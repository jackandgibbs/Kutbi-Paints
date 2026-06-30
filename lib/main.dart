import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/utils/platform_support.dart';
import 'services/offline_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

// Conditional import for window_manager
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/ui_scale_provider.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  
    // ── Desktop window configuration ─────────────────────────────
    if (PlatformSupport.isDesktop) {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(900, 600),
        center: true,
        title: 'Kutbi Hardware & Paints',
        backgroundColor: Colors.transparent,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    debugPrint('Step 1: Dotenv Loading...');
    await dotenv.load(fileName: ".env");
    debugPrint('Step 1: Dotenv Loaded');

    debugPrint('Step 2: Offline Service Initializing...');
    await OfflineService.init();
    debugPrint('Step 2: Offline Service Initialized');

    debugPrint('Step 3: Notification Service Initializing...');
    await NotificationService.init();
    debugPrint('Step 3: Notification Service Initialized');

    debugPrint('Step 4: Supabase Initializing...');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    debugPrint('Step 4: Supabase Initialized');

    debugPrint('Step 5: SharedPreferences Initializing...');
    final prefs = await SharedPreferences.getInstance();
    debugPrint('Step 5: SharedPreferences Initialized');

    runApp(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const KutbiPaintsApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('CRITICAL STARTUP ERROR: $e');
    debugPrint(stack.toString());
    // Fallback UI to show error if main fails
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Startup Error: $e\n\nPlease check your configuration.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
