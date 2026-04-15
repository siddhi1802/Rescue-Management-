import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart';
import '../../widgets/app_widgets.dart';

class ReportScreen extends StatefulWidget {
  final ReportType? initialType;
  const ReportScreen({super.key, this.initialType});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  late ReportType _selectedType;

  // Location
  double? _lat;
  double? _lng;
  String _address = '';
  bool _isLocationLoading = false;
  String _locationError = '';

  // Submit
  bool _isSubmitting = false;

  // Images — store bytes so Image.memory works on both web + mobile
  final List<XFile> _selectedImages = [];
  final Map<int, Uint8List> _imageBytes = {};
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? ReportType.sos;
    _getLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // Only setState if widget still mounted
  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ─── LOCATION ───────────────────────────────────────────────────────────────

  Future<void> _getLocation() async {
    _safeSetState(() {
      _isLocationLoading = true;
      _locationError = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;

      if (!serviceEnabled) {
        _safeSetState(() {
          _locationError =
              'Location services are disabled. Enable them in your browser/device settings, then tap Refresh.';
          _isLocationLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _safeSetState(() {
          _locationError =
              'Permission denied. Click the location icon in your browser address bar → Allow → tap Refresh.';
          _isLocationLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            kIsWeb ? LocationAccuracy.low : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

      if (!mounted) return; // KEY FIX — guard after every await

      final coordStr =
          'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';

      _safeSetState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _address = coordStr;
        _isLocationLoading = false;
        _locationError = '';
      });
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() {
        _locationError = 'Could not get location. Tap Refresh to try again.';
        _isLocationLoading = false;
      });
    }
  }

  // ─── IMAGES ─────────────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 70);
      if (images.isEmpty || !mounted) return;

      for (int i = 0; i < images.length; i++) {
        final idx = _selectedImages.length + i;
        final bytes = await images[i].readAsBytes(); // works on web + mobile
        if (!mounted) return;
        _safeSetState(() => _imageBytes[idx] = bytes);
      }

      _safeSetState(() => _selectedImages.addAll(images));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  void _removeImage(int index) {
    _safeSetState(() {
      _selectedImages.removeAt(index);
      final rebuilt = <int, Uint8List>{};
      _imageBytes.forEach((k, v) {
        if (k < index) rebuilt[k] = v;
        if (k > index) rebuilt[k - 1] = v;
      });
      _imageBytes
        ..clear()
        ..addAll(rebuilt);
    });
  }

  Future<List<String>> _uploadImages(String reportId) async {
    final urls = <String>[];
    for (int i = 0; i < _selectedImages.length; i++) {
      final ref = FirebaseStorage.instance.ref().child(
          'reports/$reportId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');

      final bytes = _imageBytes[i] ?? await _selectedImages[i].readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  // ─── SUBMIT ─────────────────────────────────────────────────────────────────

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location required. Allow location access and tap Refresh.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _safeSetState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser!;

      final docRef = FirebaseFirestore.instance.collection('reports').doc();
      final imageUrls = await _uploadImages(docRef.id);
      if (!mounted) return;

      final report = ReportModel(
        id: docRef.id,
        userId: user.uid,
        userName: user.name,
        userPhone: user.phone,
        type: _selectedType,
        status: ReportStatus.pending,
        description: _descriptionController.text.trim(),
        location: GeoPoint(_lat!, _lng!),
        address: _address,
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
      );

      await docRef.set(report.toMap());
      if (!mounted) return;

      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'reportId': docRef.id,
        'type': report.type.name,
        'message': 'New ${report.typeLabel} report from ${user.name}',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Submit Report'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTypeSelector(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildLocationCard(),
              const SizedBox(height: 16),
              _buildImagePicker(),
              const SizedBox(height: 16),
              _buildSosWarning(),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Submit Report',
                onPressed: _submitReport,
                isLoading: _isSubmitting,
                backgroundColor: _typeColor(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SECTION WIDGETS ────────────────────────────────────────────────────────

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Type',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const SizedBox(height: 14),
          Row(
            children: ReportType.values.map((type) {
              final isSelected = _selectedType == type;
              final color = _typeColor(type: type);
              return Expanded(
                child: GestureDetector(
                  onTap: () => _safeSetState(() => _selectedType = type),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: type != ReportType.animalRescue ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? color : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected ? color : AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        Icon(_typeIcon(type),
                            color: isSelected
                                ? Colors.white
                                : AppColors.textGrey,
                            size: 22),
                        const SizedBox(height: 6),
                        Text(_typeShortLabel(type),
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textGrey),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: AppTextField(
        label: 'Description',
        hint: 'Describe the emergency situation in detail...',
        controller: _descriptionController,
        maxLines: 4,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Please describe the situation';
          if (v.length < 10)
            return 'Please provide more details (min 10 characters)';
          return null;
        },
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Location',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              GestureDetector(
                onTap: _getLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Refresh',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLocationLoading)
            Row(children: [
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Detecting your location...',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textGrey)),
            ])
          else if (_lat != null)
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.location_on,
                    color: AppColors.success, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Location detected',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                    Text(_address,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ),
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 20),
            ])
          else ...[
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.location_off,
                    color: AppColors.error, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    _locationError.isEmpty
                        ? 'Location not available'
                        : _locationError,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.error)),
              ),
            ]),
            if (kIsWeb) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 15, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Web tip: Click the lock/info icon in your browser address bar → Site settings → Location → Allow → then tap Refresh.',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Photos (Optional)',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  final bytes = _imageBytes[index];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.background,
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: bytes != null
                              ? Image.memory(bytes,
                                  fit: BoxFit.cover,
                                  width: 90,
                                  height: 90)
                              : const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_selectedImages.length} photo${_selectedImages.length == 1 ? '' : 's'} selected',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textGrey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSosWarning() {
    if (_selectedType != ReportType.sos) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sosRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sosRed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.sosRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'SOS reports are highest priority. Only use for genuine emergencies.',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.sosRed),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  Color _typeColor({ReportType? type}) {
    switch (type ?? _selectedType) {
      case ReportType.sos:
        return AppColors.sosRed;
      case ReportType.childHelp:
        return AppColors.childBlue;
      case ReportType.animalRescue:
        return AppColors.animalOrange;
    }
  }

  IconData _typeIcon(ReportType type) {
    switch (type) {
      case ReportType.sos:
        return Icons.sos;
      case ReportType.childHelp:
        return Icons.child_care;
      case ReportType.animalRescue:
        return Icons.pets;
    }
  }

  String _typeShortLabel(ReportType type) {
    switch (type) {
      case ReportType.sos:
        return 'SOS';
      case ReportType.childHelp:
        return 'Child Help';
      case ReportType.animalRescue:
        return 'Animal';
    }
  }
}