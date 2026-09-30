import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'page_curl_geometry.dart';

/// Visual options of the physical renderer.
class FlipbookPhysicalStyle {
  const FlipbookPhysicalStyle({
    this.curl = 1,
    this.velocityCurl = 1,
    this.castShadow = 1,
    this.showThrough = 0.035,
    this.gutterShadow = 1,
    this.bookBlock = true,
    this.bookBlockMaxLayers = 5,
    this.paperEdge = true,
    this.haptics = true,
    this.cornerPeek = false,
  });

  /// Roll radius of the page, relative to the default.
  final double curl;

  /// How much a fast turn bends the page more, relative to the default.
  final double velocityCurl;

  /// Strength of the shadows cast by the lifted page (0 disables them).
  final double castShadow;

  /// Opacity of the other side's ink seen through a lifted page.
  final double showThrough;

  /// Strength of the shading in the binding (0 disables it).
  final double gutterShadow;

  /// Draws the stacked page edges, thicker on the side holding more pages.
  final bool bookBlock;
  final int bookBlockMaxLayers;

  /// Thin line along the free edges of a lifted page.
  final bool paperEdge;

  /// Light vibration when the page tips over and when it lands.
  final bool haptics;

  /// Holding a finger still on an outer corner lifts it to peek.
  final bool cornerPeek;
}

/// Paints one turning leaf, its shadows and its lighting.
class PhysicalPagePainter extends CustomPainter {
  PhysicalPagePainter({
    required this.frame,
    required this.frontImage,
    required this.backImage,
    required this.paperColor,
    required this.ambient,
    required this.gloss,
    required this.style,
  });

  final CurlFrame frame;
  final ui.Image frontImage;
  final ui.Image backImage;
  final Color paperColor;
  final double ambient;
  final double gloss;
  final FlipbookPhysicalStyle style;

  Paint _texture(ui.Image image, {double opacity = 1}) {
    final leaf = frame.leaf;
    final matrix = Matrix4.diagonal3Values(
      leaf.width / image.width,
      leaf.height / image.height,
      1,
    );
    return Paint()
      ..color = Color.fromRGBO(0, 0, 0, opacity)
      ..shader = ui.ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        matrix.storage,
        filterQuality: FilterQuality.medium,
      );
  }

  void _drawMesh(
    Canvas canvas,
    CurlMesh mesh, {
    required bool front,
    required Paint texture,
    Paint? paper,
  }) {
    if (mesh.isEmpty) {
      return;
    }
    if (paper != null) {
      canvas.drawVertices(mesh.plain(), BlendMode.srcOver, paper);
    }
    canvas.drawVertices(
        mesh.vertices(front: front), BlendMode.srcOver, texture);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lift = frame.maxLift;
    final leafWidth = frame.leaf.width;
    final liftRatio = (lift / (leafWidth * 0.25)).clamp(0.0, 1.0);
    final paper = Paint()..color = paperColor;
    final frontTexture = _texture(frontImage);
    final backTexture = _texture(backImage);

    // 1. The part of the leaf still lying flat.
    _drawMesh(
      canvas,
      frame.unfolded,
      front: true,
      texture: frontTexture,
      paper: paper,
    );

    // 2. Soft shade of the lifted paper on the book, blurred as one layer
    //    so it always hugs the paper.
    if (style.castShadow > 0 && lift > 0.5 && frame.shadows.isNotEmpty) {
      final sigma = (3 + lift * 0.035).clamp(3.0, 14.0).toDouble();
      canvas.saveLayer(
        frame.bookRect.inflate(sigma * 3),
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
      );
      final shade = Paint();
      for (final patch in frame.shadows) {
        final alpha = (0.32 * style.castShadow * patch.strength)
            .clamp(0.0, 0.45)
            .toDouble();
        if (alpha <= 0.004) {
          continue;
        }
        shade.color = Color.fromRGBO(0, 0, 0, alpha);
        canvas.drawPath(patch.footprint, shade);
      }
      canvas.restore();
    }

    // 3. Lifted paper, from the fold outward: farther paper is higher.
    for (final run in frame.runs) {
      _drawMesh(
        canvas,
        run.mesh,
        front: run.front,
        texture: run.front ? frontTexture : backTexture,
        paper: paper,
      );
      if (style.showThrough > 0 && liftRatio > 0) {
        _drawMesh(
          canvas,
          run.mesh,
          front: !run.front,
          texture: _texture(
            run.front ? backImage : frontImage,
            opacity: style.showThrough * liftRatio,
          ),
        );
      }
      _shade(canvas, run.slices);
    }

    if (style.paperEdge && lift > 0.5) {
      canvas.drawPath(
        frame.paperEdges,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..isAntiAlias = true
          ..color = Color.lerp(paperColor, const Color(0xFF000000), 0.28)!
              .withValues(alpha: 0.55),
      );
    }
  }

  void _shade(Canvas canvas, List<BendSlice> slices) {
    final blackness = 1 - ambient;
    // Shading reuses the paper's own triangles: slices tile exactly, without
    // gaps or double coverage, and each turns only a few degrees so no
    // banding shows.
    final dark = Paint();
    final light = Paint();
    for (final slice in slices) {
      // Angle between the visible face and the reader, 0 when facing them.
      final facing =
          math.cos(slice.theta) >= 0 ? slice.theta : math.pi - slice.theta;
      // Paper darkens as it turns away from the light above the book.
      final shade = (blackness * 0.9 * (1 - math.cos(facing))).clamp(0.0, 0.85);
      if (shade > 0.004) {
        dark.color = Color.fromRGBO(0, 0, 0, shade);
        canvas.drawVertices(slice.triangles, BlendMode.srcOver, dark);
      }
      if (gloss > 0) {
        // A narrow sheen where the bent paper mirrors the light, on the side
        // of the roll that faces it.
        final glint = (gloss *
                0.7 *
                math.pow(
                  math.max(0.0, math.cos(facing - math.pi / 6)),
                  140,
                ))
            .clamp(0.0, 0.5)
            .toDouble();
        if (glint > 0.004) {
          light.color = Color.fromRGBO(255, 255, 255, glint);
          canvas.drawVertices(slice.triangles, BlendMode.srcOver, light);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PhysicalPagePainter oldDelegate) => true;
}

/// Shading in the binding and the stacked page edges around the book.
class BookBodyPainter extends CustomPainter {
  BookBodyPainter({
    required this.pages,
    required this.spineX,
    required this.top,
    required this.pageWidth,
    required this.pageHeight,
    required this.paperColor,
    required this.style,
    required this.drawBlock,
  });

  /// Rectangles of the pages lying on each side of the spine, when present.
  final ({Rect? left, Rect? right}) pages;
  final double spineX;
  final double top;
  final double pageWidth;
  final double pageHeight;
  final Color paperColor;
  final FlipbookPhysicalStyle style;

  /// Leaves stacked under the left and right pages, from 0 to 1.
  final ({double left, double right})? drawBlock;

  @override
  void paint(Canvas canvas, Size size) {
    final block = drawBlock;
    if (block != null && style.bookBlock) {
      _drawBlock(canvas, pages.left, block.left, toLeft: true);
      _drawBlock(canvas, pages.right, block.right, toLeft: false);
    }
  }

  void _drawBlock(
    Canvas canvas,
    Rect? page,
    double amount, {
    required bool toLeft,
  }) {
    if (page == null || amount <= 0) {
      return;
    }
    // Seen from the front only the outer edge of the block shows: a few
    // hairline sheets, a little shorter each, darker toward the outside.
    final layers = (style.bookBlockMaxLayers * amount).ceil();
    final sign = toLeft ? -1.0 : 1.0;
    final edgeX = toLeft ? page.left : page.right;
    const pitch = 0.75;
    final line = Paint()..strokeWidth = 0.5;
    for (var i = 1; i <= layers; i++) {
      final x = edgeX + sign * i * pitch;
      final inset = i * 0.35;
      final shade = 0.1 + 0.28 * i / layers;
      canvas.drawRect(
        Rect.fromLTRB(
          math.min(x, x - sign * pitch),
          page.top + inset,
          math.max(x, x - sign * pitch),
          page.bottom - inset,
        ),
        Paint()..color = paperColor,
      );
      line.color = Color.lerp(paperColor, const Color(0xFF000000), shade)!;
      canvas.drawLine(
        Offset(x, page.top + inset),
        Offset(x, page.bottom - inset),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BookBodyPainter old) =>
      old.pages != pages ||
      old.spineX != spineX ||
      old.drawBlock != drawBlock ||
      old.paperColor != paperColor;
}

/// Shading drawn over the pages, darkest at the binding.
class GutterPainter extends CustomPainter {
  GutterPainter({
    required this.spineX,
    required this.top,
    required this.pageWidth,
    required this.pageHeight,
    required this.strength,
    required this.leftPage,
    required this.rightPage,
  });

  final double spineX;
  final double top;
  final double pageWidth;
  final double pageHeight;
  final double strength;
  final bool leftPage;
  final bool rightPage;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) {
      return;
    }
    final width = pageWidth * 0.075;
    void side(double sign) {
      final rect = Rect.fromLTWH(
        sign > 0 ? spineX : spineX - width,
        top,
        width,
        pageHeight,
      );
      final from = Offset(spineX, 0);
      final to = Offset(spineX + sign * width, 0);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            from,
            to,
            <Color>[
              Color.fromRGBO(0, 0, 0, 0.2 * strength),
              Color.fromRGBO(0, 0, 0, 0.07 * strength),
              Color.fromRGBO(255, 255, 255, 0.05 * strength),
              const Color.fromRGBO(255, 255, 255, 0),
            ],
            const <double>[0, 0.3, 0.75, 1],
          ),
      );
    }

    if (leftPage) {
      side(-1);
    }
    if (rightPage) {
      side(1);
    }
  }

  @override
  bool shouldRepaint(covariant GutterPainter old) =>
      old.spineX != spineX ||
      old.top != top ||
      old.pageWidth != pageWidth ||
      old.strength != strength ||
      old.leftPage != leftPage ||
      old.rightPage != rightPage;
}
