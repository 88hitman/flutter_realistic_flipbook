import 'package:flutter/material.dart';
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';
import 'package:flutter_realistic_flipbook/src/physical/physical_page_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _frames(WidgetTester tester, {int count = 8}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
}

Future<Map<int, int>> _dragAndCountBuilds(
  WidgetTester tester,
  FlipbookRenderer renderer,
) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final builds = <int, int>{};
  final pages = List<FlipbookPage?>.generate(8, (index) {
    return FlipbookPage(
      sizeHint: const Size(480, 700),
      widgetBuilder: (_) {
        builds[index] = (builds[index] ?? 0) + 1;
        return ColoredBox(color: Colors.primaries[index]);
      },
    );
  });
  await tester.pumpWidget(
    MaterialApp(
      home: RealisticFlipbook(
        pages: pages,
        startPage: 3,
        allowPageWidgetGestures: true,
        tapToFlip: false,
        clickToZoom: false,
        renderer: renderer,
        physicalStyle: const FlipbookPhysicalStyle(haptics: false),
        enableDiagnostics: false,
      ),
    ),
  );
  // Let every nearby page be captured as a texture first.
  await _frames(tester, count: 20);
  builds.clear();

  final gesture = await tester.startGesture(const Offset(900, 600));
  var stamp = Duration.zero;
  for (var i = 0; i < 20; i++) {
    stamp += const Duration(milliseconds: 16);
    await gesture.moveBy(const Offset(-12, -3), timeStamp: stamp);
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is PhysicalPagePainter,
    ),
    renderer == FlipbookRenderer.physical ? findsOneWidget : findsNothing,
  );
  await gesture.up(timeStamp: stamp);
  await _frames(tester, count: 80);
  return builds;
}

void main() {
  testWidgets('strips stay the default renderer', (tester) async {
    final book = RealisticFlipbook(pages: const <FlipbookPage?>[]);
    expect(book.renderer, FlipbookRenderer.strips);
  });

  testWidgets(
    'neither renderer rebuilds page widgets on every frame of a turn',
    (tester) async {
      final strips = await _dragAndCountBuilds(tester, FlipbookRenderer.strips);
      final physical =
          await _dragAndCountBuilds(tester, FlipbookRenderer.physical);
      final stripTotal = strips.values.fold<int>(0, (a, b) => a + b);
      final physicalTotal = physical.values.fold<int>(0, (a, b) => a + b);
      // ignore: avoid_print
      print('page builds during a turn: strips $stripTotal, '
          'physical $physicalTotal');
      // A turn lasts well over 100 frames; a few builds per page at most.
      expect(stripTotal, lessThan(40));
      expect(physicalTotal, lessThan(40));
    },
  );

  testWidgets('a swipe during the landing turns the next page', (tester) async {
    final controller = FlipbookController();
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FlipbookDiagnostics? last;
    await tester.pumpWidget(
      MaterialApp(
        home: RealisticFlipbook(
          controller: controller,
          pages: List<FlipbookPage?>.generate(
            10,
            (index) => FlipbookPage(
              sizeHint: const Size(480, 700),
              widgetBuilder: (_) => ColoredBox(color: Colors.primaries[index]),
            ),
          ),
          startPage: 3,
          allowPageWidgetGestures: true,
          tapToFlip: false,
          clickToZoom: false,
          interruptibleFlips: true,
          flipThreshold: 0.1,
          renderer: FlipbookRenderer.physical,
          physicalStyle: const FlipbookPhysicalStyle(haptics: false),
          enableDiagnostics: true,
          onDiagnosticsChanged: (d) => last = d,
        ),
      ),
    );
    await _frames(tester, count: 20);

    Future<void> swipe() async {
      final gesture = await tester.startGesture(const Offset(900, 600));
      var stamp = Duration.zero;
      for (var i = 0; i < 10; i++) {
        stamp += const Duration(milliseconds: 16);
        await gesture.moveBy(const Offset(-16, 0), timeStamp: stamp);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up(timeStamp: stamp);
    }

    await swipe();
    // Wait until the first page is landing, then swipe again at once.
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      final d = last;
      if (d != null &&
          d.phase == FlipbookNavigationPhase.flip &&
          d.progress > 0.93) {
        break;
      }
    }
    expect(last?.phase, FlipbookNavigationPhase.flip);
    await swipe();
    await _frames(tester, count: 120);
    expect(controller.page, 7);
  });

  for (final renderer in FlipbookRenderer.values) {
    testWidgets(
        'on a phone, quick successive swipes each move one page '
        '(${renderer.name})', (tester) async {
      final controller = FlipbookController();
      FlipbookDiagnostics? last;
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RealisticFlipbook(
            controller: controller,
            pages: List<FlipbookPage?>.generate(
              12,
              (index) => FlipbookPage(
                sizeHint: const Size(480, 760),
                widgetBuilder: (_) =>
                    ColoredBox(color: Colors.primaries[index]),
              ),
            ),
            startPage: 3,
            forwardDirection: FlipbookForwardDirection.left,
            allowPageWidgetGestures: true,
            tapToFlip: false,
            clickToZoom: false,
            interruptibleFlips: true,
            swipeMin: 18,
            flipThreshold: 0.1,
            flipDuration: const Duration(milliseconds: 950),
            renderer: renderer,
            physicalStyle: const FlipbookPhysicalStyle(haptics: false),
            enableDiagnostics: true,
            onDiagnosticsChanged: (d) => last = d,
          ),
        ),
      );
      await _frames(tester, count: 20);

      // A reader's quick flick toward the next page.
      Future<void> flick() async {
        final gesture = await tester.startGesture(const Offset(40, 400));
        var stamp = Duration.zero;
        for (var k = 0; k < 8; k++) {
          stamp += const Duration(milliseconds: 16);
          await gesture.moveBy(const Offset(18, 0), timeStamp: stamp);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up(timeStamp: stamp);
      }

      // Each next flick comes as soon as the page is landing, as a reader
      // does, never later than the strips engine allows.
      for (var i = 0; i < 4; i++) {
        await flick();
        var busy = 0;
        while (busy < 300) {
          final d = last;
          if (d == null || d.phase == FlipbookNavigationPhase.idle) break;
          if (renderer == FlipbookRenderer.physical && d.progress >= 0.9) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 8));
          busy++;
        }
        if (i == 0) {
          // The first move is a slide within the spread: no lingering tail.
          expect(busy * 8, lessThanOrEqualTo(260));
        }
      }
      await _frames(tester, count: 120);
      expect(controller.page, 7);
    });
  }

  testWidgets('a released page completes the turn', (tester) async {
    final controller = FlipbookController();
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: RealisticFlipbook(
          controller: controller,
          pages: List<FlipbookPage?>.generate(
            8,
            (index) => FlipbookPage(
              sizeHint: const Size(480, 700),
              widgetBuilder: (_) => ColoredBox(color: Colors.primaries[index]),
            ),
          ),
          startPage: 3,
          allowPageWidgetGestures: true,
          tapToFlip: false,
          clickToZoom: false,
          renderer: FlipbookRenderer.physical,
          physicalStyle: const FlipbookPhysicalStyle(haptics: false),
        ),
      ),
    );
    await _frames(tester, count: 20);
    expect(controller.page, 3);
    controller.flipRight();
    await _frames(tester, count: 90);
    expect(controller.page, 5);
    controller.flipLeft();
    await _frames(tester, count: 90);
    expect(controller.page, 3);
  });
}
