import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Assuming these are your file paths - update if different
import '../../services/auth_service.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart'; 
import '../../widgets/app_widgets.dart';

class ReportHistoryScreen extends StatelessWidget {
  const ReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Safely get the current user ID from your AuthService
    final auth = Provider.of<AuthService>(context, listen: false);
    final String? uid = auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Report History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textDark),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: uid == null 
        ? const Center(child: Text("Please log in to view history"))
        : StreamBuilder<QuerySnapshot>(
            // 2. The Stream: Listens to Firestore 'reports' collection
            stream: FirebaseFirestore.instance
                .collection('reports')
                .where('userId', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // Handle Loading
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Handle Errors (e.g., missing index)
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text("Error: ${snapshot.error}\n\nCheck console for Index URL."),
                  ),
                );
              }

              // Handle Empty State
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyState(
                  title: 'No Reports Yet',
                  subtitle: 'Your submitted reports will appear here.',
                  icon: Icons.report_gmailerrorred_outlined,
                );
              }

              // 3. Build the List
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  // Map Firestore data to your model
                  final report = ReportModel.fromMap(
                    doc.data() as Map<String, dynamic>, 
                    doc.id
                  );
                  return _ReportCard(report: report);
                },
              );
            },
          ),
    );
  }
}

// --- Internal Widget: The Report Card ---
class _ReportCard extends StatelessWidget {
  final ReportModel report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/report-detail', arguments: report),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Change these two lines:
               _TypeBadge(type: report.type.name),       // Added .name
               const Spacer(),
                _StatusBadge(status: report.status.name), // Added .name
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report.description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.address,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppColors.textGrey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy · hh:mm a').format(report.createdAt),
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textGrey),
                ),
              ],
            ),
            if (report.assignedNgoName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Assigned: ${report.assignedNgoName}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Helper UI: Type Badge ---
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type.toLowerCase()) {
      case 'animal': color = Colors.orange; break;
      case 'child': color = Colors.blue; break;
      case 'sos': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// --- Helper UI: Status Badge ---
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Text(
      status,
      style: GoogleFonts.poppins(
        fontSize: 12,
        color: status.toLowerCase() == 'pending' ? Colors.orange : Colors.green,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}