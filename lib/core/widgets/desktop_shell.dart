import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../utils/responsive.dart';

/// A desktop shell that provides a sidebar navigation + optional top bar.
/// On mobile-width windows, it falls back to showing just the [body].
///
/// Usage:
/// ```dart
/// DesktopShell(
///   currentIndex: _currentIndex,
///   onIndexChanged: (i) => setState(() => _currentIndex = i),
///   items: [ DesktopNavItem(...), ... ],
///   body: _tabs[_currentIndex],
///   userName: 'Admin',
///   userRole: 'System Admin',
/// )
/// ```
class DesktopShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<DesktopNavItem> items;
  final Widget body;
  final String? userName;
  final String? userRole;
  final VoidCallback? onLogout;
  final VoidCallback? onRefresh;
  /// If provided, shown as a mobile scaffold with bottom nav instead.
  final Widget? mobileBody;

  const DesktopShell({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.items,
    required this.body,
    this.userName,
    this.userRole,
    this.onLogout,
    this.onRefresh,
    this.mobileBody,
  });

  @override
  Widget build(BuildContext context) {
    // On mobile, just return the mobileBody or body directly
    if (!Responsive.isDesktop(context)) {
      return mobileBody ?? body;
    }

    return Scaffold(
      backgroundColor: AppColors.adminBg,
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────
          _DesktopSidebar(
            currentIndex: currentIndex,
            onIndexChanged: onIndexChanged,
            items: items,
            userName: userName,
            userRole: userRole,
            onLogout: onLogout,
            onRefresh: onRefresh,
          ),
          // ── Content ────────────────────────────────────────────
          Expanded(child: body),
        ],
      ),
    );
  }
}

class DesktopNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final Color? glowColor;
  final int badgeCount;

  const DesktopNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.glowColor,
    this.badgeCount = 0,
  });
}

class _DesktopSidebar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<DesktopNavItem> items;
  final String? userName;
  final String? userRole;
  final VoidCallback? onLogout;
  final VoidCallback? onRefresh;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onIndexChanged,
    required this.items,
    this.userName,
    this.userRole,
    this.onLogout,
    this.onRefresh,
  });

  @override
  State<_DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<_DesktopSidebar> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWideDesktop(context);
    final sidebarWidth = isWide
        ? Responsive.sidebarWidth
        : Responsive.sidebarCollapsedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: sidebarWidth,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.adminAccent.withValues(alpha: 0.03),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Logo header ──────────────────────────
          _buildLogo(isWide),

          const SizedBox(height: 8),

          // ── Nav Items ────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: List.generate(widget.items.length, (i) {
                return _SidebarNavTile(
                  item: widget.items[i],
                  isSelected: widget.currentIndex == i,
                  isExpanded: isWide,
                  onTap: () => widget.onIndexChanged(i),
                );
              }),
            ),
          ),

          // ── Refresh button ────────────────────────
          if (widget.onRefresh != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _isRefreshing ? null : () async {
                    setState(() => _isRefreshing = true);
                    widget.onRefresh!();
                    await Future.delayed(const Duration(milliseconds: 1500));
                    if (mounted) setState(() => _isRefreshing = false);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 14 : 0,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: _isRefreshing
                          ? AppColors.adminAccent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: isWide
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        _isRefreshing
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      AppColors.adminAccent),
                                ),
                              )
                            : Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                        if (isWide) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isRefreshing ? 'Refreshing...' : 'Refresh Data',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _isRefreshing
                                    ? AppColors.adminAccent
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // ── User info + Logout ───────────────────
          if (widget.onLogout != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              height: 1,
              color: AppColors.adminBorder.withValues(alpha: 0.4),
            ),
            _buildLogoutTile(isWide),
          ],

          // ── User identity ────────────────────────
          if (widget.userName != null) _buildUserInfo(isWide),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isWide) {
    return Container(
      padding: EdgeInsets.fromLTRB(isWide ? 20 : 16, 28, isWide ? 20 : 16, 12),
      child: Row(
        mainAxisAlignment: isWide ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (isWide) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KUTBI',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 2,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Hardware & Paints',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutTile(bool isWide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onLogout,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 14 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: isWide ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                if (isWide) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(bool isWide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 20 : 12, 12, isWide ? 20 : 12, 0),
      child: Row(
        mainAxisAlignment: isWide ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.8),
                  AppColors.primaryLight,
                ],
              ),
            ),
            child: Center(
              child: Text(
                widget.userName != null && widget.userName!.isNotEmpty
                    ? widget.userName![0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (isWide) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.userRole != null)
                    Text(
                      widget.userRole!,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarNavTile extends StatefulWidget {
  final DesktopNavItem item;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.item.glowColor ?? AppColors.adminAccent;
    final icon = widget.isSelected
        ? (widget.item.activeIcon ?? widget.item.icon)
        : widget.item.icon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? color.withValues(alpha: 0.1)
                : (_hovering ? Colors.black.withValues(alpha: 0.03) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: color.withValues(alpha: 0.2))
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isExpanded ? 14 : 0,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisAlignment: widget.isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: widget.isSelected ? color : AppColors.textSecondary,
                        ),
                        if (widget.item.badgeCount > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              constraints: const BoxConstraints(minWidth: 14, minHeight: 12),
                              child: Text(
                                widget.item.badgeCount > 99
                                    ? '99+'
                                    : '${widget.item.badgeCount}',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.isExpanded) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: widget.isSelected
                                ? color
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.item.badgeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.item.badgeCount}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
