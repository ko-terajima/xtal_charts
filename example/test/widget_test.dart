import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('ExampleApp builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Sales Analytics Demo'), findsOneWidget);
  });
}
