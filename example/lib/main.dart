import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realistic_flipbook/flutter_realistic_flipbook.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
    _page(1),
    _page(2),
    _page(3),
    _page(4),
    _page(5),
    _page(6),
  ];

  static FlipbookPage _page(int id) {
    final image = AssetImage('assets/images/$id.jpg');
    return FlipbookPage(
      image: image,
      hiResImage: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: RealisticFlipbook(
            controller: controller,
            pages: pages,
            nPolygons: 14,
            perspective: 2200,
            ambient: 0.72,
            gloss: 0.25,
            clipToViewport: false,
            zooms: const [1, 2, 4],
            flipDuration: const Duration(milliseconds: 1300),
            zoomDuration: const Duration(milliseconds: 500),
            clickToZoom: true,
            dragToFlip: true,
            dragToScroll: true,
            wheel: FlipbookWheelMode.scroll,
            singlePageSpreadNavigation: true,
            singlePageSlideDuration: const Duration(milliseconds: 320),
          ),
        ),
      ),
    );
  }
}
