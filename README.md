# flutter_realistic_flipbook

A realistic 3D page-turn widget for Flutter, inspired by the interaction and rendering model of `flipbook-vue`.

This package is designed for immersive reader experiences (books, magazines, catalogs, Mushaf-like pages) where the page turn must feel physical, not just a flat slide transition.

## Preview

![Realistic flipbook demo](assets/preview/realistic-flipbook-demo.gif)

## Highlights

- Real-time 3D page curvature using polygon strips (`nPolygons`)
- Perspective projection with diffuse and specular lighting
- Tap/click, drag, and wheel interactions
- Auto and manual flip progression with controller access
- Single-page and double-page layouts
- Optional Mushaf-style page chrome:
  - top header area
  - bottom footer area
  - per-page header/footer text
  - decorative paper/border look
- Zoom support with animated transitions and hi-res image fallback

## Installation

### 1) From pub.dev

```yaml
dependencies:
  flutter_realistic_flipbook: ^0.0.1
```

### 2) From private/public Git

```yaml
dependencies:
  flutter_realistic_flipbook:
    git:
      url: git@github.com:88hitman/flutter_realistic_flipbook.git
      ref: main
```

### 3) From local path (development)

```yaml
dependencies:
  flutter_realistic_flipbook:
    path: ../flutter_realistic_flipbook
```

Then run:

```bash
flutter pub get
```

## Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';

class FlipbookDemo extends StatefulWidget {
  const FlipbookDemo({super.key});

  @override
  State<FlipbookDemo> createState() => _FlipbookDemoState();
}

class _FlipbookDemoState extends State<FlipbookDemo> {
  final controller = FlipbookController();

  late final pages = <FlipbookPage?>[
    null, // optional: isolated cover behavior
    const FlipbookPage(image: AssetImage('assets/pages/1.jpg')),
    const FlipbookPage(image: AssetImage('assets/pages/2.jpg')),
    const FlipbookPage(image: AssetImage('assets/pages/3.jpg')),
    const FlipbookPage(image: AssetImage('assets/pages/4.jpg')),
  ];

  @override
  Widget build(BuildContext context) {
    return RealisticFlipbook(
      controller: controller,
      pages: pages,
      nPolygons: 14,
      perspective: 2200,
      ambient: 0.72,
      gloss: 0.25,
      flipDuration: const Duration(milliseconds: 1300),
      zooms: const [1, 2, 3],
      clickToZoom: true,
      dragToFlip: true,
      dragToScroll: true,
      wheel: FlipbookWheelMode.scroll,
    );
  }
}
```

## Mushaf-Style Chrome Example

```dart
RealisticFlipbook(
  pages: pages,
  mushafChrome: true,
  paperColor: const Color(0xFFFFFCF2),
  mushafTopInsetRatio: 0.065,
  mushafBottomInsetRatio: 0.075,
  mushafSideInsetRatio: 0.04,
  mushafHeaderFooterColor: const Color(0xFF5E4721),
  mushafBorderColor: const Color(0xFFC8A163),
  mushafInnerBorderColor: const Color(0xFFEED8AB),
  mushafHeaderStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
  mushafFooterStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
)
```

To feed page metadata (header/footer text and alignment), use `FlipbookPage`:

```dart
FlipbookPage(
  image: imageProvider,
  hiResImage: imageProviderHiRes,
  headerText: 'سورة البقرة',
  footerText: '2',
  headerAlignment: Alignment.topRight,
)
```

## Core API

### `RealisticFlipbook`

- `pages` (`List<FlipbookPage?>`) required
- `controller` (`FlipbookController?`)
- `flipDuration`, `zoomDuration`
- `zooms` (`List<double>`)
- `perspective`, `nPolygons`, `ambient`, `gloss`, `swipeMin`
- `singlePage`, `forwardDirection`, `centering`, `startPage`
- `clickToZoom`, `dragToFlip`, `dragToScroll`, `wheel`
- `paperColor`, `blankPageColor`
- Mushaf chrome settings:
  - `mushafChrome`
  - `mushafTopInsetRatio`
  - `mushafBottomInsetRatio`
  - `mushafSideInsetRatio`
  - `mushafHeaderStyle`
  - `mushafFooterStyle`
  - `mushafHeaderFooterColor`
  - `mushafBorderColor`
  - `mushafInnerBorderColor`
  - `mushafShadowStrength`
- callbacks:
  - `onFlipLeftStart`, `onFlipLeftEnd`
  - `onFlipRightStart`, `onFlipRightEnd`
  - `onZoomStart`, `onZoomEnd`

### `FlipbookPage`

- `image` (`ImageProvider`) required
- `hiResImage` (`ImageProvider?`) optional (used for zoomed rendering)
- `headerText` (`String?`) optional
- `footerText` (`String?`) optional
- `headerAlignment` (`Alignment`) optional

### `FlipbookController`

- read-only states:
  - `canFlipLeft`, `canFlipRight`
  - `canZoomIn`, `canZoomOut`
  - `page`, `numPages`
- actions:
  - `flipLeft()`, `flipRight()`
  - `zoomIn([Offset?])`, `zoomOut([Offset?])`
  - `goToPage(int)`

## Behavior Notes

- If the first element in `pages` is `null`, the widget follows cover-like behavior for page indexing similar to the source inspiration.
- Double-page mode activates when viewport width is larger than height and `singlePage == false`.
- Drag flip progress is direct and can be completed by velocity fling.
- Hi-res images are preloaded around the active page range for smoother zoomed rendering.

## Performance Recommendations

- Use compressed page assets and sensible dimensions.
- Start with `nPolygons` between `10` and `16` for mobile.
- Increase `nPolygons` only if needed; higher values are heavier.
- Provide `hiResImage` only when truly needed for high zoom.

## Troubleshooting

- **No animation, immediate page jump:**
  - Ensure you call `flipLeft()/flipRight()` rather than only changing page index externally.
- **Package changes not reflected in host app:**
  - Confirm the app imports `package:flutter_realistic_flipbook/...` and not a local duplicate widget file.
- **Transparent PNG pages look black/empty while flipping:**
  - Set `paperColor` and use Mushaf chrome if needed.

## Example App

A runnable example is provided in `/example`.

```bash
cd example
flutter run
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
