import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kutbi_paints/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: KutbiPaintsApp()),
    );
    await tester.pumpAndSettle();
    // App should load without crashing
    expect(find.byType(KutbiPaintsApp), findsOneWidget);
  });
}
