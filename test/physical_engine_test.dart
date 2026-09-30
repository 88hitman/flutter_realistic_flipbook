import 'dart:math' as math;

import 'package:flutter_realistic_flipbook/src/physical/page_curl_geometry.dart';
import 'package:flutter_realistic_flipbook/src/physical/page_turn_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const w = 400.0;
  const h = 600.0;

  group('PageBend', () {
    PageBend pose(double p, {double bend = 1.9, double tilt = 0}) =>
        PageBend.pose(
          width: w,
          height: h,
          progress: p,
          bend: bend * math.pow(math.sin(math.pi * p), 0.8),
          grabY: 500,
          tilt: tilt,
        );

    test('the spine never lifts and paper never goes under the book', () {
      for (var i = 0; i <= 40; i++) {
        final p = i / 40;
        for (final tilt in <double>[-0.6, 0, 0.6]) {
          for (final bend in <double>[-1, 0, 1.9]) {
            final shape = pose(p, bend: bend, tilt: tilt);
            for (final y in <double>[0, 300, 600]) {
              final (x, yy, z) = shape.map(0, y);
              expect(x, closeTo(0, 1e-6), reason: 'p=$p tilt=$tilt');
              expect(yy, closeTo(y, 1e-6));
              expect(z, closeTo(0, 1e-6));
              for (final px in <double>[100, 250, 400]) {
                final (_, __, pz) = shape.map(px, y);
                expect(pz, greaterThanOrEqualTo(-1e-6));
              }
            }
          }
        }
      }
    });

    test('paper keeps its length while it bends', () {
      for (final p in <double>[0.1, 0.3, 0.5, 0.8]) {
        final shape = pose(p);
        var length = 0.0;
        var previous = shape.map(0, 300);
        for (var i = 1; i <= 400; i++) {
          final point = shape.map(i.toDouble(), 300);
          final dx = point.$1 - previous.$1;
          final dz = point.$3 - previous.$3;
          length += math.sqrt(dx * dx + dz * dz);
          previous = point;
        }
        expect(length, closeTo(w, 0.5), reason: 'p=$p');
      }
    });

    test('the leaf rises from the spine and stands up mid-turn', () {
      final (edgeX, _, edgeZ) = pose(0.5).map(w, 300);
      expect(edgeZ, greaterThan(w * 0.5));
      expect(edgeX.abs(), lessThan(w * 0.35));
      final (_, __, lowZ) = pose(0.08).map(w, 300);
      expect(lowZ, greaterThan(0));
      expect(lowZ, lessThan(edgeZ));
    });

    test('a finished turn lies flat, mirrored across the spine', () {
      final (x, y, z) = pose(1).map(300, 100);
      expect(x, closeTo(-300, 1e-6));
      expect(y, closeTo(100, 1e-6));
      expect(z, closeTo(0, 1e-6));
    });

    test('a corner pulled up lifts first', () {
      final shape = pose(0.12, tilt: 0.5);
      final (_, __, zTop) = shape.map(w, 0);
      final (_, ___, zBottom) = shape.map(w, h);
      expect(zBottom, greaterThan(zTop));
    });

    test('the mesh covers the whole page, once', () {
      const leaf = LeafFrame(
        spineX: 400,
        top: 0,
        width: w,
        height: h,
        rightHanded: true,
        viewCenter: Offset(400, 300),
        perspective: 2200,
      );
      for (final p in <double>[0.1, 0.45, 0.7]) {
        final frame = CurlFrame.build(leaf: leaf, bend: pose(p, tilt: 0.3));
        double texArea(CurlMesh mesh) {
          var area = 0.0;
          final t = mesh.frontTex;
          for (var i = 0; i < t.length; i += 6) {
            area += ((t[i + 2] - t[i]) * (t[i + 5] - t[i + 1]) -
                        (t[i + 4] - t[i]) * (t[i + 3] - t[i + 1]))
                    .abs() /
                2;
          }
          return area;
        }

        final total = texArea(frame.unfolded) +
            frame.runs.fold<double>(0, (sum, run) => sum + texArea(run.mesh));
        expect(total, closeTo(w * h, w * h * 0.001), reason: 'p=$p');
        expect(frame.runs, isNotEmpty);
      }
    });
  });

  group('PageTurnSimulation', () {
    test('keeps the finger speed at release', () {
      final sim = PageTurnSimulation(start: 0.4, velocity: 2.5, target: 1);
      expect(sim.dx(0), closeTo(2.5, 1e-9));
      expect(sim.x(0.004), closeTo(0.4 + 2.5 * 0.004, 0.002));
    });

    test('lands on its target and stays inside the book', () {
      for (final start in <double>[0, 0.1, 0.5, 0.9]) {
        for (final v in <double>[-3, 0, 0.5, 6]) {
          for (final target in <double>[0, 1]) {
            final sim =
                PageTurnSimulation(start: start, velocity: v, target: target);
            expect(sim.x(sim.duration), target);
            expect(sim.isDone(sim.duration), isTrue);
            expect(sim.duration, lessThan(3));
            for (var t = 0.0; t < sim.duration; t += 0.005) {
              expect(sim.x(t), inInclusiveRange(0, 1));
            }
          }
        }
      }
    });

    test('a turn speeds up as it falls, then the air slows it down', () {
      final sim = PageTurnSimulation(start: 0, velocity: 1.25, target: 1);
      final landing = sim.landingTime;
      final top = sim.dx(landing * 0.35);
      final falling = sim.dx(landing * 0.8);
      expect(falling, greaterThan(top));
      expect(sim.dx(landing - 0.002), lessThan(sim.dx(landing * 0.85)));
      // ignore: avoid_print
      print('auto turn: landing ${landing.toStringAsFixed(3)} s, '
          'rest ${sim.duration.toStringAsFixed(3)} s');
    });

    test('time scale plays the same motion faster', () {
      final slow = PageTurnSimulation(start: 0, velocity: 1.25, target: 1);
      final fast = PageTurnSimulation(
        start: 0,
        velocity: 2.5,
        target: 1,
        timeScale: 2,
      );
      expect(fast.landingTime, closeTo(slow.landingTime / 2, 0.01));
    });
  });
}
