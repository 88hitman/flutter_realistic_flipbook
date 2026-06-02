import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';

final Uint8List _imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

List<FlipbookPage?> _imagePages({required bool leadingBlank}) {
  final image = MemoryImage(_imageBytes);
  return <FlipbookPage?>[
    if (leadingBlank) null,
    for (var i = 0; i < 4; i++) FlipbookPage(image: image),
  ];
}

Future<void> _pumpBook(
  WidgetTester tester, {
  required FlipbookController controller,
  required List<FlipbookPage?> pages,
  bool singlePage = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox.expand(
        child: RealisticFlipbook(
          controller: controller,
          pages: pages,
          singlePage: singlePage,
          flipDuration: const Duration(milliseconds: 20),
          zoomDuration: const Duration(milliseconds: 20),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

Future<void> _pumpFlip(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('leading null page behaves as a closed cover in double-page mode',
      (tester) async {
    final controller = FlipbookController();

    await _pumpBook(
      tester,
      controller: controller,
      pages: _imagePages(leadingBlank: true),
    );

    expect(controller.numPages, 4);
    expect(controller.page, 1);
    expect(controller.canFlipLeft, isFalse);
    expect(controller.canFlipRight, isTrue);

    controller.flipRight();
    await _pumpFlip(tester);

    expect(controller.page, 2);
    expect(controller.canFlipLeft, isTrue);
    expect(controller.canFlipRight, isTrue);

    controller.flipLeft();
    await _pumpFlip(tester);

    expect(controller.page, 1);
    expect(controller.canFlipLeft, isFalse);
    expect(controller.canFlipRight, isTrue);
  });

  testWidgets('goToPage(1) returns to the closed cover spread', (tester) async {
    final controller = FlipbookController();

    await _pumpBook(
      tester,
      controller: controller,
      pages: _imagePages(leadingBlank: true),
    );

    controller.goToPage(2);
    await tester.pump();
    expect(controller.page, 2);

    controller.goToPage(1);
    await tester.pump();

    expect(controller.page, 1);
    expect(controller.canFlipLeft, isFalse);
    expect(controller.canFlipRight, isTrue);
  });

  testWidgets('leading null page behaves as a closed cover in single-page mode',
      (tester) async {
    final controller = FlipbookController();
    await _pumpBook(
      tester,
      controller: controller,
      pages: _imagePages(leadingBlank: true),
      singlePage: true,
    );

    expect(controller.numPages, 4);
    expect(controller.page, 1);
    expect(controller.canFlipLeft, isFalse);
    expect(controller.canFlipRight, isTrue);

    controller.flipRight();
    await _pumpFlip(tester);

    expect(controller.page, 2);
    expect(controller.canFlipLeft, isTrue);

    controller.flipLeft();
    await _pumpFlip(tester);

    expect(controller.page, 1);
    expect(controller.canFlipLeft, isFalse);
    expect(controller.canFlipRight, isTrue);
  });

  testWidgets('normal books without a leading null keep existing page math',
      (tester) async {
    final controller = FlipbookController();

    await _pumpBook(
      tester,
      controller: controller,
      pages: _imagePages(leadingBlank: false),
    );

    expect(controller.numPages, 4);
    expect(controller.page, 1);

    controller.flipRight();
    await _pumpFlip(tester);

    expect(controller.page, 3);
    expect(controller.canFlipLeft, isTrue);
    expect(controller.canFlipRight, isFalse);
  });

  testWidgets('changing singlePage recalculates the spread without resizing',
      (tester) async {
    final controller = FlipbookController();
    final pages = _imagePages(leadingBlank: false);

    await _pumpBook(
      tester,
      controller: controller,
      pages: pages,
      singlePage: true,
    );

    controller.flipRight();
    await _pumpFlip(tester);
    expect(controller.page, 2);

    await _pumpBook(
      tester,
      controller: controller,
      pages: pages,
    );

    expect(controller.page, 1);
  });
}
