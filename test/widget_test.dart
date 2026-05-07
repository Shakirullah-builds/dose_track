import 'package:dose_tracker/app_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AppShell()),
    );
    expect(find.text('Today'), findsOneWidget);
  });
}
