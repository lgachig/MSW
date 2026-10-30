import 'package:flutter_test/flutter_test.dart';

import 'package:musicsundayworship/main.dart';

void main() {
  testWidgets('music engine smoke test renders the app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Flutter Demo Home Page'), findsOneWidget);
    expect(
      find.text('You have pushed the button this many times:'),
      findsOneWidget,
    );
    expect(find.text('0'), findsOneWidget);
  });
}
