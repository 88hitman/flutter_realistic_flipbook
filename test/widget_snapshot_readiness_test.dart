import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';

class _DelayedImage extends ImageProvider<_DelayedImage> {
  _DelayedImage(this.decoded);

  final Completer<ui.Image> decoded;

  @override
  Future<_DelayedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _DelayedImage key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(decoded.future.then(
        (image) => ImageInfo(image: image),
      ));
}

Future<ui.Image> _redImage(WidgetTester tester) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFFFF0000),
  );
  final picture = recorder.endRecording();
  final result = await tester.runAsync(() => picture.toImage(8, 8));
  picture.dispose();
  return result!;
}

Future<void> _frames(WidgetTester tester, {int count = 8}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 2),
        ));
  }
}

List<FlipbookPage?> _pages(
  List<Completer<void>> loads, {
  required Set<int> prepared,
  Color color = const Color(0xFFFF0000),
}) =>
    List<FlipbookPage?>.generate(loads.length, (index) {
      return FlipbookPage(
        sizeHint: const Size(240, 400),
        prepareSnapshot: (_) async {
          prepared.add(index);
          await loads[index].future;
        },
        widgetBuilder: (_) => FutureBuilder<void>(
          future: loads[index].future,
          builder: (_, snapshot) => ColoredBox(
            color: snapshot.connectionState == ConnectionState.done
                ? color
                : Colors.white,
          ),
        ),
      );
    });

Future<void> _book(
  WidgetTester tester, {
  required FlipbookController controller,
  required List<FlipbookPage?> pages,
  required ValueChanged<FlipbookDiagnostics> diagnostics,
  int startPage = 1,
  FlipbookSnapshotPreparationMode snapshotMode =
      FlipbookSnapshotPreparationMode.waitForTextures,
  bool allowPageWidgetGestures = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: RealisticFlipbook(
      controller: controller,
      pages: pages,
      startPage: startPage,
      snapshotPreparationMode: snapshotMode,
      allowPageWidgetGestures: allowPageWidgetGestures,
      enableDiagnostics: true,
      onDiagnosticsChanged: diagnostics,
      flipDuration: const Duration(milliseconds: 400),
    ),
  ));
  await _frames(tester);
}

Future<void> _expectTextureColor(WidgetTester tester, Color color) async {
  final textures = tester
      .widgetList<RawImage>(find.byType(RawImage))
      .map((widget) => widget.image)
      .whereType<ui.Image>()
      .toSet();
  expect(textures, isNotEmpty, reason: 'The moving sheet must use a texture.');
  for (final texture in textures) {
    final pixels = await tester.runAsync(
      () => texture.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final offset =
        ((texture.height ~/ 2) * texture.width + texture.width ~/ 2) * 4;
    expect(pixels!.getUint8(offset), (color.toARGB32() >> 16) & 255);
    expect(pixels.getUint8(offset + 1), (color.toARGB32() >> 8) & 255);
    expect(pixels.getUint8(offset + 2), color.toARGB32() & 255);
  }
}

void main() {
  for (final landscape in <bool>[false, true]) {
    for (final manual in <bool>[false, true]) {
      testWidgets(
          'instant ${manual ? 'swipe' : 'command'} turns with pending captures, '
          'landscape=$landscape', (tester) async {
        final size = landscape ? const Size(800, 600) : const Size(600, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final loads = List.generate(8, (_) => Completer<void>());
        final decoded = Completer<ui.Image>();
        final image = _DelayedImage(decoded);
        decoded.complete(await _redImage(tester));
        final pages = List<FlipbookPage?>.generate(
          loads.length,
          (index) => FlipbookPage(
            sizeHint: const Size(240, 400),
            prepareSnapshot: (context) async {
              await precacheImage(image, context);
              await loads[index].future;
            },
            widgetBuilder: (_) => Image(image: image, fit: BoxFit.fill),
          ),
        );
        final controller = FlipbookController();
        FlipbookDiagnostics? diagnostics;
        await _book(tester,
            controller: controller,
            pages: pages,
            snapshotMode: FlipbookSnapshotPreparationMode.instantFallback,
            allowPageWidgetGestures: true,
            diagnostics: (value) => diagnostics = value);

        TestGesture? gesture;
        if (manual) {
          gesture = await tester.startGesture(
            Offset(size.width * 0.65, size.height * 0.5),
          );
          await gesture.moveBy(const Offset(-40, 0));
          await tester.pump();
          await gesture.moveBy(Offset(-size.width * 0.3, 0));
          await tester.pump();
        } else {
          controller.flipRight();
          await tester.pump();
        }

        expect(
            diagnostics!.phase,
            isIn(<FlipbookNavigationPhase>[
              FlipbookNavigationPhase.flip,
              FlipbookNavigationPhase.slide,
            ]));
        expect(diagnostics!.snapshotsCached, 0);
        await _expectTextureColor(tester, const Color(0xFFFF0000));
        if (gesture != null) await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();
        expect(controller.page, greaterThan(1),
            reason: 'Pending captures must never cancel or block navigation.');
        expect(loads.every((load) => !load.isCompleted), isTrue);

        for (final load in loads) {
          load.complete();
        }
        await _frames(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester, count: 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a delayed image cannot be cached as a blank page',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final decoded = Completer<ui.Image>();
    final image = _DelayedImage(decoded);
    final pages = List<FlipbookPage?>.generate(
      8,
      (_) => FlipbookPage(
        sizeHint: const Size(240, 400),
        prepareSnapshot: (context) => precacheImage(image, context),
        widgetBuilder: (_) => Image(image: image, fit: BoxFit.fill),
      ),
    );
    final controller = FlipbookController();
    FlipbookDiagnostics? diagnostics;
    await _book(tester,
        controller: controller,
        pages: pages,
        diagnostics: (value) => diagnostics = value);

    controller.flipRight();
    await _frames(tester);
    expect(diagnostics!.phase, FlipbookNavigationPhase.preparation);
    expect(diagnostics!.snapshotsCached, 0);
    expect(controller.page, 1);

    decoded.complete(await _redImage(tester));
    await _frames(tester);
    expect(diagnostics!.phase, FlipbookNavigationPhase.flip);
    await _expectTextureColor(tester, const Color(0xFFFF0000));
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, count: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both neighbouring spreads are prepared before a gesture',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final loads = List.generate(10, (_) => Completer<void>()..complete());
    final prepared = <int>{};
    await _book(tester,
        controller: FlipbookController(),
        pages: _pages(loads, prepared: prepared),
        startPage: 5,
        diagnostics: (_) {});
    // Current spread is 4/5, previous 2/3, next 6/7 (zero-based).
    expect(prepared, containsAll(<int>[2, 3, 4, 5, 6, 7]));
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, count: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the page revealed under a spread waits for its content',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final loads = List.generate(8, (index) {
      final load = Completer<void>();
      if (index != 3) load.complete();
      return load;
    });
    final controller = FlipbookController();
    FlipbookDiagnostics? diagnostics;
    await _book(tester,
        controller: controller,
        pages: _pages(loads, prepared: <int>{}),
        diagnostics: (value) => diagnostics = value);
    controller.flipRight();
    await _frames(tester);
    expect(diagnostics!.phase, FlipbookNavigationPhase.preparation);
    loads[3].complete();
    await _frames(tester);
    expect(diagnostics!.phase, FlipbookNavigationPhase.flip);
    await _expectTextureColor(tester, const Color(0xFFFF0000));
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, count: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a completed old load cannot overwrite a replacement book',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final oldLoads = List.generate(8, (_) => Completer<void>());
    final controller = FlipbookController();
    await _book(tester,
        controller: controller,
        pages: _pages(oldLoads, prepared: <int>{}),
        diagnostics: (_) {});
    final newLoads = List.generate(8, (_) => Completer<void>()..complete());
    await _book(tester,
        controller: controller,
        pages:
            _pages(newLoads, prepared: <int>{}, color: const Color(0xFF00FF00)),
        diagnostics: (_) {});
    for (final load in oldLoads) {
      load.complete();
    }
    await _frames(tester);
    controller.flipRight();
    await _frames(tester);
    await _expectTextureColor(tester, const Color(0xFF00FF00));
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, count: 2);
    expect(tester.takeException(), isNull);
  });
}
