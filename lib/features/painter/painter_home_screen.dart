import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/platform_support.dart';
import '../../core/widgets/desktop_shell.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../services/cart_service.dart';
import '../../models/user_model.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../core/services/haptic_service.dart';
import '../shared/widgets/skeleton_loaders.dart';
import '../shared/widgets/product_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/skeuomorphic_background.dart';
import '../../core/widgets/clay_card.dart';
import '../../core/widgets/glass_brand_card.dart';
import '../../core/widgets/liquid_glass_navbar.dart';

class PainterHomeScreen extends ConsumerStatefulWidget {
  const PainterHomeScreen({super.key});

  @override
  ConsumerState<PainterHomeScreen> createState() => _PainterHomeScreenState();
}

class _PainterHomeScreenState extends ConsumerState<PainterHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  late final FToast _fToast;
  late final PageController _pageController;

  void _onItemTapped(int index) {
    HapticService.light();
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _fToast = FToast();
    _pageController = PageController(initialPage: _currentIndex);
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<DesktopNavItem> _buildDesktopNavItems() {
    return const [
      DesktopNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        glowColor: Color(0xFF4F8CFF),
      ),
      DesktopNavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'Orders',
        glowColor: Color(0xFFFF6BB5),
      ),
      DesktopNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
        glowColor: Color(0xFF4FD1A5),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final dataService = ref.watch(dataServiceProvider);
    final isDesktop = Responsive.isDesktop(context);

    if (user == null) return const SizedBox.shrink();

    // ── Desktop layout — sidebar shell ────────────────────────────
    if (isDesktop) {
      final tabs = [
        _buildHomeTab(user, dataService),
        _buildOrdersTab(dataService),
        _buildProfileTab(user),
      ];
      return DesktopShell(
        currentIndex: _currentIndex,
        onIndexChanged: (i) => setState(() => _currentIndex = i),
        items: _buildDesktopNavItems(),
        userName: user.name,
        userRole: user.tier.toUpperCase(),
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        },
        onRefresh: () => ref.read(dataServiceProvider).refresh(),
        body: SkeuomorphicBackground(
          child: tabs[_currentIndex],
        ),
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
                      style: GoogleFonts.poppins(
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
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: SkeuomorphicBackground(
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              HapticService.light();
            },
            children: [
              RepaintBoundary(child: KeepAliveWrapper(child: _buildHomeTab(user, dataService))),
              RepaintBoundary(child: KeepAliveWrapper(child: _buildOrdersTab(dataService))),
              RepaintBoundary(child: KeepAliveWrapper(child: _buildProfileTab(user))),
            ],
          ),
        ),
        bottomNavigationBar: LiquidGlassNavbar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }



  // ─── HOME TAB ──────────────────────────────────────────────────
  Widget _buildHomeTab(dynamic user, DataService ds) {
    final recentOrders = ds.getOrdersByPainter(user.id);
    final totalBuckets = ds.getTotalBucketsForPainter(user.id);
    final lastProducts = ds.getLastOrderedProducts(user.id);
    final totalProducts = ds.getAllProducts().length;

    final hPad = Responsive.horizontalPadding(context);
    final isDesktopView = Responsive.isDesktop(context);

    return RefreshIndicator(
      onRefresh: ds.refresh,
      child: CustomScrollView(
        slivers: [
// App Bar Header (ClayCard style)
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 20),
              child: ClayCard(
                borderRadius: 24,
                surfaceColor: AppColors.clayPastelBlue,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                useShadow: false,
                child: Row(
                  children: [
                    ClayCard(
                      borderRadius: 14,
                      surfaceColor: AppColors.clayBase,
                      padding: const EdgeInsets.all(0),
                      useShadow: false,
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8C8FB4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.welcomeBack,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            user.name.isNotEmpty ? '${user.name[0].toUpperCase()}${user.name.substring(1)}' : '',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            user.tier.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: user.isGold ? AppColors.goldTier : AppColors.textPrimary.withValues(alpha: 0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClayCard(
                      borderRadius: 14,
                      surfaceColor: AppColors.clayBase,
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        onPressed: () => context.push('/painter/scanner'),
                        icon: const Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.primary, size: 24),
                        tooltip: 'Scan for Points',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClayCard(
                      borderRadius: 14,
                      surfaceColor: AppColors.clayBase,
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        onPressed: () => context.push('/chats'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            color: AppColors.primary, size: 24),
                        tooltip: 'Messages',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
        ),

        SliverToBoxAdapter(
          child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, isDesktopView ? 40 : 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!ds.isLoaded)
                const Column(
                  children: [
                    DashboardCardSkeleton(),
                    SizedBox(height: 12),
                    DashboardCardSkeleton(),
                    SizedBox(height: 28),
                    OrderTileSkeleton(),
                    OrderTileSkeleton(),
                  ],
                )
              else
                AnimationLimiter(
                  child: Column(
                    children: AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 375),
                      childAnimationBuilder: (widget) => SlideAnimation(
                        horizontalOffset: 50.0,
                        child: FadeInAnimation(child: widget),
                      ),
                      children: [
              // ─── 2 Stat Cards (1 row) ────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/painter/orders'),
                      child: _statCardRaw(
                        'Buckets Ordered',
                        '$totalBuckets',
                        Icons.inventory_2_rounded,
                        const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/painter/rewards'),
                      child: _statCardRaw(
                        'Reward Points',
                        '${ds.users.firstWhere((u) => u.id == user.id, orElse: () => user).points}',
                        Icons.stars_rounded,
                        const Color(0xFFFFD700), // Gold
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (ctx) {
                  final liveUser = ds.users.firstWhere((u) => u.id == user.id, orElse: () => user);
                  final nextMilestone = ds.getNextMilestoneForPainter(user.id);
                  if (nextMilestone == null) return const SizedBox.shrink();
                  
                  double progress = 0;
                  if (nextMilestone.targetPoints > 0) {
                    progress = liveUser.points / nextMilestone.targetPoints;
                    if (progress > 1.0) progress = 1.0;
                  }
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text('Next Milestone', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ],
                            ),
                            Text('${nextMilestone.targetPoints - liveUser.points} pts away', 
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(nextMilestone.rewardTitle, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/painter/bills'),
                child: _wideStatCard(
                  'My Bills',
                  '${ds.getBilledOrdersForPainter(user.id).length} Bills',
                  Icons.receipt_long_rounded,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/painter/analytics'),
                child: _wideStatCard(
                  AppLocalizations.of(context)!.myPerformance,
                  'View Stats',
                  Icons.analytics_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 28),



              // ─── Quick Reorder Section ────────────────────
              if (lastProducts.isNotEmpty) ...[
                Text(
                  'Quick Reorder',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to reorder your recent paints',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 105,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: lastProducts.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) => _quickReorderCard(lastProducts[i]),
                  ),
                ),
                const SizedBox(height: 28),
              ],


              // Select Brand Section
              Text(
                'Select Brand',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap a brand to browse products & order',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Brand Cards — use grid on desktop
              if (isDesktopView)
                _buildBrandCardsGrid(ds)
              else
                _buildBrandCardsList(ds),

              const SizedBox(height: 28),

              // Recent Orders
              if (recentOrders.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Orders',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/painter/orders'),
                      child: Text(
                        'View All',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...recentOrders
                    .take(3)
                    .map((order) => _orderCard(order)),
              ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
        ),
        ),
      ],
    ),
  );
}

  Widget _buildBrandCardsList(DataService ds) {
    return Column(
      children: [
        GlassBrandCard(
          brandName: 'Asian Paints',
          subtitle: 'Premium Quality Paints',
          imageUrl: 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/ap.png',
          gradientStart: AppColors.asianPaintsGradientStart,
          gradientEnd: AppColors.asianPaintsGradientEnd,
          glassTint: AppColors.asianPaintsGlassTint,
          productCount: '${ds.getProductsByBrand('Asian Paints').length} Products',
          onTap: () => context.push('/painter/asian-paints'),
        ),
        const SizedBox(height: 16),
        GlassBrandCard(
          brandName: 'Berger',
          subtitle: 'Color That Lasts',
          icon: Icons.brush_rounded,
          gradientStart: AppColors.bergerGradientStart,
          gradientEnd: AppColors.bergerGradientEnd,
          glassTint: AppColors.bergerGlassTint,
          productCount: '${ds.getProductsByBrand('Berger').length} Products',
          onTap: () => context.push('/painter/berger'),
        ),
        const SizedBox(height: 16),
        GlassBrandCard(
          brandName: 'Birla Opus',
          subtitle: 'Nature-Inspired Colors',
          imageUrl: 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/opus.png',
          gradientStart: AppColors.birlaOpusGradientStart,
          gradientEnd: AppColors.birlaOpusGradientEnd,
          glassTint: AppColors.birlaOpusGlassTint,
          productCount: '${ds.getProductsByBrand('Birla Opus').length} Products',
          onTap: () => context.push('/painter/birla-opus'),
        ),
        const SizedBox(height: 16),
        GlassBrandCard(
          brandName: 'Tools',
          subtitle: 'Professional Equipment',
          icon: Icons.construction_rounded,
          gradientStart: AppColors.toolsGradientStart,
          gradientEnd: AppColors.toolsGradientEnd,
          glassTint: AppColors.toolsGlassTint,
          productCount: '${ds.getProductsByBrand('Tools').length} Items',
          onTap: () => context.push('/painter/tools'),
        ),
      ],
    );
  }

  Widget _buildBrandCardsGrid(DataService ds) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 340,
          child: GlassBrandCard(
            brandName: 'Asian Paints',
            subtitle: 'Premium Quality Paints',
            imageUrl: 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/ap.png',
            gradientStart: AppColors.asianPaintsGradientStart,
            gradientEnd: AppColors.asianPaintsGradientEnd,
            glassTint: AppColors.asianPaintsGlassTint,
            productCount: '${ds.getProductsByBrand('Asian Paints').length} Products',
            onTap: () => context.push('/painter/asian-paints'),
          ),
        ),
        SizedBox(
          width: 340,
          child: GlassBrandCard(
            brandName: 'Berger',
            subtitle: 'Color That Lasts',
            icon: Icons.brush_rounded,
            gradientStart: AppColors.bergerGradientStart,
            gradientEnd: AppColors.bergerGradientEnd,
            glassTint: AppColors.bergerGlassTint,
            productCount: '${ds.getProductsByBrand('Berger').length} Products',
            onTap: () => context.push('/painter/berger'),
          ),
        ),
        SizedBox(
          width: 340,
          child: GlassBrandCard(
            brandName: 'Birla Opus',
            subtitle: 'Nature-Inspired Colors',
            imageUrl: 'https://mlzrqgocvenrwjnabljm.supabase.co/storage/v1/object/public/paint-images/brands/opus.png',
            gradientStart: AppColors.birlaOpusGradientStart,
            gradientEnd: AppColors.birlaOpusGradientEnd,
            glassTint: AppColors.birlaOpusGlassTint,
            productCount: '${ds.getProductsByBrand('Birla Opus').length} Products',
            onTap: () => context.push('/painter/birla-opus'),
          ),
        ),
        SizedBox(
          width: 340,
          child: GlassBrandCard(
            brandName: 'Tools',
            subtitle: 'Professional Equipment',
            icon: Icons.construction_rounded,
            gradientStart: AppColors.toolsGradientStart,
            gradientEnd: AppColors.toolsGradientEnd,
            glassTint: AppColors.toolsGlassTint,
            productCount: '${ds.getProductsByBrand('Tools').length} Items',
            onTap: () => context.push('/painter/tools'),
          ),
        ),
      ],
    );
  }



  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: _statCardRaw(label, value, icon, color),
    );
  }

  Widget _statCardRaw(String label, String value, IconData icon, Color color) {
    return ClayCard(
      surfaceColor: _getClayColor(color),
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      useShadow: false,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }





  Widget _wideStatCard(
      String label, String value, IconData icon, Color color) {
    return ClayCard(
      surfaceColor: _getClayColor(color),
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      useShadow: false,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickReorderCard(Map<String, dynamic> product) {
    final brandColor = AppColors.getBrandPrimary(product['brand'] as String);

    return SizedBox(
      width: 150,
      child: AnimatedClayCard(
        onTap: () => context.push(
            '/painter/order/${Uri.encodeComponent(product['brand'] as String)}?productId=${product['id']}&size=${Uri.encodeComponent(product['bucketSize'] as String)}&qty=${product['quantity']}'),
        padding: const EdgeInsets.all(12),
        borderRadius: 18,
        useShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductImage(
                  imageUrl: product['imageUrl'] as String?,
                  productId: product['id'] as String,
                  brand: product['brand'] as String,
                  size: 32,
                  borderRadius: 8,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['productName'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        product['brand'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product['bucketSize'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: brandColor,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.replay_rounded, size: 14, color: brandColor),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _orderCard(dynamic order) {
    final statusColor = _getStatusColor(order.status);
    return GestureDetector(
      onTap: () => context.push('/painter/order-detail/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.clayBase,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ProductImage(
              imageUrl: order.items.first.productImageUrl,
              productId: order.items.first.productId,
              brand: order.brand,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.brand,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${order.items.length} item${order.items.length > 1 ? 's' : ''}${order.status != 'pending_bill' && order.totalAmount > 0 ? ' • ₹${order.totalAmount.toStringAsFixed(0)}' : ' • Pending Bill'}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.status.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_bill':
        return const Color(0xFF7C3AED);
      case 'bill_sent':
        return const Color(0xFFD97706);
      case 'payment_selected':
        return const Color(0xFF059669);
      case 'placed':
        return AppColors.info;
      case 'accepted':
        return AppColors.primary;
      case 'preparing':
        return AppColors.warning;
      case 'dispatched':
        return const Color(0xFF7C3AED);
      case 'delivered':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  // ─── ORDERS TAB ────────────────────────────────────────────────
  Widget _buildOrdersTab(DataService ds) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    final orders = ds.getOrdersByPainter(user.id);
    final billedOrders = ds.getBilledOrdersForPainter(user.id);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('My Orders',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
      ),
      body: !ds.isLoaded
          ? ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: 5,
              itemBuilder: (ctx, i) => const OrderTileSkeleton(),
            )
          : RefreshIndicator(
              onRefresh: ds.refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  // Bills shortcut — Glassmorphism
                  GestureDetector(
                    onTap: () => context.push('/painter/bills'),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF7C3AED).withValues(alpha: 0.75),
                                  const Color(0xFF9333EA).withValues(alpha: 0.55),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded,
                                      color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'My Bills',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        billedOrders.isEmpty
                                            ? 'No pending bills'
                                            : '${billedOrders.length} bill${billedOrders.length > 1 ? 's' : ''} awaiting action',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (billedOrders.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${billedOrders.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: Colors.white70, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Udhaari shortcut
                  Builder(
                    builder: (context) {
                      final udhaariPending = orders.where((o) =>
                        o.paymentMethod == 'udhaari' && o.paymentStatus == 'udhaari' && !o.deletedByAdmin
                      ).toList();
                      final udhaariCompleted = orders.where((o) =>
                        o.paymentMethod == 'udhaari' && o.paymentStatus == 'udhaari_completed' && !o.deletedByAdmin
                      ).toList();
                      final totalUdhaari = udhaariPending.length + udhaariCompleted.length;

                      return GestureDetector(
                        onTap: () => context.push('/painter/udhaari'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFD97706).withValues(alpha: 0.75),
                                      const Color(0xFFF59E0B).withValues(alpha: 0.55),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.account_balance_wallet_rounded,
                                          color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'My Udhaari',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            totalUdhaari == 0
                                                ? 'No udhaari records'
                                                : '${udhaariPending.length} pending • ${udhaariCompleted.length} paid',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (udhaariPending.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${udhaariPending.length}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_ios_rounded,
                                        color: Colors.white70, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Deleted Orders shortcut
                  Builder(
                    builder: (context) {
                      final deletedOrders = orders.where((o) => o.deletedByAdmin).toList();

                      return GestureDetector(
                        onTap: () => context.push('/painter/orders'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFEF4444).withValues(alpha: 0.75),
                                      const Color(0xFFDC2626).withValues(alpha: 0.55),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded,
                                          color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Deleted Orders',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            deletedOrders.isEmpty
                                                ? 'No deleted orders'
                                                : '${deletedOrders.length} order${deletedOrders.length > 1 ? 's' : ''} deleted by admin',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (deletedOrders.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${deletedOrders.length}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_ios_rounded,
                                        color: Colors.white70, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Orders list
                  if (orders.isEmpty)
                    Container(
                      height: 300,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No orders yet',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              )),
                        ],
                      ),
                    )
                  else
                    ...orders.map((order) => _orderCard(order)),
                ],
              ),
            ),
    );
  }

  // ─── PROFILE TAB ───────────────────────────────────────────────
  Widget _buildProfileTab(dynamic user) {
    final ds = ref.watch(dataServiceProvider);
    final admins = ds.getAdmins();

    final tierColor = user.isGold ? AppColors.goldTier : AppColors.silverTier;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Claymorphic Profile Header ─────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 56, 16, 0),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                color: AppColors.clayBase,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  // Clay light shadow — top-left highlight
                  BoxShadow(
                    color: AppColors.clayLightShadow.withValues(alpha: 0.8),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(-6, -6),
                  ),
                  // Clay dark shadow — bottom-right depth
                  BoxShadow(
                    color: AppColors.clayDarkShadow.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(8, 8),
                  ),
                  // Very subtle inner ambient glow
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 3,
                    spreadRadius: -1,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar — clay-inset circle
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE8E4DE),
                      boxShadow: [
                        // Inset dark shadow (simulated)
                        BoxShadow(
                          color: AppColors.clayDarkShadow.withValues(alpha: 0.45),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(3, 3),
                        ),
                        // Inset light highlight
                        BoxShadow(
                          color: AppColors.clayLightShadow.withValues(alpha: 0.9),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(-3, -3),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.85),
                            const Color(0xFF1565C0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (user.businessName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.businessName!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Tier badge — skeuomorphic pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          tierColor.withValues(alpha: 0.25),
                          tierColor.withValues(alpha: 0.12),
                        ],
                      ),
                      border: Border.all(
                        color: tierColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tierColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: tierColor),
                        const SizedBox(width: 6),
                        Text(
                          '${user.tier.toUpperCase()} Member',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Skeuomorphic Info Cards Section ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              child: Column(
                children: [
                  // Language Switcher — Skeuomorphic
                  _skeuomorphicContainer(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Select Language',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _langBtn('English', const Locale('en')),
                            const SizedBox(width: 8),
                            _langBtn('हिंदी', const Locale('hi')),
                            const SizedBox(width: 8),
                            _langBtn('اردو', const Locale('ur')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Personal info — Skeuomorphic
                  _skeuoInfoTile(Icons.phone_rounded, 'Phone', user.phone),
                  _skeuoInfoTile(Icons.email_rounded, 'Email', user.email),
                  if (user.businessAddress != null)
                    _skeuoInfoTile(Icons.location_on_rounded, 'Address', user.businessAddress!),

                  // Support Admins
                  if (admins.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _skeuomorphicContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Support Admins',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...admins.map((admin) => _adminContactCard(admin)),
                        ],
                      ),
                    ),
                  ],

                  // Logout — Skeuomorphic button
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFEF5350), Color(0xFFD32F2F)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.15),
                          blurRadius: 1,
                          spreadRadius: 0,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      label: Text('Logout',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skeuomorphic container — embossed surface with light-source simulation
  Widget _skeuomorphicContainer({
    required Widget child,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8E4DD),
          width: 1,
        ),
        boxShadow: [
          // Outer cast shadow (depth)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          // Top-left edge highlight (light source)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(-2, -2),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFAF8F5), // light warm top-left
            Color(0xFFF0ECE6), // slightly darker bottom-right
          ],
        ),
      ),
      child: child,
    );
  }

  /// Skeuomorphic info tile — individual row with embossed icon container
  Widget _skeuoInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF6F3EE),
        border: Border.all(color: const Color(0xFFE8E4DD), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.65),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(-1.5, -1.5),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFAF8F5),
            Color(0xFFF0ECE6),
          ],
        ),
      ),
      child: Row(
        children: [
          // Skeuomorphic inset icon well
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFEBE7E0),
              boxShadow: [
                // Inner dark shadow (inset simulation)
                BoxShadow(
                  color: AppColors.clayDarkShadow.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
                // Inner light highlight
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 4,
                  offset: const Offset(-1.5, -1.5),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }




  void _showAdminContactOptions(UserModel admin) {
    final phone = admin.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappPhone = phone.length == 10 ? '91$phone' : phone;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Contact ${admin.name}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            // Call option
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.call_rounded, color: AppColors.success),
              ),
              title: Text(
                'Call',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                admin.phone,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
            const Divider(height: 1),
            // WhatsApp option
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              ),
              title: Text(
                'Message on WhatsApp',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Opens WhatsApp chat',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
              onTap: () {
                Navigator.pop(ctx);
                final message = Uri.encodeComponent('Hello ${admin.name}, I need help from Kutbi Paints support.');
                launchUrl(
                  Uri.parse('https://wa.me/$whatsappPhone?text=$message'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminContactCard(UserModel admin) {
    return GestureDetector(
      onTap: () => _showAdminContactOptions(admin),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ClayCard(
          borderRadius: 16,
          surfaceColor: AppColors.clayBase,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    admin.name.isNotEmpty ? admin.name.substring(0, 1).toUpperCase() : 'A',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      admin.phone,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_in_talk_rounded,
                    color: AppColors.success, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileInfoCard(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecondary)),
                Text(value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _langBtn(String label, Locale locale) {
    final currentLocale = ref.watch(localeProvider);
    final isSelected = currentLocale.languageCode == locale.languageCode;

    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(localeProvider.notifier).setLocale(locale),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getClayColor(Color color) {
    if (color == const Color(0xFF6366F1)) return AppColors.clayPastelPurple;
    if (color == const Color(0xFFEC4899)) return AppColors.clayPastelPink;
    if (color == AppColors.warning) return AppColors.clayPastelAmber;
    if (color == const Color(0xFF10B981)) return AppColors.clayPastelGreen;
    return AppColors.clayBase;
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}


