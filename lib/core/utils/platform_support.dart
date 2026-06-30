import 'package:flutter/foundation.dart';

class PlatformSupport {
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get supportsGoogleSignIn => !isWindows;

  static bool get supportsLocalNotifications => !isWindows;

  static bool get supportsReverseGeocoding => !isWindows;

  /// Haptic feedback is not available on desktop platforms.
  static bool get supportsHaptics => !isDesktop;

  /// System back gesture / SystemNavigator.pop() is Android-only.
  static bool get supportsSystemNavPop => !isDesktop && !kIsWeb;

  /// Mobile scanner (camera barcode) may not work on desktop.
  static bool get supportsMobileScanner => !isDesktop;
}
