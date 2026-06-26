import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';

final Uint8List _imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

List<FlipbookPage?> _imagePages({
  required bool leadingBlank,
  int count = 4,
}) {
  final image = MemoryImage(_imageBytes);
  return <FlipbookPage?>[
    if (leadingBlank) null,
    for (var i = 0; i < count; i++) FlipbookPage(image: image),
  ];
}

Future<void> _pumpBook(
  WidgetTester tester, {
  required FlipbookController controller,
  required List<FlipbookPage?> pages,
  bool singlePage = false,
  bool enableDiagnostics = false,
  bool queuedNavigation = false,
  bool interruptibleFlips = false,
  Duration flipDuration = const Duration(milliseconds: 20),
  FlipbookAutoPhysics autoPhysics = FlipbookAutoPhysics.animationController,
  FlipbookSnapshotPreparationMode snapshotPreparationMode =
      FlipbookSnapshotPreparationMode.waitForTextures,
  FlipbookDiagnosticsCallback? onDiagnosticsChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox.expand(
        child: RealisticFlipbook(
          controller: controller,
          pages: pages,
          singlePage: singlePage,
          flipDuration: flipDuration,
          zoomDuration: const Duration(milliseconds: 20),
          enableDiagnostics: enableDiagnostics,
          queuedNavigation: queuedNavigation,
          interruptibleFlips: interruptibleFlips,
          autoPhysics: autoPhysics,
          snapshotPreparationMode: snapshotPreparationMode,
          onDiagnosticsChanged: onDiagnosticsChanged,
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

  testWidgets('diagnostics reports flip progress when enabled', (tester) async {
    final controller = FlipbookController();
    final diagnostics = <FlipbookDiagnostics>[];

    await _pumpBook(
      tester,
      controller: controller,
      pages: _imagePages(leadingBlank: false),
      enableDiagnostics: true,
      onDiagnosticsChanged: diagnostics.add,
    );

    controller.flipRight();
    await _pumpFlip(tester);

    expect(diagnostics, isNotEmpty);
    expect(
      diagnostics.any((d) => d.phase == FlipbookNavigationPhase.flip),
      isTrue,
    );
    expect(diagnostics.last.publicPage, controller.page);
  });

  testWidgets('queued navigation chains repeated auto flips and drains',
      (tester) async {
    final controller = FlipbookController();
    final diagnostics = <FlipbookDiagnostics>[];

    await _pumpBook(
      tester,
      controller: controller,
      pages: _imagePages(leadingBlank: false, count: 6),
      enableDiagnostics: true,
      queuedNavigation: true,
      onDiagnosticsChanged: diagnostics.add,
    );

    controller.flipRight();
    await tester.pump();
    controller.flipRight();
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    expect(controller.page, 5);
    expect(diagnostics.last.navigationQueueDepth, 0);
  });

  testWidgets(
      'interrupted right release completes a left flip below normal fling threshold',
      (tester) async {
    final controller = FlipbookController();
    final diagnostics = <FlipbookDiagnostics>[];

    await _pumpBook(
      tester,
      controller: controller,
      pages: _imagePages(leadingBlank: false, count: 6),
      interruptibleFlips: true,
      flipDuration: const Duration(milliseconds: 300),
      enableDiagnostics: true,
      onDiagnosticsChanged: diagnostics.add,
    );

    controller.flipRight();
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    expect(controller.page, 3);

    diagnostics.clear();
    controller.flipLeft();
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      final activeLeftFlip = diagnostics.any(
        (d) =>
            d.phase == FlipbookNavigationPhase.flip &&
            d.direction == FlipbookNavigationDirection.left &&
            d.progress >= 0.03,
      );
      if (activeLeftFlip) break;
    }

    await tester.timedDragFrom(
      const Offset(300, 300),
      const Offset(30, 0),
      const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 340));
    await tester.pump();

    expect(controller.page, 1);
  });

  testWidgets('spring physics completes auto navigation', (tester) async {
    final controller = FlipbookController();

    await _pumpBook(
      tester,
      controller: controller,
      pages: _imagePages(leadingBlank: false),
      autoPhysics: FlipbookAutoPhysics.spring,
    );

    controller.flipRight();
    await tester.pumpAndSettle(const Duration(milliseconds: 20));

    expect(controller.page, 3);
  });
}
