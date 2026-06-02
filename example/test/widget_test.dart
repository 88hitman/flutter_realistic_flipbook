import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';

import 'package:flutter_realistic_flipbook_example/main.dart';

void main() {
  testWidgets('demo app builds the flipbook', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    expect(find.byType(RealisticFlipbook), findsOneWidget);
  });
}
