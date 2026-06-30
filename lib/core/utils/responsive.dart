import 'package:flutter/material.dart';

/// Centralized responsive breakpoint utility for adaptive layouts.
///
/// Usage:
/// ```dart
/// final cols = Responsive.value<int>(context, mobile: 2, tablet: 3, desktop: 4);
/// final isWide = Responsive.isDesktop(context);
/// ```
class Responsive {
  Responsive._();

  // ── Breakpoints ───────────────────────────────────────────────────
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // ── Boolean Helpers ──────────────────────────────────────────────
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreakpoint && w < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// True for tablet or desktop.
  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint;

  // ── Value Picker ──────────────────────────────────────────────────
  /// Returns a value based on the current screen width bracket.
  /// [tablet] defaults to [mobile] if not provided.
  /// [desktop] defaults to [tablet] (or [mobile]) if not provided.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= tabletBreakpoint) return desktop ?? tablet ?? mobile;
    if (w >= mobileBreakpoint) return tablet ?? mobile;
    return mobile;
  }

  // ── Layout Constants ──────────────────────────────────────────────
  
  /// Global UI scale multiplier (controlled by user on desktop)
  static double uiScale = 1.0;

  /// Maximum width for form-like content (login, register, etc.)
  static double formMaxWidth(BuildContext context) =>
      value(context, mobile: double.infinity, tablet: 520.0, desktop: 560.0) * uiScale;

  /// Maximum width for main content area on desktop
  static double contentMaxWidth(BuildContext context) =>
      value(context, mobile: double.infinity, tablet: 800.0, desktop: 1100.0) * uiScale;

  /// Horizontal padding for page content
  static double horizontalPadding(BuildContext context) =>
      value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0) * uiScale;

  /// Number of grid columns for card grids
  static int gridColumns(BuildContext context) =>
      value(context, mobile: 2, tablet: 3, desktop: 4);

  /// Sidebar width for desktop navigation
  static double get sidebarWidth => 260.0 * uiScale;
  static double get sidebarCollapsedWidth => 72.0 * uiScale;
}
