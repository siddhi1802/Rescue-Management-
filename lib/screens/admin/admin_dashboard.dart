import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart';
import '../../models/app_user.dart';
import '../../widgets/app_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsRow(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.admin_panel_settings, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
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

  Widget _buildStatsRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          int total = 0, pending = 0, inProgress = 0, resolved = 0;
          if (snapshot.hasData) {
            total = snapshot.data!.docs.length;
            for (final doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              switch (data['status']) {
                case 'pending':
                  pending++;
                  break;
                case 'inProgress':
                  inProgress++;
                  break;
                case 'resolved':
                  resolved++;
                  break;
              }
            }
          }
          return Row(
            children: [
              _statCard('Total', total.toString(), AppColors.primary,
                  Icons.list_alt),
              const SizedBox(width: 8),
              _statCard('Pending', pending.toString(), AppColors.warning,
                  Icons.hourglass_top),
              const SizedBox(width: 8),
              _statCard('Active', inProgress.toString(),
                  AppColors.animalOrange, Icons.loop),
              const SizedBox(width: 8),
              _statCard('Done', resolved.toString(), AppColors.success,
                  Icons.check_circle),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textGrey)),
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
          Tab(text: 'Reports'),
          Tab(text: 'NGOs'),
          Tab(text: 'Users'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: const [
        _AdminReportsTab(),
        _AdminNgosTab(),
        _AdminUsersTab(),
      ],
    );
  }
}

class _AdminReportsTab extends StatelessWidget {
  const _AdminReportsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            title: 'No Reports',
            subtitle: 'No emergency reports submitted yet.',
            icon: Icons.report_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final report = ReportModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id);
            return _AdminReportCard(report: report);
          },
        );
      },
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  final ReportModel report;

  const _AdminReportCard({required this.report});

  Future<void> _assignNgo(BuildContext context) async {
    final ngos = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'ngo')
        .get();

    if (!context.mounted) return;

    if (ngos.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No NGOs available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Assign to NGO',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...ngos.docs.map((doc) {
            final data = doc.data();
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.ngoGreen,
                child: Icon(Icons.business, color: Colors.white, size: 18),
              ),
              title: Text(data['ngoName'] ?? data['name'] ?? 'NGO',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: Text(data['ngoAddress'] ?? '',
                  style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('reports')
                    .doc(report.id)
                    .update({
                  'assignedNgoId': doc.id,
                  'assignedNgoName':
                      data['ngoName'] ?? data['name'] ?? 'NGO',
                  'status': ReportStatus.accepted.name,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Notify the user
                await FirebaseFirestore.instance
                    .collection('notifications')
                    .add({
                  'userId': report.userId,
                  'title': 'Report Accepted',
                  'body':
                      '${data['ngoName']} has been assigned to your report.',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _rejectReport(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(report.id)
        .update({
      'status': ReportStatus.rejected.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
          Text(report.description,
              style:
                  GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.person_outline,
                size: 13, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Text('${report.userName} • ${report.userPhone}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textGrey)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on_outlined,
                size: 13, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(report.address,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time, size: 13, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Text(DateFormat('MMM d, hh:mm a').format(report.createdAt),
                style:
                    GoogleFonts.poppins(fontSize: 11, color: AppColors.textGrey)),
          ]),
          if (report.assignedNgoName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.ngoGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business,
                      size: 14, color: AppColors.ngoGreen),
                  const SizedBox(width: 6),
                  Text('Assigned: ${report.assignedNgoName}',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.ngoGreen,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
          if (report.status == ReportStatus.pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectReport(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Reject',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _assignNgo(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Assign NGO',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminNgosTab extends StatelessWidget {
  const _AdminNgosTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            title: 'No NGOs',
            subtitle: 'No NGOs registered yet.',
            icon: Icons.business_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final user = AppUser.fromMap(
                doc.data() as Map<String, dynamic>, doc.id);
            return _NgoCard(user: user);
          },
        );
      },
    );
  }
}

class _NgoCard extends StatelessWidget {
  final AppUser user;

  const _NgoCard({required this.user});

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
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.ngoGreen.withOpacity(0.15),
            child: Text(
              (user.ngoName ?? user.name).isNotEmpty
                  ? (user.ngoName ?? user.name)[0].toUpperCase()
                  : 'N',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ngoGreen),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.ngoName ?? user.name,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(user.email,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textGrey)),
                if (user.ngoAddress != null)
                  Text(user.ngoAddress!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Active',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _AdminUsersTab extends StatelessWidget {
  const _AdminUsersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'user')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyState(
            title: 'No Users',
            subtitle: 'No users registered yet.',
            icon: Icons.people_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final user = AppUser.fromMap(
                doc.data() as Map<String, dynamic>, doc.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: user.photoUrl != null
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null
                        ? Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text(user.email,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textGrey)),
                        Text(user.phone,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textGrey)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}