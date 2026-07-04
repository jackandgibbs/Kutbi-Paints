import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../models/goal_model.dart';
import '../../core/widgets/lottie_loading_widget.dart';

class GoalSettingScreen extends ConsumerStatefulWidget {
  const GoalSettingScreen({super.key});

  @override
  ConsumerState<GoalSettingScreen> createState() =>
      _GoalSettingScreenState();
}

class _GoalSettingScreenState extends ConsumerState<GoalSettingScreen> {
  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final goals = ds.getAllGoals();

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: LottieLoadingWidget(message: 'Loading goals...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text('Goal Setting',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: goals.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No goals yet',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Create goals to motivate painters!',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (ctx, i) {
                final goal = goals[i];
                final brandColor =
                    AppColors.getBrandPrimary(goal.brand);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDE8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: brandColor.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Icon(
                                Icons.emoji_events_rounded,
                                color: brandColor,
                                size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(goal.title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    )),
                                Text(goal.brand,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color:
                                          AppColors.textSecondary,
                                    )),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: goal.isActive
                                  ? AppColors.success
                                      .withValues(alpha: 0.1)
                                  : AppColors.textLight
                                      .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              goal.isActive
                                  ? 'ACTIVE'
                                  : 'EXPIRED',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: goal.isActive
                                    ? AppColors.success
                                    : AppColors.textLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _confirmDeleteGoal(goal.id, goal.title),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.error, size: 20),
                            tooltip: 'Delete Goal',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      if (goal.description != null) ...[
                        const SizedBox(height: 8),
                        Text(goal.description!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            )),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _infoChip(
                              Icons.shopping_bag_rounded,
                              '${goal.targetQuantity} buckets',
                              brandColor),
                          const SizedBox(width: 8),
                          _infoChip(
                              Icons.card_giftcard_rounded,
                              '${goal.rewardAmount.toStringAsFixed(0)} Coins',
                              AppColors.success),
                          const SizedBox(width: 8),
                          _infoChip(
                            Icons.people_rounded,
                            goal.assignedTo.contains('all')
                                ? 'All Painters'
                                : '${goal.assignedTo.length} Painters',
                            AppColors.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${DateFormat('dd MMM').format(goal.startDate)} — ${DateFormat('dd MMM yyyy').format(goal.endDate)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _showAddGoalDialog(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.black87, size: 20),
                  const SizedBox(width: 8),
                  Text('New Goal',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              )),
        ],
      ),
    );
  }

  void _confirmDeleteGoal(String goalId, String goalTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Goal', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete "$goalTitle"? This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(dataServiceProvider).deleteGoal(goalId);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Goal "$goalTitle" deleted'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting goal: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final rewardCtrl = TextEditingController();
    String brand = 'Asian Paints';
    bool assignAll = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Create New Goal',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Goal Title',
                        prefixIcon: Icon(Icons.title_rounded,
                            color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon:
                            Icon(Icons.description_rounded,
                                color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: brand,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        prefixIcon: Icon(
                            Icons.business_rounded,
                            color: AppColors.primary),
                      ),
                      items: [
                        'Asian Paints',
                        'Berger',
                        'Birla Opus'
                      ]
                          .map((b) => DropdownMenuItem(
                              value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => brand = v!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Target Qty',
                              prefixIcon: Icon(
                                  Icons
                                      .shopping_bag_rounded,
                                  color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: rewardCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Reward (Coins)',
                              prefixIcon: Icon(
                                  Icons
                                      .card_giftcard_rounded,
                                  color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: assignAll,
                      onChanged: (v) =>
                          setModalState(() => assignAll = v),
                      title: Text('Assign to all painters',
                          style: GoogleFonts.poppins(
                              fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleCtrl.text.isEmpty ||
                              qtyCtrl.text.isEmpty ||
                              rewardCtrl.text.isEmpty) {
                            return;
                          }
                          final goal = GoalModel(
                            id: const Uuid().v4(),
                            title: titleCtrl.text.trim(),
                            description:
                                descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                            brand: brand,
                            targetQuantity:
                                int.parse(qtyCtrl.text),
                            rewardAmount: double.parse(
                                rewardCtrl.text),
                            assignedTo:
                                assignAll ? ['all'] : [],
                            startDate: DateTime.now(),
                            endDate: DateTime.now().add(
                                const Duration(days: 90)),
                            createdAt: DateTime.now(),
                          );
                          ref
                              .read(dataServiceProvider)
                              .addGoal(goal);
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Goal created successfully!'),
                              backgroundColor:
                                  AppColors.success,
                            ),
                          );
                        },
                        child: Text('Create Goal',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
