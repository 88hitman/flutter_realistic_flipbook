import 'package:flutter/material.dart';
import 'package:flutter_flipbook/flutter_flipbook.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB25C2B)),
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final controller = FlipbookController();

  late final pages = <FlipbookPage?>[
    null,
    _page('flipbook-1'),
    _page('flipbook-2'),
    _page('flipbook-3'),
    _page('flipbook-4'),
    _page('flipbook-5'),
    _page('flipbook-6'),
  ];

  static FlipbookPage _page(String id) {
    return FlipbookPage(
      image: NetworkImage('https://picsum.photos/seed/$id/1200/1800'),
      hiResImage: NetworkImage('https://picsum.photos/seed/$id-hq/2400/3600'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      appBar: AppBar(
        title: const Text('Realistic Flipbook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: controller.zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: controller.zoomIn,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: RealisticFlipbook(
          controller: controller,
          pages: pages,
          nPolygons: 10,
          perspective: 2400,
          ambient: 0.4,
          gloss: 0.6,
          zooms: const [1, 2, 4],
          flipDuration: const Duration(milliseconds: 1000),
          zoomDuration: const Duration(milliseconds: 500),
          clickToZoom: true,
          dragToFlip: true,
          dragToScroll: true,
          wheel: FlipbookWheelMode.scroll,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: controller.flipLeft,
                  child: const Text('Page précédente'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: controller.flipRight,
                  child: const Text('Page suivante'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
