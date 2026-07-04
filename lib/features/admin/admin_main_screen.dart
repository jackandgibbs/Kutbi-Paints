import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/platform_support.dart';
import '../../core/widgets/desktop_shell.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import 'admin_home_screen.dart';
import 'admin_bills_tab.dart';
import 'admin_inventory_tab.dart';
import 'admin_goals_tab.dart';
import 'admin_support_tab.dart';
import 'admin_settings_screen.dart';

class AdminMainScreen extends ConsumerStatefulWidget {
  const AdminMainScreen({super.key});

  @override
  ConsumerState<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends ConsumerState<AdminMainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  late final FToast _fToast;
  late final List<Widget> _tabs;
  late final AnimationController _navGlowController;
  late final AnimationController _rippleController;
  late final PageController _pageController;

  // Glow colors for each tab
  static const List<Color> _tabGlowColors = [
    Color(0xFF635BFF), // Home – indigo
    Color(0xFF0EA5E9), // Inventory – sky blue
    Color(0xFFF97316), // Bills – orange
    Color(0xFF10B981), // Goals – emerald
    Color(0xFF8B5CF6), // Support – violet
    Color(0xFF64748B), // Settings – slate
    Color(0xFFEF4444), // Logout – red
  ];

  static const List<IconData> _tabIcons = [
    Icons.home_rounded,
    Icons.inventory_2_rounded,
    Icons.shopping_bag_rounded,
    Icons.flag_rounded,
    Icons.support_agent_rounded,
    Icons.settings_suggest_rounded,
    Icons.logout_rounded,
  ];

  static const List<String> _tabLabels = [
    'Home',
    'Inventory',
    'Bills',
    'Goals',
    'Support',
    'Settings',
    'Logout',
  ];

  @override
  void initState() {
    super.initState();
    _fToast = FToast();
    _tabs = const [
      AdminHomeScreen(),
      AdminInventoryTab(),
      AdminBillsTab(),
      AdminGoalsTab(),
      AdminSupportTab(),
      AdminSettingsScreen(),
    ];
    _navGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _navGlowController.dispose();
    _rippleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    // Logout – show dialog instead of switching tab
    if (index == 6) {
      _showLogoutDialog();
      return;
    }

    if (PlatformSupport.supportsHaptics) {
      HapticFeedback.lightImpact();
    }
    _rippleController.forward(from: 0.0);
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  void _onDesktopTabChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Color(0xFFEF4444), size: 30),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Logout?',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Are you sure you want to\nlog out of Admin Panel?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final router = GoRouter.of(context);
                              Navigator.of(ctx).pop();
                              await ref.read(authProvider.notifier).logout();
                              router.go('/login');
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEF4444),
                                    Color(0xFFDC2626),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Logout',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DesktopNavItem> _buildDesktopNavItems() {
    final ds = ref.watch(dataServiceProvider);
    return [
      DesktopNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        glowColor: _tabGlowColors[0],
      ),
      DesktopNavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        label: 'Inventory',
        glowColor: _tabGlowColors[1],
        badgeCount: ds.getLowStockAlerts().length,
      ),
      DesktopNavItem(
        icon: Icons.shopping_bag_outlined,
        activeIcon: Icons.shopping_bag_rounded,
        label: 'Bills',
        glowColor: _tabGlowColors[2],
        badgeCount: ds.getOrdersByStatus('placed').length,
      ),
      DesktopNavItem(
        icon: Icons.flag_outlined,
        activeIcon: Icons.flag_rounded,
        label: 'Goals',
        glowColor: _tabGlowColors[3],
        badgeCount: _getBadgeCount(3),
      ),
      DesktopNavItem(
        icon: Icons.support_agent_outlined,
        activeIcon: Icons.support_agent_rounded,
        label: 'Support',
        glowColor: _tabGlowColors[4],
        badgeCount: _getBadgeCount(4),
      ),
      DesktopNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
        glowColor: _tabGlowColors[5],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final user = ref.watch(authProvider).user;

    if (isDesktop) {
      return DesktopShell(
        currentIndex: _currentIndex,
        onIndexChanged: _onDesktopTabChanged,
        items: _buildDesktopNavItems(),
        userName: user?.name ?? 'Admin',
        userRole: 'System Admin',
        onLogout: _showLogoutDialog,
        onRefresh: () => ref.read(dataServiceProvider).refresh(),
        body: _tabs[_currentIndex],
      );
    }

    // ── Mobile layout (original) ─────────────────────────────────
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If not on home tab, go to home tab
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          _pageController.jumpToPage(0);
          return;
        }

        // 2. Double-tap to exit logic
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          _fToast.init(context);
          _fToast.showToast(
            toastDuration: const Duration(seconds: 2),
            gravity: ToastGravity.BOTTOM,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Press back one more time to exit the app',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
          );
          return;
        }

        // 3. Exit app
        if (PlatformSupport.supportsSystemNavPop) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.adminBg,
      body: Stack(
        children: [
          // Current tab
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _rippleController.forward(from: 0.0);
              if (PlatformSupport.supportsHaptics) {
                HapticFeedback.lightImpact();
              }
            },
            children: _tabs,
          ),

          // Modern scrollable bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildModernNavBar(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildModernNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (i) => _buildModernNavItem(i)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavItem(int index) {
    final isSelected = _currentIndex == index;
    final color = _tabGlowColors[index];
    final badgeCount = _getBadgeCount(index);
    final label = _tabLabels[index];
    final icon = _tabIcons[index];

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.25), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? color : AppColors.textSlateLight,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 13),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
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
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Row(
                      children: [
                        const SizedBox(width: 7),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a notification count for each tab index.
  int _getBadgeCount(int index) {
    final ds = ref.watch(dataServiceProvider);
    switch (index) {
      case 1: // Inventory – low stock alerts
        return ds.getLowStockAlerts().length;
      case 2: // Bills – pending bills + pending payments
        final pendingBills = ds.getOrdersForBilling().length;
        final pendingPayments = ds.getAllOrders().where((o) =>
            o.paymentStatus == 'pending' || o.paymentStatus == 'partially_paid'
        ).length;
        return pendingBills + pendingPayments;
      case 3: // Goals – pending painter approvals
        return ds.getPaintersByStatus('inactive').length;
      case 4: // Support – track unread customer messages
        return ds.getUnreadSupportCount();
      default:
        return 0;
    }
  }
}
