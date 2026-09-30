# flutter_realistic_flipbook

A realistic page-turn widget for Flutter.

It is designed for reader-style experiences (books, magazines, catalogs) with natural navigation in both single-page and double-page layouts.

## Preview

![Realistic flipbook demo](https://raw.githubusercontent.com/88hitman/flutter_realistic_flipbook/main/assets/preview/realistic-flipbook-demo.gif)

## Features

- Realistic page-turn animation
- Manual swipe and programmatic navigation
- Single-page and double-page display
- Zoom support
- Optional book-style page chrome (header, footer, border)
- Pre-flip navigation guard (`onFlipGuard`)
- Stalled flip recovery watchdog (animated settle/revert)
- Two content modes:
  - Image pages
  - Widget pages

## Installation

```yaml
dependencies:
  flutter_realistic_flipbook: ^0.1.4
```

```bash
flutter pub get
```

## Import

```dart
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';
```

## Basic Usage

```dart
final controller = FlipbookController();

RealisticFlipbook(
  controller: controller,
  pages: pages,
  flipDuration: const Duration(milliseconds: 1200),
);
```

## Page Content Modes

### Image Mode

Use image-based pages when content is static.

```dart
final pages = <FlipbookPage?>[
  null,
  const FlipbookPage(image: AssetImage('assets/pages/1.jpg')),
  const FlipbookPage(image: AssetImage('assets/pages/2.jpg')),
  const FlipbookPage(image: AssetImage('assets/pages/3.jpg')),
];
```

If the first entry is `null`, the next page is treated as a standalone cover.
This gives a closed-book state in both single-page and double-page layouts:
page 1 appears alone, and flipping forward opens the book.

### Widget Mode

Use widget-based pages when content is dynamic or interactive.

```dart
final pages = <FlipbookPage?>[
  null,
  FlipbookPage(
    sizeHint: const Size(1000, 1414),
    widgetBuilder: (context) => Container(
      color: const Color(0xFFFFF8E8),
      padding: const EdgeInsets.all(24),
      child: const Text('Dynamic page'),
    ),
  ),
  FlipbookPage(
    sizeHint: const Size(1000, 1414),
    widgetBuilder: (context) => Container(
      color: const Color(0xFFFFF8E8),
      child: const Center(child: Text('Another page')),
    ),
  ),
];
```

The same cover pattern works with widget pages:

```dart
final pages = <FlipbookPage?>[
  null,
  FlipbookPage(widgetBuilder: (context) => const CoverPage()),
  FlipbookPage(widgetBuilder: (context) => const InteriorPage()),
];
```

### Asynchronous widget content

For pages that load images or data asynchronously, provide `prepareSnapshot`
with the same resources used by the page widget:

```dart
FlipbookPage(
  sizeHint: const Size(1000, 1414),
  prepareSnapshot: (context) async {
    await precacheImage(pageImage, context);
    await loadPageData();
  },
  widgetBuilder: (context) => PageContent(image: pageImage),
)
```

The engine prepares nearby pages in the background and waits for loaded
content to paint before caching a texture. Use
`snapshotPreparationMode: FlipbookSnapshotPreparationMode.instantFallback`
on the book to start turns immediately with live page content while captures
are pending. Preparation never cancels a turn. `waitForTextures` retains its
short (280 ms) preparation window before falling back to live content.
Pending captures are discarded when pages or capture dimensions change.

## Gesture Integration

If your page widgets handle their own taps/presses, enable gesture pass-through:

```dart
RealisticFlipbook(
  pages: pages,
  allowPageWidgetGestures: true,
  tapToFlip: false,
  clickToZoom: false,
  dragToFlip: true,
)
```

## Navigation Guard

Use `onFlipGuard` to block a flip before the animation starts:

```dart
RealisticFlipbook(
  pages: pages,
  onFlipGuard: (currentPage, targetPage, direction, auto) {
    final inAllowedRange = targetPage >= 10 && targetPage <= 30;
    return inAllowedRange;
  },
)
```

## Physical Renderer

`renderer: FlipbookRenderer.physical` replaces the rigid strips with a sheet
of paper bound at the spine:

- the paper first bows up, calm near the spine and bending more toward the
  hand (diagonally from a corner or when the finger moves up or down); then
  the whole leaf swings around the spine, curled almost into a half circle,
  and lands on the other side;
- completion thresholds compare finger travel, so a swipe decides the same
  way as with the strips engine;
- the held point stays under the finger, perspective included (in single-page
  spread navigation the book slides in step with the finger, then finishes
  its slide with the leaf once released);
- a released page keeps the finger velocity, falls under its weight, slows
  down on an air cushion and lands with a small bounce (`pagePhysics`);
- fast turns bend the page more;
- a soft shadow right below the lifted paper: none where it touches the
  book, strongest just above it, fading as it rises;
  show-through ink, binding shade, page-block edges, haptics
  and an optional corner peek (`physicalStyle`);
- one mesh per face drawn with `Canvas.drawVertices`; page widgets are not
  rebuilt on every frame of a turn.

```dart
RealisticFlipbook(
  pages: pages,
  renderer: FlipbookRenderer.physical,
  physicalStyle: const FlipbookPhysicalStyle(cornerPeek: true),
  pagePhysics: const PageTurnPhysics(restitution: 0.1),
);
```

Both renderers reuse page widgets across the frames of a turn (they are
rebuilt when the parent rebuilds), and a released page starts at the
finger's speed. With the physical renderer, a gesture or command arriving
while a page is landing finishes that turn and starts the next one.

The default stays `FlipbookRenderer.strips`. The physical renderer falls back
to strips in plain single-page mode, landscape fill-width mode, with
`bookChrome`, and while a page texture is not ready yet. `flipDuration` sets
when an unassisted turn touches down (at 80% of it).

## Core API

### `RealisticFlipbook`

Main widget that renders and animates the book.

Use it to configure:

- pages and controller
- animation and navigation behavior
- single vs double page layout
- zoom and gesture behavior
- visual styling (paper/chrome)

### `FlipbookPage`

Data model for one page.

A page can be defined with either:

- an `image`, or
- a `widgetBuilder`

You can also provide optional metadata (`headerText`, `footerText`, etc.).

### `FlipbookController`

Imperative controller for navigation and zoom.

It exposes:

- state (`page`, `numPages`, `canFlipLeft`, `canFlipRight`, ...)
- actions (`flipLeft`, `flipRight`, `zoomIn`, `zoomOut`, `goToPage`)

## Example

A runnable demo is available in `example/`.

```bash
cd example
flutter run
```

## License

MIT. See [LICENSE](LICENSE).
