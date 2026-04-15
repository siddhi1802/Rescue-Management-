import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart';
import '../../widgets/app_widgets.dart';

class ReportDetailScreen extends StatelessWidget {
  final ReportModel report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Report #${report.id.substring(0, 8)}'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildInfoCard(),
          if (report.assignedNgoName != null) ...[
            const SizedBox(height: 16),
            _buildNgoCard(),
          ],
          if (report.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildImagesCard(),
          ],
          const SizedBox(height: 16),
          _buildTimeline(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor().withOpacity(0.8),
            _getStatusColor(),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(_getStatusIcon(), color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            report.statusLabel,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your report is being processed',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Details',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              ReportTypeBadge(type: report.type),
              const Spacer(),
              Text(
                DateFormat('MMM d, yyyy').format(report.createdAt),
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.description_outlined, 'Description',
              report.description),
          const Divider(height: 24, color: AppColors.divider),
          _infoRow(Icons.location_on_outlined, 'Location', report.address),
          const Divider(height: 24, color: AppColors.divider),
          _infoRow(Icons.person_outline, 'Reported by', report.userName),
          const Divider(height: 24, color: AppColors.divider),
          _infoRow(Icons.phone_outlined, 'Phone', report.userPhone),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textGrey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNgoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assigned NGO',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.ngoGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business,
                    color: AppColors.ngoGreen, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.assignedNgoName!,
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Responding',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.success),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (report.ngoNotes != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ngoGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                report.ngoNotes!,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textDark),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photos',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: report.imageUrls.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(report.imageUrls[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final steps = [
      ('Report Submitted', ReportStatus.pending, report.createdAt),
      if (report.status.index >= ReportStatus.accepted.index)
        ('Report Accepted', ReportStatus.accepted, report.updatedAt),
      if (report.status.index >= ReportStatus.inProgress.index)
        ('NGO Assigned & In Progress', ReportStatus.inProgress,
            report.updatedAt),
      if (report.status == ReportStatus.resolved)
        ('Case Resolved', ReportStatus.resolved, report.updatedAt),
      if (report.status == ReportStatus.rejected)
        ('Report Rejected', ReportStatus.rejected, report.updatedAt),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timeline',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final isLast = i == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status: step.$2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: AppColors.divider,
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$1,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (step.$3 != null)
                          Text(
                            DateFormat('MMM d, hh:mm a').format(step.$3!),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textGrey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Color _getStatusColor({ReportStatus? status}) {
    switch (status ?? report.status) {
      case ReportStatus.pending:
        return AppColors.warning;
      case ReportStatus.accepted:
        return AppColors.primary;
      case ReportStatus.inProgress:
        return AppColors.animalOrange;
      case ReportStatus.resolved:
        return AppColors.success;
      case ReportStatus.rejected:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon() {
    switch (report.status) {
      case ReportStatus.pending:
        return Icons.hourglass_top;
      case ReportStatus.accepted:
        return Icons.check_circle_outline;
      case ReportStatus.inProgress:
        return Icons.loop;
      case ReportStatus.resolved:
        return Icons.verified_outlined;
      case ReportStatus.rejected:
        return Icons.cancel_outlined;
    }
  }
}