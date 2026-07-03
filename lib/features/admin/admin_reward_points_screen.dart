import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../models/milestone_model.dart';

class AdminRewardPointsScreen extends ConsumerStatefulWidget {
  const AdminRewardPointsScreen({super.key});

  @override
  ConsumerState<AdminRewardPointsScreen> createState() =>
      _AdminRewardPointsScreenState();
}

class _AdminRewardPointsScreenState extends ConsumerState<AdminRewardPointsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        title: Text('Reward Milestones',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_pin_rounded),
            onPressed: () => context.push('/admin/reset-points'),
            tooltip: 'Reset Points',
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/admin/points-history'),
            tooltip: 'View History',
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: () => _showSaveAndResetDialog(context),
            tooltip: 'Save & Reset',
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textLight,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Configuration'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _RewardDashboardTab(),
          _RewardConfigTab(),
        ],
      ),
    );
  }

  void _showSaveAndResetDialog(BuildContext context) {
    final ds = ref.read(dataServiceProvider);
    final now = DateTime.now();
    final monthKey =
        '${_getMonthName(now.month)}-${now.year.toString().substring(2)}';
    final history = ds.getPointsHistory();
    final existingForMonth = history.any(
      (r) => r is Map && r['month'] == monthKey,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Save & Reset Points', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will:\n• Generate a PDF report of current points\n• Save history for this month\n• Reset all painter points to 0',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            if (existingForMonth) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A history record for "$monthKey" already exists '
                        'and will be overwritten.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Continue?',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _generatePDFAndReset(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              existingForMonth ? 'Overwrite & Reset' : 'Proceed',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDFAndReset(BuildContext context) async {
    try {
      final ds = ref.read(dataServiceProvider);
      final painters = ds.painters.where((p) => p.points > 0).toList()
        ..sort((a, b) => b.points.compareTo(a.points));

      if (painters.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No painters with points to save'), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      // Generate PDF
      final pdf = pw.Document();
      final now = DateTime.now();
      final monthYear = '${_getMonthName(now.month)} ${now.year}';

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Painter Points Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Month: $monthYear', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Generated: ${now.day}/${now.month}/${now.year}', style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['Name', 'Phone', 'Points'],
                  data: painters.map((p) => [p.name, p.phone, p.points.toString()]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ],
            );
          },
        ),
      );

      // Show PDF preview and share
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());

      // Save and reset points
      await ds.saveAndResetPoints();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Points saved and reset successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _RewardDashboardTab extends ConsumerWidget {
  const _RewardDashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    final painters = [...ds.painters]
      ..removeWhere((p) => p.points == 0)
      ..sort((a, b) => b.points.compareTo(a.points));

    if (painters.isEmpty) {
      return Center(
        child: Text('No painters with points found.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: painters.length,
      itemBuilder: (ctx, i) {
        final painter = painters[i];
        final nextMilestone = ds.getNextMilestoneForPainter(painter.id);
        
        double progress = 0;
        if (nextMilestone != null && nextMilestone.targetPoints > 0) {
          progress = painter.points / nextMilestone.targetPoints;
          if (progress > 1.0) progress = 1.0;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(painter.name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${painter.points} pts',
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (nextMilestone != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Next: ${nextMilestone.rewardTitle}',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecondary)),
                    Text('${nextMilestone.targetPoints - painter.points} pts away',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${(progress * 100).toStringAsFixed(1)}% completed',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textLight)),
              ] else ...[
                Text('All milestones achieved or none set!',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.success)),
              ]
            ],
          ),
        );
      },
    );
  }
}

class _RewardConfigTab extends ConsumerStatefulWidget {
  const _RewardConfigTab();

  @override
  ConsumerState<_RewardConfigTab> createState() => _RewardConfigTabState();
}

class _RewardConfigTabState extends ConsumerState<_RewardConfigTab> {
  void _showAddMilestoneModal(BuildContext context, DataService ds) {
    final pointsCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    String selectedType = 'gift';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Reward Milestone',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target Points',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Reward Title (e.g., 50% Discount)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Reward Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'gift', child: Text('Gift')),
                      DropdownMenuItem(value: 'discount', child: Text('Discount')),
                      DropdownMenuItem(value: 'cashback', child: Text('Cashback')),
                    ],
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (pointsCtrl.text.isEmpty || titleCtrl.text.isEmpty) return;
                        final milestone = MilestoneModel(
                          id: const Uuid().v4(),
                          targetPoints: int.tryParse(pointsCtrl.text) ?? 0,
                          rewardTitle: titleCtrl.text,
                          rewardType: selectedType,
                          createdAt: DateTime.now(),
                        );
                        ds.addMilestone(milestone);
                        Navigator.pop(ctx);
                      },
                      child: Text('Save Milestone',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final milestones = [...ds.getAllMilestones]..sort((a, b) => a.targetPoints.compareTo(b.targetPoints));

    return Stack(
      children: [
        if (milestones.isEmpty)
          Center(
            child: Text('No milestones defined yet.',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
            itemCount: milestones.length,
            itemBuilder: (ctx, i) {
              final m = milestones[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m.targetPoints} Points',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(m.rewardTitle,
                              style: GoogleFonts.poppins(
                                  color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () {
                        ds.deleteMilestone(m.id);
                      },
                    )
                  ],
                ),
              );
            },
          ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            onPressed: () => _showAddMilestoneModal(context, ds),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('Add Milestone',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
