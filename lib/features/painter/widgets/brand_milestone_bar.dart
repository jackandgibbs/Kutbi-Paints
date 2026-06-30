import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/goal_model.dart';

/// Multi-stage milestone progress bar for a specific brand
/// Shows stages sorted by target quantity (smallest → largest)
class BrandMilestoneBar extends StatelessWidget {
  final String brand;
  final List<GoalModel> goals; // goals for this brand, sorted by targetQuantity
  final int currentProgress; // painter's current bucket count for this brand
  final List<bool> claimedStatus; // whether each goal stage is claimed

  const BrandMilestoneBar({
    super.key,
    required this.brand,
    required this.goals,
    required this.currentProgress,
    required this.claimedStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();

    final brandColor = AppColors.getBrandPrimary(brand);
    final maxTarget = goals.last.targetQuantity;
    final overallProgress = (currentProgress / maxTarget).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.clayBase,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.palette_rounded, color: brandColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  brand,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$currentProgress buckets',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Milestone progress bar
          SizedBox(
            height: 70,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                return Stack(
                  children: [
                    // Background line
                    Positioned(
                      top: 18,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Progress line
                    Positioned(
                      top: 18,
                      left: 20,
                      child: Container(
                        height: 4,
                        width: ((totalWidth - 40) * overallProgress).clamp(0, totalWidth - 40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [brandColor, brandColor.withValues(alpha: 0.7)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Start node (0)
                    Positioned(
                      top: 0,
                      left: 20 - 18, // Centering 36px node on x=20
                      child: _buildNode(
                        label: '0',
                        isCompleted: currentProgress > 0,
                        isActive: currentProgress == 0,
                        color: brandColor,
                        showCheck: false,
                      ),
                    ),
                    // Goal stage nodes
                    ...List.generate(goals.length, (i) {
                      final goal = goals[i];
                      final isCompleted = currentProgress >= goal.targetQuantity;
                      final isClaimed = i < claimedStatus.length && claimedStatus[i];
                      final nodeCenter = 20 + (totalWidth - 40) * (goal.targetQuantity / maxTarget);

                      return Positioned(
                        top: 0,
                        left: nodeCenter - 25, // Centering a 50px wide column
                        width: 50, // Fixed width for centering text
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildNode(
                              label: '${i + 1}',
                              isCompleted: isCompleted,
                              isActive: !isCompleted &&
                                  (i == 0 || currentProgress >= goals[i - 1].targetQuantity),
                              color: brandColor,
                              showCheck: isClaimed,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${goal.targetQuantity}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isCompleted ? brandColor : AppColors.textLight,
                              ),
                            ),
                            Text(
                              '${goal.rewardAmount.toStringAsFixed(0)} Coins',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isClaimed
                                    ? AppColors.success
                                    : isCompleted
                                        ? brandColor
                                        : AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode({
    required String label,
    required bool isCompleted,
    required bool isActive,
    required Color color,
    required bool showCheck,
  }) {
    final size = 36.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? color : Colors.white,
        border: Border.all(
          color: isCompleted
              ? color
              : isActive
                  ? color.withValues(alpha: 0.5)
                  : Colors.grey.shade300,
          width: isActive ? 2.5 : 2,
        ),
      ),
      child: Center(
        child: showCheck
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive ? color : Colors.grey.shade400,
                    ),
                  ),
      ),
    );
  }
}
