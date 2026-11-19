import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promatchfix/main.dart';

void main() {
  testWidgets('PromatchfixApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PromatchfixApp(),
      ),
    );
  });
}