import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart';
import '../../widgets/app_widgets.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(user?.ngoName ?? user?.name ?? 'NGO', user?.photoUrl),
            _buildStatsRow(user?.uid),
            _buildTabBar(),
            Expanded(child: _buildTabContent(user?.uid)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String ngoName, String? photoUrl) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.ngoGreen,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? const Icon(Icons.business, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ngoName,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('Active',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.success)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textGrey),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String? ngoId) {
    if (ngoId == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('assignedNgoId', isEqualTo: ngoId)
            .snapshots(),
        builder: (context, snapshot) {
          int total = 0, inProgress = 0, resolved = 0;
          if (snapshot.hasData) {
            total = snapshot.data!.docs.length;
            for (final doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'inProgress') inProgress++;
              if (data['status'] == 'resolved') resolved++;
            }
          }
          return Row(
            children: [
              _statCard('Total', total.toString(), AppColors.primary),
              const SizedBox(width: 10),
              _statCard('Active', inProgress.toString(), AppColors.animalOrange),
              const SizedBox(width: 10),
              _statCard('Resolved', resolved.toString(), AppColors.success),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textGrey,
        indicatorColor: AppColors.primary,
        labelStyle:
            GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Assigned'),
          Tab(text: 'In Progress'),
          Tab(text: 'Resolved'),
        ],
      ),
    );
  }

  Widget _buildTabContent(String? ngoId) {
    if (ngoId == null) return const SizedBox.shrink();
    return TabBarView(
      controller: _tabController,
      children: [
        _ReportListView(ngoId: ngoId, status: ReportStatus.accepted),
        _ReportListView(ngoId: ngoId, status: ReportStatus.inProgress),
        _ReportListView(ngoId: ngoId, status: ReportStatus.resolved),
      ],
    );
  }
}

class _ReportListView extends StatelessWidget {
  final String ngoId;
  final ReportStatus status;

  const _ReportListView({required this.ngoId, required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('assignedNgoId', isEqualTo: ngoId)
          .where('status', isEqualTo: status.name)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            title: 'No Reports',
            subtitle: 'No reports in this category.',
            icon: Icons.assignment_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final report = ReportModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id);
            return _NgoReportCard(report: report);
          },
        );
      },
    );
  }
}

class _NgoReportCard extends StatelessWidget {
  final ReportModel report;

  const _NgoReportCard({required this.report});

  Future<void> _updateStatus(
      BuildContext context, ReportStatus newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update Status',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'Change status to "${newStatus.name}"?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReportTypeBadge(type: report.type),
              const Spacer(),
              StatusBadge(status: report.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.description,
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text('${report.userName} • ${report.userPhone}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(report.address,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 14, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, hh:mm a').format(report.createdAt),
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report.status == ReportStatus.accepted)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _updateStatus(context, ReportStatus.inProgress),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.animalOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Start Response',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            )
          else if (report.status == ReportStatus.inProgress)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _updateStatus(context, ReportStatus.resolved),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Mark Resolved',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}