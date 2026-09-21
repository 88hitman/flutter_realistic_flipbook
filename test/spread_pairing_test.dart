import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';
import 'package:flutter_test/flutter_test.dart';

final Uint8List _imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

List<FlipbookPage?> _pages(int count) {
  final image = MemoryImage(_imageBytes);
  return <FlipbookPage?>[
    for (var i = 0; i < count; i++) FlipbookPage(image: image),
  ];
}

Future<void> _pumpBook(
  WidgetTester tester, {
  required FlipbookController controller,
  required Size size,
  int? startPage,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox.expand(
        child: RealisticFlipbook(
          controller: controller,
          pages: _pages(8),
          startPage: startPage,
          flipDuration: const Duration(milliseconds: 20),
          zoomDuration: const Duration(milliseconds: 20),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

void main() {
  const landscape = Size(800, 600);
  const portrait = Size(600, 800);

  testWidgets('going to the second page of a spread opens that spread',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = FlipbookController();
    await _pumpBook(tester, controller: controller, size: landscape);
    expect(controller.displayedPages, 2);

    controller.goToPage(4);
    await _settle(tester);
    expect(controller.page, 3);

    controller.goToPage(5);
    await _settle(tester);
    expect(controller.page, 5);
  });

  testWidgets('a book opened on a left-hand page shows its own spread',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = FlipbookController();
    await _pumpBook(
      tester,
      controller: controller,
      size: landscape,
      startPage: 4,
    );

    expect(controller.page, 3);
  });

  testWidgets('turning to landscape on a left-hand page keeps its spread',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = FlipbookController();
    await _pumpBook(tester, controller: controller, size: portrait);
    controller.goToPage(4);
    await _settle(tester);
    expect(controller.displayedPages, 1);
    expect(controller.page, 4);

    tester.view.physicalSize = landscape;
    await _settle(tester);
    expect(controller.displayedPages, 2);
    expect(controller.page, 3);

    // The reader asking again for the page it already shows is a no-op.
    controller.goToPage(4);
    await _settle(tester);
    expect(controller.page, 3);
  });
}
