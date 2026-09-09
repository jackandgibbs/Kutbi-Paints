import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// A widget that centers its child and constrains its maximum width based on
/// responsive breakpoints, preventing content from awkwardly stretching across
/// ultra-wide desktop and browser screens.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? Responsive.contentMaxWidth(context);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context));

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}

/// A specialized responsive container tailored for forms, auth cards, and dialogs.
class ResponsiveForm extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveForm({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? Responsive.formMaxWidth(context);
    final effectivePadding = padding ??
        EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context));

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}
