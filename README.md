# flutter_realistic_flipbook

A realistic 3D page-turn widget for Flutter, inspired by the interaction and rendering model of `flipbook-vue`.

This package is designed for immersive reader experiences (books, magazines, catalogs) where the page turn must feel physical, not just a flat slide transition.

## Preview

![Realistic flipbook demo](https://raw.githubusercontent.com/88hitman/flutter_realistic_flipbook/main/assets/preview/realistic-flipbook-demo.gif)

## Highlights

- Real-time 3D page curvature using polygon strips (`nPolygons`)
- Perspective projection with diffuse and specular lighting
- Tap/click, drag, and wheel interactions
- Auto and manual flip progression with controller access
- Single-page and double-page layouts
- Spread-aware single-page navigation (camera slide between left/right pages)
- Supports both image pages and Flutter widget pages
- Optional book-style page chrome:
  - top header area
  - bottom footer area
  - per-page header/footer text
  - decorative paper/border look
- Zoom support with animated transitions and hi-res image fallback

## Installation

### 1) From pub.dev

```yaml
dependencies:
  flutter_realistic_flipbook: ^0.1.1
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

## Page Styling Example

```dart
RealisticFlipbook(
  pages: pages,
  paperColor: const Color(0xFFFFFCF2),
)
```

To feed page metadata (header/footer text and alignment), use `FlipbookPage`:

```dart
FlipbookPage(
  image: imageProvider,
  hiResImage: imageProviderHiRes,
  headerText: 'Chapter One',
  footerText: '1',
  headerAlignment: Alignment.topRight,
)
```

## Widget Page Usage

`FlipbookPage` can be backed by a widget instead of an image:

```dart
FlipbookPage(
  widgetBuilder: (context) {
    return Container(
      color: const Color(0xFFFFF8E8),
      alignment: Alignment.center,
      child: const Text('Dynamic page widget'),
    );
  },
  // Recommended when your book is widget-only.
  sizeHint: const Size(1000, 1414),
  headerText: 'Chapter One',
  footerText: '12',
)
```

Notes:
- Resting pages render as live widgets.
- During 3D page-turn, widget pages are rendered from internal snapshots to preserve strip-based performance.
- If both `image` and `widgetBuilder` are provided, the live widget is used for resting pages and image/snapshot is used as fallback texture for flips.

## Core API

### `RealisticFlipbook`

- `pages` (`List<FlipbookPage?>`) required
- `controller` (`FlipbookController?`)
- `flipDuration`, `zoomDuration`
- `zooms` (`List<double>`)
- `perspective`, `nPolygons`, `ambient`, `gloss`, `swipeMin`
- `singlePage`, `forwardDirection`, `centering`, `startPage`
- `singlePageSpreadNavigation`, `singlePageSlideDuration`
- `clickToZoom`, `dragToFlip`, `dragToScroll`, `wheel`
- `paperColor`, `blankPageColor`
- optional page chrome settings are available for header/footer zones, decorative borders, and paper styling
- callbacks:
  - `onFlipLeftStart`, `onFlipLeftEnd`
  - `onFlipRightStart`, `onFlipRightEnd`
  - `onZoomStart`, `onZoomEnd`

### `FlipbookPage`

- `image` (`ImageProvider?`) optional
- `widgetBuilder` (`WidgetBuilder?`) optional
- `sizeHint` (`Size?`) optional (recommended for widget-only books)
- `hiResImage` (`ImageProvider?`) optional (used for zoomed rendering)
- `headerText` (`String?`) optional
- `footerText` (`String?`) optional
- `headerAlignment` (`Alignment`) optional

At least one of `image` or `widgetBuilder` must be provided.

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
- In single-page mode, spread-aware navigation is enabled by default: the first step within a spread uses a horizontal camera slide, and the next step uses a page-turn to move to the next spread.
- Drag flip progress is direct and can be completed by velocity fling.
- Hi-res images are preloaded around the active page range for smoother zoomed rendering.
- Widget pages are captured as textures around the active range so they can be used inside the 3D strip renderer.

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
  - Set `paperColor` and enable page chrome if needed.

## Example App

A runnable example is provided in `/example`.

```bash
cd example
flutter run
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
