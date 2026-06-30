import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the splash screen has been shown this session.
/// Once true, subsequent loading states use a minimal progress bar instead.
final splashShownProvider = StateProvider<bool>((ref) => false);
