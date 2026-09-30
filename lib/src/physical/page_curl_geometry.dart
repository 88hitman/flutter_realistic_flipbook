import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Where a turning leaf sits on screen.
///
/// Leaf-local coordinates put the spine at `x = 0` and the free edge at
/// `x = width`, with `y` going down and `z` toward the reader. [rightHanded]
/// leaves extend to the right of the spine on screen, left-handed ones to the
/// left.
class LeafFrame {
  const LeafFrame({
    required this.spineX,
    required this.top,
    required this.width,
    required this.height,
    required this.rightHanded,
    required this.viewCenter,
    required this.perspective,
  });

  final double spineX;
  final double top;
  final double width;
  final double height;
  final bool rightHanded;
  final Offset viewCenter;
  final double perspective;

  Offset project(double x, double y, double z) {
    final sx = rightHanded ? spineX + x : spineX - x;
    final sy = top + y;
    if (z == 0 || perspective <= 0) {
      return Offset(sx, sy);
    }
    final s = perspective / math.max(perspective - z, perspective * 0.2);
    return Offset(
      viewCenter.dx + (sx - viewCenter.dx) * s,
      viewCenter.dy + (sy - viewCenter.dy) * s,
    );
  }

  /// Texture coordinate, in page units, of a leaf point on its front face.
  double frontTexX(double x) => rightHanded ? x : width - x;

  /// Texture coordinate, in page units, of a leaf point on its back face.
  double backTexX(double x) => rightHanded ? width - x : x;
}

/// Shape of a leaf bound at the spine and lifted by a hand.
///
/// Points with `u <= 0` lie flat, `u` being the distance from the line where
/// the paper leaves the book, measured along [axis]. Beyond that line the
/// paper leaves at angle [hinge] (0 = flat, π = flat on the other side) and
/// bends progressively: its angle grows by [bend] · (u / [length])^[power],
/// so the paper stays calm near the spine and bends most toward the hand, as
/// a real sheet does. Paper length is preserved.
class PageBend {
  PageBend._({
    required this.foldPoint,
    required this.axis,
    required this.hinge,
    required this.bend,
    required this.length,
    required this.power,
    required this.uMax,
  }) {
    _buildTable();
  }

  PageBend.flat()
      : foldPoint = const Offset(double.infinity, 0),
        axis = const Offset(1, 0),
        hinge = 0,
        bend = 0,
        length = 1,
        power = 1,
        uMax = 0;

  final Offset foldPoint;
  final Offset axis;
  final double hinge;
  final double bend;
  final double length;
  final double power;
  final double uMax;

  static const int _samples = 256;
  final List<double> _runs = <double>[];
  final List<double> _lifts = <double>[];
  double _step = 1;

  bool get isFlat => !foldPoint.dx.isFinite;

  double uOf(double x, double y) =>
      (x - foldPoint.dx) * axis.dx + (y - foldPoint.dy) * axis.dy;

  /// Paper angle at distance [u] beyond the fold (0 facing the reader).
  double thetaAt(double u) {
    if (u <= 0) {
      return 0;
    }
    final t = u / length;
    return (hinge + bend * math.pow(t, power)).clamp(0.0, math.pi).toDouble();
  }

  void _buildTable() {
    _step = math.max(uMax, 1e-6) / _samples;
    var run = 0.0;
    var lift = 0.0;
    _runs.add(0);
    _lifts.add(0);
    for (var i = 0; i < _samples; i++) {
      final theta = thetaAt((i + 0.5) * _step);
      run += math.cos(theta) * _step;
      lift += math.sin(theta) * _step;
      _runs.add(run);
      _lifts.add(lift);
    }
  }

  /// Horizontal run and lift of the profile after a length [u] of paper.
  (double, double) profile(double u) {
    if (u <= 0 || isFlat) {
      return (u, 0);
    }
    final f = u / _step;
    final i = f.floor();
    if (i >= _samples) {
      // Beyond the table (rounding only): continue straight.
      final extra = u - uMax;
      final theta = thetaAt(uMax);
      return (
        _runs.last + extra * math.cos(theta),
        _lifts.last + extra * math.sin(theta),
      );
    }
    final t = f - i;
    return (
      _runs[i] + (_runs[i + 1] - _runs[i]) * t,
      _lifts[i] + (_lifts[i + 1] - _lifts[i]) * t,
    );
  }

  /// Maps a leaf point to its lifted position `(x, y, z)`.
  (double, double, double) map(double x, double y) {
    if (isFlat) {
      return (x, y, 0);
    }
    final u = uOf(x, y);
    if (u <= 0) {
      return (x, y, 0);
    }
    final (run, lift) = profile(u);
    final along = run - u;
    return (x + axis.dx * along, y + axis.dy * along, lift);
  }

  /// Distance beyond the fold where the paper turns edge-on, if it does.
  double? edgeOnU() {
    if (isFlat) {
      return null;
    }
    final a = thetaAt(1e-9) - math.pi / 2;
    final b = thetaAt(uMax) - math.pi / 2;
    if (a * b >= 0) {
      return null;
    }
    return _solve(math.pi / 2);
  }

  double? _solve(double theta) {
    var lo = 0.0;
    var hi = uMax;
    final rising = thetaAt(hi) > thetaAt(1e-9);
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      final below = thetaAt(mid) < theta;
      if (below == rising) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final u = (lo + hi) / 2;
    return u > 1e-6 && u < uMax - 1e-6 ? u : null;
  }

  /// Pose of a leaf for a turn [progress] from 0 (flat, unturned) to 1 (flat
  /// on the other side).
  ///
  /// First the paper bows up from the spine toward the hand ([liftEnd]),
  /// then the whole leaf swings around the spine. [bend] is how far the free
  /// edge leads (positive) or trails (negative) the paper at the spine, in
  /// radians. [tilt] turns the bending axis toward a corner; it fades as the
  /// leaf starts to swing, since the spine is straight.
  static PageBend pose({
    required double width,
    required double height,
    required double progress,
    required double bend,
    double grabY = double.nan,
    double tilt = 0,
    double liftEnd = 0.25,
    double power = 1.25,
  }) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 1e-5) {
      return PageBend.flat();
    }
    final lift = _smoothstep(p / liftEnd);
    final hinge = p <= liftEnd
        ? 0.0
        : math.pi *
            math
                .pow((p - liftEnd) / (1 - liftEnd), 1.15)
                .toDouble()
                .clamp(0.0, 1.0);
    final t = tilt.clamp(-0.6, 0.6) *
        (1 - lift * 0.85) *
        (1 - (hinge / math.pi).clamp(0.0, 1.0));
    final axis = Offset(math.cos(t), math.sin(t));
    final rowY = grabY.isFinite ? grabY.clamp(0.0, height) : height / 2;
    var fold = Offset(0, rowY.toDouble());
    // A tilted fold must stay inside the page: the spine is bound.
    double xAt(double y) => fold.dx - (y - fold.dy) * axis.dy / axis.dx;
    final minX = math.min(xAt(0), xAt(height));
    if (minX < 0) {
      fold = Offset(fold.dx - minX, fold.dy);
    }
    var uMax = 0.0;
    for (final c in <Offset>[
      Offset(width, 0),
      Offset(width, height),
      Offset.zero,
      Offset(0, height),
    ]) {
      final u = (c.dx - fold.dx) * axis.dx + (c.dy - fold.dy) * axis.dy;
      uMax = math.max(uMax, u);
    }
    if (uMax <= 1e-3) {
      return PageBend.flat();
    }
    final length = math.max(1.0, (width - fold.dx) / math.max(axis.dx, 0.2));
    final reach = math.pow(uMax / length, power).toDouble();
    // Paper stays between the two sides of the book.
    final b = bend.clamp(-hinge / reach, (math.pi - hinge) / reach).toDouble();
    return PageBend._(
      foldPoint: fold,
      axis: axis,
      hinge: hinge,
      bend: b,
      length: length,
      power: power,
      uMax: uMax,
    );
  }

  static double _smoothstep(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }
}

/// Shade cast straight down by one band of lifted paper.
class ShadowPatch {
  const ShadowPatch(this.footprint, this.strength);

  /// The band flattened on the book.
  final Path footprint;

  /// From 1 (paper touching the book) toward 0 (paper high above it).
  final double strength;
}

/// A triangle soup ready for `Canvas.drawVertices`.
class CurlMesh {
  CurlMesh(this.positions, this.frontTex, this.backTex);

  final Float32List positions;
  final Float32List frontTex;
  final Float32List backTex;

  bool get isEmpty => positions.isEmpty;

  Vertices vertices({required bool front}) => Vertices.raw(
        VertexMode.triangles,
        positions,
        textureCoordinates: front ? frontTex : backTex,
      );

  Vertices plain() => Vertices.raw(VertexMode.triangles, positions);
}

/// A thin band of lifted paper with a single orientation.
class BendSlice {
  const BendSlice(this.triangles, this.theta);

  /// The same triangles as the paper mesh, so shading covers it exactly.
  final Vertices triangles;

  /// Paper angle in the middle of the slice (0 facing the reader).
  final double theta;
}

/// Consecutive lifted slices showing the same face, drawn in one call.
class BendRun {
  BendRun({required this.front, required this.mesh, required this.slices});

  final bool front;
  final CurlMesh mesh;
  final List<BendSlice> slices;
}

/// Everything the painter needs to draw one turning leaf.
class CurlFrame {
  CurlFrame({
    required this.leaf,
    required this.bend,
    required this.unfolded,
    required this.runs,
    required this.shadows,
    required this.bookRect,
    required this.paperEdges,
    required this.maxLift,
    required this.minX,
    required this.maxX,
  });

  final LeafFrame leaf;
  final PageBend bend;

  /// The part of the leaf still lying flat, front face up.
  final CurlMesh unfolded;

  /// Lifted paper, in drawing order (farther from the fold is higher).
  final List<BendRun> runs;

  /// Shade of the lifted paper on the book, to be blurred as one layer.
  final List<ShadowPatch> shadows;

  /// Both pages of the opening, where the shading may fall.
  final Rect bookRect;

  /// Page borders of the lifted paper, stroked as a paper edge.
  final Path paperEdges;
  final double maxLift;
  final double minX;
  final double maxX;

  static CurlFrame build({
    required LeafFrame leaf,
    required PageBend bend,
    double sliceLength = 5,
    double sliceAngle = 0.05,
  }) {
    final w = leaf.width;
    final h = leaf.height;
    final page = <Offset>[
      const Offset(0, 0),
      Offset(w, 0),
      Offset(w, h),
      Offset(0, h),
    ];
    final bounds = _Bounds();

    if (bend.isFlat) {
      return CurlFrame(
        leaf: leaf,
        bend: bend,
        unfolded: (_MeshBuilder(leaf, bend, bounds)..addPolygon(page)).build(),
        runs: const <BendRun>[],
        shadows: const <ShadowPatch>[],
        bookRect: Rect.zero,
        paperEdges: Path(),
        maxLift: 0,
        minX: bounds.minX,
        maxX: bounds.maxX,
      );
    }

    var uMax = 0.0;
    for (final c in page) {
      uMax = math.max(uMax, bend.uOf(c.dx, c.dy));
    }
    final turn = (bend.thetaAt(uMax) - bend.hinge).abs();
    final count = math
        .max((uMax / sliceLength).ceil(), (turn / sliceAngle).ceil())
        .clamp(2, 120);
    final cuts = <double>[for (var i = 0; i <= count; i++) uMax * i / count];
    // Split exactly where the paper turns edge-on, so each run shows one face.
    final edgeOn = bend.edgeOnU();
    if (edgeOn != null) {
      cuts
        ..add(edgeOn)
        ..sort();
    }

    List<Offset> clipped(double uMin, double uMaxClip) {
      var poly = page;
      if (uMin.isFinite) {
        poly = _clip(poly, bend, uMin, keepAbove: true);
      }
      if (uMaxClip.isFinite) {
        poly = _clip(poly, bend, uMaxClip, keepAbove: false);
      }
      return poly;
    }

    final unfolded = _MeshBuilder(leaf, bend, bounds)
      ..addPolygon(clipped(double.negativeInfinity, 0));

    final runs = <BendRun>[];
    _MeshBuilder? runMesh;
    List<BendSlice>? runSlices;
    bool? runFront;
    final edges = Path();
    final shadows = <ShadowPatch>[];
    var maxLift = 0.0;

    void closeRun() {
      final mesh = runMesh;
      final slices = runSlices;
      final front = runFront;
      if (mesh != null &&
          slices != null &&
          front != null &&
          slices.isNotEmpty) {
        runs.add(BendRun(front: front, mesh: mesh.build(), slices: slices));
      }
    }

    for (var i = 0; i < cuts.length - 1; i++) {
      final u0 = cuts[i];
      final u1 = cuts[i + 1];
      if (u1 - u0 < 1e-6) {
        continue;
      }
      final poly = clipped(u0, u1);
      if (poly.length < 3) {
        continue;
      }
      final theta = bend.thetaAt((u0 + u1) / 2);
      final front = math.cos(theta) >= 0;
      if (front != runFront) {
        closeRun();
        runFront = front;
        runMesh = _MeshBuilder(leaf, bend, bounds);
        runSlices = <BendSlice>[];
      }
      runMesh!.addPolygon(poly);
      final projected = <Offset>[];
      final footprint = <Offset>[];
      var sliceLift = 0.0;
      for (final p in poly) {
        final (x, y, z) = bend.map(p.dx, p.dy);
        maxLift = math.max(maxLift, z);
        sliceLift += z / poly.length;
        projected.add(leaf.project(x, y, z));
        footprint.add(leaf.project(x, y, 0));
      }
      // Light from above: a band shades the book right below it. Paper
      // touching the book casts nothing, a slightly raised band the most,
      // and the shade fades as it rises higher.
      final rise = sliceLift / (w * 0.12);
      shadows.add(
        ShadowPatch(
          Path()..addPolygon(footprint, true),
          rise * math.exp(1 - rise),
        ),
      );
      final fan = <double>[];
      for (var j = 1; j < projected.length - 1; j++) {
        for (final k in <int>[0, j, j + 1]) {
          fan
            ..add(projected[k].dx)
            ..add(projected[k].dy);
        }
      }
      runSlices!.add(
        BendSlice(
          Vertices.raw(VertexMode.triangles, Float32List.fromList(fan)),
          theta,
        ),
      );
      for (var j = 0; j < poly.length; j++) {
        final a = poly[j];
        final b = poly[(j + 1) % poly.length];
        if (_onPageBorder(a, b, w, h)) {
          edges
            ..moveTo(projected[j].dx, projected[j].dy)
            ..lineTo(
              projected[(j + 1) % poly.length].dx,
              projected[(j + 1) % poly.length].dy,
            );
        }
      }
    }
    closeRun();

    return CurlFrame(
      leaf: leaf,
      bend: bend,
      unfolded: unfolded.build(),
      runs: runs,
      shadows: shadows,
      bookRect: Rect.fromPoints(
        leaf.project(-w, 0, 0),
        leaf.project(w, h, 0),
      ),
      paperEdges: edges,
      maxLift: maxLift,
      minX: bounds.minX,
      maxX: bounds.maxX,
    );
  }

  static bool _onPageBorder(Offset a, Offset b, double w, double h) {
    const eps = 0.01;
    bool same(double p, double q, double v) =>
        (p - v).abs() < eps && (q - v).abs() < eps;
    // The spine edge is bound and never shows as a free paper edge.
    return same(a.dy, b.dy, 0) || same(a.dy, b.dy, h) || same(a.dx, b.dx, w);
  }

  /// Sutherland–Hodgman clip of a convex polygon against `u >= value`
  /// ([keepAbove]) or `u <= value`.
  static List<Offset> _clip(
    List<Offset> poly,
    PageBend bend,
    double value, {
    required bool keepAbove,
  }) {
    if (poly.isEmpty) {
      return poly;
    }
    double side(Offset p) {
      final u = bend.uOf(p.dx, p.dy) - value;
      return keepAbove ? u : -u;
    }

    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final sa = side(a);
      final sb = side(b);
      if (sa >= 0) {
        out.add(a);
      }
      if ((sa >= 0) != (sb >= 0)) {
        final t = sa / (sa - sb);
        out.add(Offset.lerp(a, b, t)!);
      }
    }
    return out;
  }
}

class _Bounds {
  double minX = double.infinity;
  double maxX = -double.infinity;
}

class _MeshBuilder {
  _MeshBuilder(this.leaf, this.bend, this.bounds);

  final LeafFrame leaf;
  final PageBend bend;
  final _Bounds bounds;
  final List<double> _positions = <double>[];
  final List<double> _front = <double>[];
  final List<double> _back = <double>[];

  void addPolygon(List<Offset> poly) {
    if (poly.length < 3) {
      return;
    }
    final mapped = <Offset>[];
    for (final p in poly) {
      final (x, y, z) = bend.map(p.dx, p.dy);
      final s = leaf.project(x, y, z);
      bounds.minX = math.min(bounds.minX, s.dx);
      bounds.maxX = math.max(bounds.maxX, s.dx);
      mapped.add(s);
    }
    for (var i = 1; i < poly.length - 1; i++) {
      for (final k in <int>[0, i, i + 1]) {
        final leafPoint = poly[k];
        _positions
          ..add(mapped[k].dx)
          ..add(mapped[k].dy);
        _front
          ..add(leaf.frontTexX(leafPoint.dx))
          ..add(leafPoint.dy);
        _back
          ..add(leaf.backTexX(leafPoint.dx))
          ..add(leafPoint.dy);
      }
    }
  }

  CurlMesh build() => CurlMesh(
        Float32List.fromList(_positions),
        Float32List.fromList(_front),
        Float32List.fromList(_back),
      );
}
