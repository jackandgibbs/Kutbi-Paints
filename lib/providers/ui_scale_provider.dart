import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/platform_support.dart';

class UIScaleNotifier extends StateNotifier<double> {
  static const _key = 'ui_scale_factor';
  final SharedPreferences? _prefs;

  UIScaleNotifier(this._prefs) : super(_prefs?.getDouble(_key) ?? 1.0);

  Future<void> setScale(double scale) async {
    state = scale;
    if (_prefs != null) {
      await _prefs!.setDouble(_key, scale);
    }
  }

  void reset() => setScale(1.0);
}

final sharedPrefsProvider = Provider<SharedPreferences?>((ref) => throw UnimplementedError());

final uiScaleProvider = StateNotifierProvider<UIScaleNotifier, double>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return UIScaleNotifier(prefs);
});
