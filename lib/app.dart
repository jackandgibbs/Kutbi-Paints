import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'widgets/no_internet_overlay.dart';
import 'widgets/version_check_overlay.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/ui_scale_provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'services/data_service.dart';
import 'providers/global_refresh_provider.dart';
import 'core/widgets/lottie_loading_widget.dart';
import 'core/utils/responsive.dart';
import 'core/utils/platform_support.dart';
import 'widgets/ui_scale_controller.dart';

class RestartIntent extends Intent {
  const RestartIntent();
}

class KutbiPaintsApp extends ConsumerStatefulWidget {
  const KutbiPaintsApp({super.key});

  @override
  ConsumerState<KutbiPaintsApp> createState() => _KutbiPaintsAppState();
}

class _KutbiPaintsAppState extends ConsumerState<KutbiPaintsApp> {
  @override
  void initState() {
    super.initState();
    // Check for saved login on app start
    Future.microtask(() {
      ref.read(authProvider.notifier).checkSavedLogin();
      ref.read(dataServiceProvider).checkAppVersion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final uiScale = ref.watch(uiScaleProvider);

    // Sync static utility for layout scaling
    Responsive.uiScale = uiScale;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
            const RestartIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR):
            const RestartIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          RestartIntent: CallbackAction<RestartIntent>(
            onInvoke: (RestartIntent intent) {
              performSoftRefresh(ref);
              return null;
            },
          ),
        },
        child: MaterialApp.router(
          title: 'Kutbi Hardware and Paints',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: router,
          locale: locale,
          builder: (context, child) {
            return MediaQuery(
              // Multiply existing text scale by our custom factor
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(uiScale)),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                  overscroll: false,
                  physics: const ClampingScrollPhysics(),
                ),
                child: NoInternetOverlay(
                  child: VersionCheckOverlay(
                    child: Stack(
                      children: [
                        child!,
                        if (PlatformSupport.isDesktop)
                          const Positioned(
                            bottom: 24,
                            right: 24,
                            child: UIScaleController(),
                          ),
                        Consumer(
                          builder: (context, ref, _) {
                            final isRefreshing = ref.watch(globalRefreshProvider);
                            if (!isRefreshing) return const SizedBox.shrink();

                            return Positioned.fill(
                              child: ClipRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                  child: Container(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    child: const Center(
                                      child: LottieLoadingWidget(
                                        message: 'Refreshing...',
                                        size: 150,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('hi'), Locale('ur')],
        ),
      ),
    );
  }
}
