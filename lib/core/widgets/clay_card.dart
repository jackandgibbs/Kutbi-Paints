import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A claymorphism-styled card with soft dual shadows,
/// pastel background surface, and extruded 3D appearance.
class ClayCard extends StatelessWidget {
  final Widget child;
  final Color? surfaceColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double depth;
  final bool useShadow;

  const ClayCard({
    super.key,
    required this.child,
    this.surfaceColor,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(18),
    this.depth = 1.0,
    this.useShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = surfaceColor ?? AppColors.clayBase;
    
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: useShadow ? [
          // Light shadow — top-left (raised highlight)
          BoxShadow(
            color: AppColors.clayLightShadow.withValues(alpha: 0.6 * depth),
            blurRadius: 8 * depth,
            offset: Offset(-3 * depth, -3 * depth),
          ),
          // Dark shadow — bottom-right (cast shadow)
          BoxShadow(
            color: AppColors.clayDarkShadow.withValues(alpha: 0.35 * depth),
            blurRadius: 10 * depth,
            offset: Offset(4 * depth, 4 * depth),
          ),
        ] : null,
      ),
      child: child,
    );
  }
}

/// Animated version of ClayCard that lifts slightly on tap.
class AnimatedClayCard extends StatefulWidget {
  final Widget child;
  final Color? surfaceColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool useShadow;

  const AnimatedClayCard({
    super.key,
    required this.child,
    this.surfaceColor,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.useShadow = true,
  });

  @override
  State<AnimatedClayCard> createState() => _AnimatedClayCardState();
}

class _AnimatedClayCardState extends State<AnimatedClayCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _liftAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _liftAnim = Tween<double>(begin: 0, end: -2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _liftAnim.value),
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: ClayCard(
                surfaceColor: widget.surfaceColor,
                borderRadius: widget.borderRadius,
                padding: widget.padding,
                depth: 1.0 + (_liftAnim.value * -0.1),
                useShadow: widget.useShadow,
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}
