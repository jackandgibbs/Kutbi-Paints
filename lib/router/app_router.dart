import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/pending_approval_screen.dart';
import '../features/painter/painter_home_screen.dart';
import '../features/painter/complete_selfie_screen.dart';
import '../core/utils/platform_support.dart';
import '../features/painter/brand_product_screen.dart';
import '../features/painter/birla_opus_screen.dart';
import '../features/painter/berger_screen.dart';
import '../features/painter/asian_paints_screen.dart';
import '../features/painter/tools_screen.dart';
import '../features/painter/order_form_screen.dart';
import '../features/painter/order_item_screen.dart';
import '../features/painter/order_history_screen.dart';
import '../features/painter/order_detail_screen.dart';
import '../features/painter/painter_profile_screen.dart';
import '../features/painter/painter_scanner_screen.dart';
import '../features/painter/painter_rewards_screen.dart';
import '../features/painter/painter_rewards_history_screen.dart';
import '../features/painter/painter_analytics_screen.dart';
import '../features/painter/painter_ledger_screen.dart';
import '../features/painter/pending_debt_screen.dart';
import '../features/painter/painter_bills_screen.dart';
import '../features/painter/painter_udhaari_screen.dart';
import '../features/painter/cart_screen.dart';
import '../features/painter/painter_bank_details_screen.dart';
import '../features/painter/painter_bank_rejected_screen.dart';
import '../features/shared/order_chat_screen.dart';
import '../features/shared/global_chat_list_screen.dart';
import '../features/admin/admin_main_screen.dart';
import '../features/admin/admin_pending_bills_screen.dart';
import '../features/admin/admin_secret_login_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_qr_generator_screen.dart';
import '../features/admin/admin_promotions_screen.dart';
import '../features/admin/admin_reward_points_screen.dart';
import '../features/admin/user_management_screen.dart';
import '../features/admin/add_painter_screen.dart';
import '../features/admin/inventory_screen.dart';
import '../features/admin/add_product_screen.dart';
import '../features/admin/order_management_screen.dart';
import '../features/admin/order_detail_admin_screen.dart';
import '../features/admin/user_activity_screen.dart';
import '../features/admin/goal_setting_screen.dart';
import '../features/admin/admin_analytics_screen.dart';
import '../features/admin/scanner_screen.dart';
import '../features/admin/admin_payments_screen.dart';
import '../features/admin/admin_settings_screen.dart';
import '../features/admin/pending_bills_screen.dart';
import '../features/admin/generated_bills_screen.dart';
import '../features/admin/admin_pin_reset_screen.dart';
import '../features/admin/stock_management_screen.dart';
import '../features/admin/points_history_screen.dart';
import '../features/admin/deleted_qrs_screen.dart';
import '../features/admin/brands_categories_screen.dart';
import '../features/admin/brand_detail_screen.dart';
import '../features/admin/admin_commissions_screen.dart';
import '../features/admin/admin_reset_points_screen.dart';
import '../features/admin/admin_bank_details_screen.dart';


/// Bridges Riverpod auth-state changes into a [Listenable] so GoRouter can
/// re-run its `redirect` logic WITHOUT the whole router being rebuilt.
///
/// Previously `routerProvider` did `ref.watch(authProvider)`, so every auth
/// change created a brand-new GoRouter and swapped it into MaterialApp.router.
/// Recreating the router tears the entire Navigator down while inherited
/// widgets still have dependents — which throws the framework assertion
/// `'_dependents.isEmpty': is not true` on the next navigation (pop/push).
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // Build the router ONCE. Auth changes only ping the refresh listenable, which
  // makes GoRouter re-evaluate redirects against fresh state — no teardown.
  final refresh = _AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  // Smooth fade + subtle scale transition for all pages
  CustomTransitionPage<void> _fadeTransitionPage({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeIn = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final fadeOut = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: fadeIn,
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.85).animate(fadeOut),
            child: child,
          ),
        );
      },
    );
  }

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Read the CURRENT auth state each time redirect runs (the router is no
      // longer rebuilt on auth changes; the refreshListenable re-runs this).
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.isLoggedIn;
      final isSplashRoute = state.matchedLocation == '/splash';
      final isLoginRoute = state.matchedLocation == '/login';
      final isRegisterRoute = state.matchedLocation == '/register';
      final isPendingRoute = state.matchedLocation == '/pending-approval';
      final isSecretAdminRoute = state.matchedLocation == '/admin-secret-login';
      final isAdminDashboardRoute = state.matchedLocation == '/admin-dashboard';

      // Let splash screen handle its own navigation
      if (isSplashRoute) return null;

      if (!isLoggedIn &&
          !isLoginRoute &&
          !isRegisterRoute &&
          !isPendingRoute &&
          !isSecretAdminRoute &&
          !isAdminDashboardRoute) {
        return '/login';
      }

      if (isLoggedIn && authState.error == 'pending_approval') {
        return '/pending-approval';
      }

      // Forced selfie gate: painters on mobile must have a profile photo before
      // accessing the app. Skipped on desktop (no camera capture there).
      final isSelfieRoute = state.matchedLocation == '/painter/complete-selfie';
      final needsSelfie = isLoggedIn &&
          authState.isPainter &&
          !PlatformSupport.isDesktop &&
          (authState.user?.profileImageUrl == null ||
              authState.user!.profileImageUrl!.isEmpty);
      if (needsSelfie && !isSelfieRoute) {
        return '/painter/complete-selfie';
      }
      // Don't let a user who already has a photo sit on the selfie screen.
      if (isSelfieRoute && !needsSelfie) {
        return '/painter';
      }

      // Bank rejection gate: if painter's bank details were rejected and they
      // haven't seen the rejection message yet, force them to the rejection screen.
      final isBankRejectedRoute = state.matchedLocation == '/painter/bank-rejected';
      final needsBankRejectionGate = isLoggedIn &&
          authState.isPainter &&
          authState.user?.bankStatus == 'rejected' &&
          authState.user?.bankRejectionSeen == false;
      if (needsBankRejectionGate && !isBankRejectedRoute) {
        return '/painter/bank-rejected';
      }
      // Don't let a painter who's already seen the rejection sit on the rejection screen.
      if (isBankRejectedRoute && !needsBankRejectionGate) {
        return '/painter';
      }

      if (isLoggedIn && (isLoginRoute || isRegisterRoute)) {
        if (authState.isAdmin) return '/admin';
        return '/painter';
      }

      // Specialized brand flows
      if (state.matchedLocation == '/painter/brand/Birla Opus') {
        return '/painter/birla-opus';
      }
      if (state.matchedLocation == '/painter/brand/Berger') {
        return '/painter/berger';
      }
      if (state.matchedLocation == '/painter/brand/Asian Paints') {
        return '/painter/asian-paints';
      }
      if (state.matchedLocation == '/painter/brand/Tools') {
        return '/painter/tools';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),

      // ─── Painter Routes ──────────────────────────────
      GoRoute(
        path: '/painter',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/complete-selfie',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const CompleteSelfieScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/brand/:brand',
        pageBuilder: (context, state) {
          final brand = Uri.decodeComponent(state.pathParameters['brand']!);
          // Every dynamically-created brand renders with the shared, Birla-Opus
          // style template (same structure/navigation), differing only in data.
          return _fadeTransitionPage(
            state: state,
            child: BrandProductScreen(brand: brand),
          );
        },
      ),
      GoRoute(
        path: '/painter/birla-opus',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const BirlaOpusScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/berger',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const BergerScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/asian-paints',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AsianPaintsScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/tools',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const ToolsScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/order/:brand',
        pageBuilder: (context, state) {
          final brand = Uri.decodeComponent(state.pathParameters['brand']!);
          final productId = state.uri.queryParameters['productId'];
          final size = state.uri.queryParameters['size'];
          final qty = int.tryParse(state.uri.queryParameters['qty'] ?? '');
          return _fadeTransitionPage(
            state: state,
            child: OrderFormScreen(
              brand: brand,
              initialProductId: productId,
              initialSize: size,
              initialQty: qty,
            ),
          );
        },
      ),
      GoRoute(
        path: '/painter/order-item/:productId',
        pageBuilder: (context, state) {
          final productId = state.pathParameters['productId']!;
          final size = state.uri.queryParameters['size'];
          final qty = int.tryParse(state.uri.queryParameters['qty'] ?? '');
          final canCustomize = state.uri.queryParameters['canCustomize'] != 'false';
          return _fadeTransitionPage(
            state: state,
            child: OrderItemScreen(
              productId: productId,
              initialSize: size,
              initialQty: qty,
              canCustomize: canCustomize,
            ),
          );
        },
      ),
      GoRoute(
        path: '/painter/orders',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const OrderHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/order-detail/:orderId',
        pageBuilder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return _fadeTransitionPage(
            state: state,
            child: OrderDetailScreen(orderId: orderId),
          );
        },
      ),
      GoRoute(
        path: '/chats',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const GlobalChatListScreen(),
        ),
      ),
      GoRoute(
        path: '/order/:orderId/chat',
        pageBuilder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return _fadeTransitionPage(
            state: state,
            child: OrderChatScreen(orderId: orderId),
          );
        },
      ),

      GoRoute(
        path: '/painter/profile',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/scanner',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterScannerScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/rewards',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterRewardsScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/rewards/history',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterRewardsHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/analytics',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterAnalyticsScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/cart',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const CartScreen(),
        ),
      ),

      GoRoute(
        path: '/painter/bank-details',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterBankDetailsScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/bank-rejected',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterBankRejectedScreen(),
        ),
      ),

      GoRoute(
        path: '/painter/ledger',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterLedgerScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/pending-debt',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PendingDebtScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/bills',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterBillsScreen(),
        ),
      ),
      GoRoute(
        path: '/painter/udhaari',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PainterUdhaariScreen(),
        ),
      ),

      // ─── Admin Routes ────────────────────────────────
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminMainScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/users',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const UserManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/add-painter',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AddPainterScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/inventory',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const InventoryScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/add-product',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AddProductScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/edit-product/:productId',
        pageBuilder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return _fadeTransitionPage(
            state: state,
            child: AddProductScreen(productId: productId),
          );
        },
      ),
      GoRoute(
        path: '/admin/orders',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const OrderManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/order-detail/:orderId',
        pageBuilder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return _fadeTransitionPage(
            state: state,
            child: OrderDetailAdminScreen(orderId: orderId),
          );
        },
      ),
      GoRoute(
        path: '/admin/user-activity/:painterId',
        pageBuilder: (context, state) {
          final painterId = state.pathParameters['painterId']!;
          return _fadeTransitionPage(
            state: state,
            child: UserActivityScreen(painterId: painterId),
          );
        },
      ),
      GoRoute(
        path: '/admin/goals',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const GoalSettingScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/analytics',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminAnalyticsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/reward-points',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminRewardPointsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/payments',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminPaymentsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/scanner',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const ScannerScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/promotions',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminPromotionsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/settings',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/qr-generator',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminQRGeneratorScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/deleted-qrs',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const DeletedQRsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/pending-bills',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminPendingBillsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/generated-bills',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const GeneratedBillsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/stock-management',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const StockManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/points-history',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const PointsHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/reset-pin',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminPinResetScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/commissions',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminCommissionsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/reset-points',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminResetPointsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/brands',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const BrandsCategoriesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/bank-details',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminBankDetailsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/brand-detail/:brand',
        pageBuilder: (context, state) {
          final brand = Uri.decodeComponent(state.pathParameters['brand']!);
          return _fadeTransitionPage(
            state: state,
            child: BrandDetailScreen(brandName: brand),
          );
        },
      ),
      GoRoute(
        path: '/admin-secret-login',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminSecretLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/admin-dashboard',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AdminDashboardScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
