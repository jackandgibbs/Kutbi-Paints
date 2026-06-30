import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/data_service.dart';
import '../features/auth/force_update_screen.dart';

/// A non-dismissible overlay that forces the user to update the app.
class VersionCheckOverlay extends ConsumerWidget {
  final Widget child;

  const VersionCheckOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(dataServiceProvider);
    
    // Check if update is required (global toggle OR local version mismatch)
    final updateRequired = ds.updateRequired || ds.forceUpdateEnabled;

    if (!updateRequired) return child;

    return ForceUpdateScreen(updateUrl: ds.forceUpdateUrl);
  }
}
