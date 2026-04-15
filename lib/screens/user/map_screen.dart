import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart';
import '../../widgets/app_widgets.dart';

// google_maps_flutter only works on Android/iOS
import 'package:google_maps_flutter/google_maps_flutter.dart'
    if (dart.library.html) 'package:rescue_app/utils/maps_stub.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  double? _currentLat;
  double? _currentLng;
  final Set<Marker> _markers = {};
  String _filterType = 'All';
  bool _isLoading = true;
  List<ReportModel> _reports = [];
  ReportModel? _selectedReport;

  // Maharashtra bounding box
  static const double _mahLatMin = 15.6;
  static const double _mahLatMax = 22.1;
  static const double _mahLngMin = 72.6;
  static const double _mahLngMax = 80.9;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadReports();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            kIsWeb ? LocationAccuracy.low : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;

      _safeSetState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
      });

      if (!kIsWeb && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 10,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadReports() async {
    _safeSetState(() => _isLoading = true);
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('reports').get();
      if (!mounted) return;

      final reports = snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
          .toList();

      if (!kIsWeb) {
        final newMarkers = <Marker>{};
        for (final report in reports) {
          newMarkers.add(Marker(
            markerId: MarkerId(report.id),
            position:
                LatLng(report.location.latitude, report.location.longitude),
            infoWindow: InfoWindow(
              title: report.typeLabel,
              snippet: report.statusLabel,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              report.type == ReportType.sos
                  ? BitmapDescriptor.hueRed
                  : report.type == ReportType.childHelp
                      ? BitmapDescriptor.hueBlue
                      : BitmapDescriptor.hueOrange,
            ),
            onTap: () => _showReportSheet(report),
          ));
        }

        final ngoSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'ngo')
            .get();
        if (!mounted) return;

        for (final doc in ngoSnap.docs) {
          final data = doc.data();
          final GeoPoint? loc = data['location'];
          if (loc != null) {
            newMarkers.add(Marker(
              markerId: MarkerId('ngo_${doc.id}'),
              position: LatLng(loc.latitude, loc.longitude),
              infoWindow: InfoWindow(
                title: data['ngoName'] ?? 'NGO Center',
                snippet: data['ngoAddress'],
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
            ));
          }
        }

        _safeSetState(() {
          _markers..clear()..addAll(newMarkers);
        });
      }

      _safeSetState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() => _isLoading = false);
    }
  }

  void _showReportSheet(ReportModel report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ReportTypeBadge(type: report.type),
              const SizedBox(width: 10),
              StatusBadge(status: report.status),
            ]),
            const SizedBox(height: 12),
            Text(report.description,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(report.address,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textGrey))),
            ]),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'View Full Details',
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/report-detail',
                    arguments: report);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<ReportModel> get _filteredReports {
    if (_filterType == 'All') return _reports;
    return _reports.where((r) {
      if (_filterType == 'SOS') return r.type == ReportType.sos;
      if (_filterType == 'Child') return r.type == ReportType.childHelp;
      if (_filterType == 'Animal') return r.type == ReportType.animalRescue;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: kIsWeb ? _buildWebLayout() : _buildMobileLayout(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/report'),
        backgroundColor: AppColors.sosRed,
        icon: const Icon(Icons.sos, color: Colors.white),
        label: Text('Report Here',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── WEB: Interactive dot-map of Maharashtra ─────────────────────────────

  Widget _buildWebLayout() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildMaharashtraMap(),
        ),
        _buildLegend(),
      ],
    );
  }

  Widget _buildMaharashtraMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            // Map background
            Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE3F2FD),
                    const Color(0xFFBBDEFB),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Maharashtra outline + grid
            CustomPaint(
              size: Size(w, h),
              painter: _MaharashtraMapPainter(),
            ),

            // City labels
            ..._buildCityLabels(w, h),

            // Report dots
            ..._filteredReports.map((report) {
              final px = _lngToX(report.location.longitude, w);
              final py = _latToY(report.location.latitude, h);
              final color = _typeColor(report.type);
              final isSelected = _selectedReport?.id == report.id;

              return Positioned(
                left: px - (isSelected ? 12 : 8),
                top: py - (isSelected ? 12 : 8),
                child: GestureDetector(
                  onTap: () {
                    _safeSetState(() => _selectedReport =
                        _selectedReport?.id == report.id ? null : report);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 24 : 16,
                    height: isSelected ? 24 : 16,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white,
                          width: isSelected ? 3 : 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: isSelected ? 12 : 6,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // Current location dot
            if (_currentLat != null)
              Positioned(
                left: _lngToX(_currentLng!, w) - 10,
                top: _latToY(_currentLat!, h) - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 10),
                    ],
                  ),
                ),
              ),

            // Selected report popup card
            if (_selectedReport != null)
              Positioned(
                left: math.min(
                    _lngToX(_selectedReport!.location.longitude, w) + 16,
                    w - 260),
                top: math.max(
                    _latToY(_selectedReport!.location.latitude, h) - 80, 8),
                child: _buildPopupCard(_selectedReport!),
              ),

            // Stats overlay top-right
            Positioned(
              top: 12,
              right: 12,
              child: _buildStatsOverlay(),
            ),

            // Refresh button
            Positioned(
              bottom: 16,
              right: 16,
              child: GestureDetector(
                onTap: _loadReports,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8),
                    ],
                  ),
                  child: const Icon(Icons.refresh,
                      color: AppColors.primary, size: 20),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopupCard(ReportModel report) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            ReportTypeBadge(type: report.type),
            const Spacer(),
            GestureDetector(
              onTap: () => _safeSetState(() => _selectedReport = null),
              child: const Icon(Icons.close,
                  size: 16, color: AppColors.textGrey),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            report.description,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textDark),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            report.address,
            style: GoogleFonts.poppins(
                fontSize: 10, color: AppColors.textGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(children: [
            StatusBadge(status: report.status),
            const Spacer(),
            GestureDetector(
              onTap: () {
                _safeSetState(() => _selectedReport = null);
                Navigator.pushNamed(context, '/report-detail',
                    arguments: report);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Details',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatsOverlay() {
    final sos = _reports.where((r) => r.type == ReportType.sos).length;
    final child = _reports.where((r) => r.type == ReportType.childHelp).length;
    final animal =
        _reports.where((r) => r.type == ReportType.animalRescue).length;
    final pending =
        _reports.where((r) => r.status == ReportStatus.pending).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Maharashtra Reports',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          _statRow(AppColors.sosRed, 'SOS', sos),
          _statRow(AppColors.childBlue, 'Child', child),
          _statRow(AppColors.animalOrange, 'Animal', animal),
          const Divider(height: 12, color: AppColors.divider),
          _statRow(AppColors.warning, 'Pending', pending),
          _statRow(AppColors.textDark, 'Total', _reports.length),
        ],
      ),
    );
  }

  Widget _statRow(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textGrey)),
          const SizedBox(width: 8),
          Text('$count',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }

  List<Widget> _buildCityLabels(double w, double h) {
    final cities = [
      ('Mumbai', 18.9388, 72.8354),
      ('Pune', 18.5204, 73.8567),
      ('Nagpur', 21.1458, 79.0882),
      ('Nashik', 19.9975, 73.7898),
      ('Aurangabad', 19.8762, 75.3433),
      ('Kolhapur', 16.7050, 74.2433),
      ('Solapur', 17.6599, 75.9064),
      ('Amravati', 20.9374, 77.7796),
      ('Nanded', 19.1383, 77.3210),
      ('Latur', 18.4088, 76.5604),
      ('Satara', 17.6805, 74.0183),
      ('Jalgaon', 21.0077, 75.5626),
    ];

    return cities.map((city) {
      final px = _lngToX(city.$3, w);
      final py = _latToY(city.$2, h);
      return Positioned(
        left: px + 8,
        top: py - 6,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF78909C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              city.$1,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF546E7A),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ─── COORDINATE PROJECTION ──────────────────────────────────────────────────
  // Maps lat/lng to pixel X/Y within the widget bounds

  double _lngToX(double lng, double width) {
    final clamped = lng.clamp(_mahLngMin, _mahLngMax);
    return ((clamped - _mahLngMin) / (_mahLngMax - _mahLngMin)) * width;
  }

  double _latToY(double lat, double height) {
    final clamped = lat.clamp(_mahLatMin, _mahLatMax);
    // Latitude increases upward, but screen Y increases downward → flip
    return (1 - (clamped - _mahLatMin) / (_mahLatMax - _mahLatMin)) * height;
  }

  // ─── MOBILE LAYOUT ──────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: const CameraPosition(
            target: LatLng(19.7515, 75.7139), // Center of Maharashtra
            zoom: 6.5,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
        ),
        Positioned(top: 0, left: 0, right: 0, child: _buildFilterBar()),
        Positioned(
          bottom: 80,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mapFab(Icons.my_location, _getCurrentLocation),
              const SizedBox(height: 10),
              _mapFab(Icons.refresh, _loadReports),
              const SizedBox(height: 10),
              _mapFab(
                Icons.map,
                () => _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    const CameraPosition(
                      target: LatLng(19.7515, 75.7139),
                      zoom: 6.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildLegend()),
      ],
    );
  }

  Widget _mapFab(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12), blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }

  // ─── SHARED ─────────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    final filters = ['All', 'SOS', 'Child', 'Animal'];
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Text('Show:',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(width: 8),
          ...filters.map((f) {
            final isSelected = _filterType == f;
            return GestureDetector(
              onTap: () => _safeSetState(() {
                _filterType = f;
                _selectedReport = null;
              }),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(f,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textGrey)),
              ),
            );
          }),
          const Spacer(),
          Text(
            '${_filteredReports.length} report${_filteredReports.length == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem(AppColors.sosRed, 'SOS'),
          _legendItem(AppColors.childBlue, 'Child'),
          _legendItem(AppColors.animalOrange, 'Animal'),
          _legendItem(AppColors.ngoGreen, 'NGO'),
          _legendItem(AppColors.primary, 'You'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textDark)),
      ],
    );
  }

  Color _typeColor(ReportType type) {
    switch (type) {
      case ReportType.sos:
        return AppColors.sosRed;
      case ReportType.childHelp:
        return AppColors.childBlue;
      case ReportType.animalRescue:
        return AppColors.animalOrange;
    }
  }
}

// ─── MAHARASHTRA MAP PAINTER ─────────────────────────────────────────────────
// Draws the background grid lines and border

class _MaharashtraMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFB0BEC5).withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final borderPaint = Paint()
      ..color = const Color(0xFF90A4AE).withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw grid lines (lat/lng grid)
    // Vertical lines every ~1 degree longitude
    for (double lng = 73.0; lng <= 81.0; lng += 1.0) {
      final x = ((lng - 72.6) / (80.9 - 72.6)) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal lines every ~1 degree latitude
    for (double lat = 16.0; lat <= 22.0; lat += 1.0) {
      final y = (1 - (lat - 15.6) / (22.1 - 15.6)) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw approximate Maharashtra border outline
    // These are simplified boundary points [lng, lat]
    final borderPoints = [
      // Konkan coast (west)
      [72.82, 19.99], [72.74, 19.50], [72.85, 19.20],
      [72.94, 18.90], [73.10, 18.50], [73.30, 17.80],
      [73.50, 17.30], [73.80, 16.90], [74.10, 16.70],
      // Southern border
      [74.40, 16.68], [74.80, 16.68], [75.10, 16.80],
      [75.40, 16.85], [75.90, 17.00], [76.30, 17.10],
      [76.70, 17.20], [77.00, 17.30],
      // Eastern border (Telangana)
      [77.30, 17.60], [77.50, 18.00], [77.80, 18.30],
      [78.00, 18.80], [78.20, 19.30], [78.30, 19.80],
      [78.50, 20.20], [78.80, 20.60], [79.10, 20.90],
      [79.50, 21.10], [80.00, 21.40], [80.40, 21.70],
      [80.60, 21.90],
      // Northern border (MP)
      [80.30, 21.95], [79.80, 21.95], [79.30, 21.90],
      [78.80, 21.85], [78.30, 21.80], [77.80, 21.75],
      [77.30, 21.70], [76.80, 21.65], [76.30, 21.60],
      [75.80, 21.55], [75.30, 21.50],
      // NW border (Gujarat/Rajasthan)
      [74.80, 21.40], [74.30, 21.20], [73.80, 21.00],
      [73.50, 20.80], [73.20, 20.50], [73.00, 20.20],
      [72.95, 20.00], [72.85, 19.80], [72.82, 19.99],
    ];

    if (borderPoints.length < 2) return;

    final path = Path();
    final first = borderPoints.first;
    final fx = ((first[0] - 72.6) / (80.9 - 72.6)) * size.width;
    final fy = (1 - (first[1] - 15.6) / (22.1 - 15.6)) * size.height;
    path.moveTo(fx, fy);

    for (int i = 1; i < borderPoints.length; i++) {
      final p = borderPoints[i];
      final px = ((p[0] - 72.6) / (80.9 - 72.6)) * size.width;
      final py = (1 - (p[1] - 15.6) / (22.1 - 15.6)) * size.height;
      path.lineTo(px, py);
    }
    path.close();

    // Fill Maharashtra with light color
    final fillPaint = Paint()
      ..color = const Color(0xFFE1F5FE).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_MaharashtraMapPainter oldDelegate) => false;
}