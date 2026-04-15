import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<Map<String, String>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && data['emergencyContacts'] != null) {
      final List<dynamic> raw = data['emergencyContacts'];
      setState(() {
        _contacts.clear();
        for (final item in raw) {
          if (item is Map) {
            _contacts.add({
              'name': item['name']?.toString() ?? '',
              'phone': item['phone']?.toString() ?? '',
              'relation': item['relation']?.toString() ?? '',
            });
          }
        }
      });
    }
    setState(() => _isLoading = false);
  }

  void _addContact() {
    _showContactDialog();
  }

  void _editContact(int index) {
    _showContactDialog(index: index, existing: _contacts[index]);
  }

  void _deleteContact(int index) async {
    setState(() => _contacts.removeAt(index));
    await _saveContacts();
  }

  Future<void> _saveContacts() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'emergencyContacts': _contacts,
    });
  }

  void _showContactDialog({int? index, Map<String, String>? existing}) {
    final nameController =
        TextEditingController(text: existing?['name'] ?? '');
    final phoneController =
        TextEditingController(text: existing?['phone'] ?? '');
    final relationController =
        TextEditingController(text: existing?['relation'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          index == null ? 'Add Contact' : 'Edit Contact',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Name',
              hint: 'Contact name',
              controller: nameController,
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.textGrey, size: 20),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Phone',
              hint: 'Phone number',
              controller: phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined,
                  color: AppColors.textGrey, size: 20),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Relation',
              hint: 'e.g. Father, Sister',
              controller: relationController,
              prefixIcon: const Icon(Icons.people_outline,
                  color: AppColors.textGrey, size: 20),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  phoneController.text.isEmpty) return;
              final contact = {
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'relation': relationController.text.trim(),
              };
              setState(() {
                if (index == null) {
                  _contacts.add(contact);
                } else {
                  _contacts[index] = contact;
                }
              });
              await _saveContacts();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Save',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _callContact(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: _addContact,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? EmptyState(
                  title: 'No Emergency Contacts',
                  subtitle:
                      'Add trusted contacts who will be notified in emergencies.',
                  icon: Icons.contact_phone_outlined,
                  buttonText: 'Add Contact',
                  onButton: _addContact,
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'These contacts will be notified when you submit an SOS report.',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final c = _contacts[index];
                          return _ContactCard(
                            name: c['name'] ?? '',
                            phone: c['phone'] ?? '',
                            relation: c['relation'] ?? '',
                            onCall: () => _callContact(c['phone'] ?? ''),
                            onEdit: () => _editContact(index),
                            onDelete: () => _deleteContact(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _contacts.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addContact,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final String relation;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.name,
    required this.phone,
    required this.relation,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text(phone,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textGrey)),
                if (relation.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.animalOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      relation,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.animalOrange,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: AppColors.ngoGreen),
            onPressed: onCall,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  const Icon(Icons.edit, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit', style: GoogleFonts.poppins(fontSize: 14)),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Delete',
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}