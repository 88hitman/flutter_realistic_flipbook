# flutter_flipbook

Widget Flutter de flipbook 3D réaliste inspiré de `flipbook-vue`:

- courbure de page par découpe en bandes (`nPolygons`)
- perspective 3D + rotation par bande
- éclairage diffus + reflet spéculaire
- drag-to-flip, clic/tap, zoom, scroll
- mode 1 page / double page selon viewport

## Installation

Dans ton projet Flutter:

```yaml
dependencies:
  flutter_flipbook:
    path: ../flutter_flipbook
```

## Utilisation rapide

```dart
import 'package:flutter/material.dart';
import 'package:flutter_flipbook/flutter_flipbook.dart';

class DemoBook extends StatefulWidget {
  const DemoBook({super.key});

  @override
  State<DemoBook> createState() => _DemoBookState();
}

class _DemoBookState extends State<DemoBook> {
  final controller = FlipbookController();

  late final pages = <FlipbookPage?>[
    null, // même comportement que le repo Vue: couverture seule
    const FlipbookPage(image: AssetImage('assets/pages/1.jpg')),
    const FlipbookPage(image: AssetImage('assets/pages/2.jpg')),
    const FlipbookPage(image: AssetImage('assets/pages/3.jpg')),
    const FlipbookPage(image: AssetImage('assets/pages/4.jpg')),
    const FlipbookPage(image: AssetImage('assets/pages/5.jpg')),
    const FlipbookPage(image: AssetImage('assets/pages/6.jpg')),
  ];

  @override
  Widget build(BuildContext context) {
    return RealisticFlipbook(
      controller: controller,
      pages: pages,
      nPolygons: 10,
      perspective: 2400,
      ambient: 0.4,
      gloss: 0.6,
      flipDuration: const Duration(milliseconds: 1000),
      zoomDuration: const Duration(milliseconds: 500),
      zooms: const [1, 2, 4],
      clickToZoom: true,
      dragToFlip: true,
      wheel: FlipbookWheelMode.scroll,
    );
  }
}
```

## API principale

- `RealisticFlipbook.pages`: `List<FlipbookPage?>` (mettre `null` en 1er pour une couverture isolée)
- `FlipbookPage(image, hiResImage?)`
- `controller`: `FlipbookController` (`flipLeft`, `flipRight`, `zoomIn`, `zoomOut`, `goToPage`)
- paramètres visuels: `nPolygons`, `perspective`, `ambient`, `gloss`
- interaction: `clickToZoom`, `dragToFlip`, `dragToScroll`, `wheel`
- callbacks: `onFlipLeftStart`, `onFlipLeftEnd`, `onFlipRightStart`, `onFlipRightEnd`, `onZoomStart`, `onZoomEnd`
