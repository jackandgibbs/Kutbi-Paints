import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/data_service.dart';

final globalRefreshProvider = StateProvider<bool>((ref) => false);

Future<void> performSoftRefresh(WidgetRef ref) async {
  ref.read(globalRefreshProvider.notifier).state = true;
  await ref.read(dataServiceProvider).refresh();
  // Ensure the cool animation plays long enough to be perceived
  await Future.delayed(const Duration(milliseconds: 1500));
  ref.read(globalRefreshProvider.notifier).state = false;
}
