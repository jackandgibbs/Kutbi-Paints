import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../providers/ui_scale_provider.dart';
import '../providers/global_refresh_provider.dart';

class UIScaleController extends ConsumerWidget {
  final bool isExpanded;
  final VoidCallback? onRefresh;

  const UIScaleController({
    super.key,
    this.isExpanded = true,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(uiScaleProvider);
    final isRefreshing = ref.watch(globalRefreshProvider);

    final canZoomOut = scale > 0.85;
    final canZoomIn = scale < 1.45;

    void zoomOut() {
      if (!canZoomOut) return;
      final newVal = ((scale - 0.1) * 10).round() / 10.0;
      ref.read(uiScaleProvider.notifier).setScale(newVal.clamp(0.8, 1.5));
    }

    void zoomIn() {
      if (!canZoomIn) return;
      final newVal = ((scale + 0.1) * 10).round() / 10.0;
      ref.read(uiScaleProvider.notifier).setScale(newVal.clamp(0.8, 1.5));
    }

    void resetZoom() {
      ref.read(uiScaleProvider.notifier).reset();
    }

    Future<void> handleRefresh() async {
      if (isRefreshing) return;
      onRefresh?.call();
      await performSoftRefresh(ref);
    }

    if (isExpanded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.adminBorder.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildIconButton(
              icon: Icons.remove_rounded,
              tooltip: 'Zoom out',
              onTap: canZoomOut ? zoomOut : null,
              color: canZoomOut ? AppColors.textPrimary : AppColors.textLight,
            ),
            Expanded(
              child: Tooltip(
                message: 'Reset zoom (100%)',
                child: InkWell(
                  onTap: resetZoom,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: Text(
                        '${(scale * 100).round()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Zoom in',
              onTap: canZoomIn ? zoomIn : null,
              color: canZoomIn ? AppColors.textPrimary : AppColors.textLight,
            ),
            Container(
              height: 18,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: AppColors.adminBorder,
            ),
            isRefreshing
                ? const Padding(
                    padding: EdgeInsets.all(7),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.adminAccent),
                      ),
                    ),
                  )
                : _buildIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Reload data',
                    onTap: handleRefresh,
                    color: AppColors.adminAccent,
                  ),
          ],
        ),
      );
    }

    // Collapsed vertical capsule
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.adminBorder.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Zoom in',
            onTap: canZoomIn ? zoomIn : null,
            color: canZoomIn ? AppColors.textPrimary : AppColors.textLight,
            size: 16,
          ),
          Tooltip(
            message: 'Reset zoom (100%)',
            child: InkWell(
              onTap: resetZoom,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Text(
                  '${(scale * 100).round()}%',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          _buildIconButton(
            icon: Icons.remove_rounded,
            tooltip: 'Zoom out',
            onTap: canZoomOut ? zoomOut : null,
            color: canZoomOut ? AppColors.textPrimary : AppColors.textLight,
            size: 16,
          ),
          Container(
            width: 20,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 3),
            color: AppColors.adminBorder,
          ),
          isRefreshing
              ? const Padding(
                  padding: EdgeInsets.all(5),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.adminAccent),
                    ),
                  ),
                )
              : _buildIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Reload data',
                  onTap: handleRefresh,
                  color: AppColors.adminAccent,
                  size: 16,
                ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    Color? color,
    double size = 18,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.adminAccent.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: size,
              color: onTap == null
                  ? AppColors.textLight
                  : (color ?? AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
