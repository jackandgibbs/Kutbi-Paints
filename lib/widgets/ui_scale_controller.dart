import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../providers/ui_scale_provider.dart';
import '../providers/global_refresh_provider.dart';

class UIScaleController extends ConsumerWidget {
  const UIScaleController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(uiScaleProvider);
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canPop) ...[
                  _buildBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  Container(
                    height: 24,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
                _buildBtn(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    final newVal = (scale - 0.1).clamp(0.8, 1.5);
                    ref.read(uiScaleProvider.notifier).setScale(newVal);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VIEW',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${(scale * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBtn(
                  icon: Icons.add_rounded,
                  onTap: () {
                    final newVal = (scale + 0.1).clamp(0.8, 1.5);
                    ref.read(uiScaleProvider.notifier).setScale(newVal);
                  },
                ),
                Container(
                  height: 24,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _buildBtn(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    performSoftRefresh(ref);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
