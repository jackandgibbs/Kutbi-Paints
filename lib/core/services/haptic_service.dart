import 'package:flutter/services.dart';
import '../utils/platform_support.dart';

class HapticService {
  static Future<void> light() async {
    if (!PlatformSupport.supportsHaptics) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (!PlatformSupport.supportsHaptics) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    if (!PlatformSupport.supportsHaptics) return;
    await HapticFeedback.heavyImpact();
  }

  static Future<void> success() async {
    if (!PlatformSupport.supportsHaptics) return;
    await HapticFeedback.vibrate();
  }

  static Future<void> selection() async {
    if (!PlatformSupport.supportsHaptics) return;
    await HapticFeedback.selectionClick();
  }
}
