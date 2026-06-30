import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the currently selected brand for the painter experience
final selectedBrandProvider = StateProvider<String?>((ref) => null);
