import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// Tunable physics of a sheet of paper turning around the spine.
class PageTurnPhysics {
  const PageTurnPhysics({
    this.gravity = 5.2,
    this.airDrag = 1.6,
    this.cushion = 0.07,
    this.cushionDrag = 16,
    this.restitution = 0.16,
    this.minTossVelocity = 0.9,
    this.maxTossVelocity = 3,
    this.autoTossVelocity = 1.25,
  });

  /// Pull toward the destination, in turns per second², at its strongest.
  ///
  /// Real paper feels its weight most when lying low and almost none when
  /// standing up, so the pull scales with `|cos(πp)|`.
  final double gravity;

  /// Linear air resistance, per second.
  final double airDrag;

  /// Distance to the destination (in turns) where the trapped air layer
  /// starts to slow the page down before it lands.
  final double cushion;
  final double cushionDrag;

  /// Share of the landing speed given back as a small bounce.
  final double restitution;
  final double minTossVelocity;
  final double maxTossVelocity;

  /// Initial speed of a turn started without a finger (tap, controller).
  final double autoTossVelocity;
}

/// Page progress from its release to rest, integrated once up front.
///
/// Progress `p` goes from 0 (page flat where it started) to 1 (flat on the
/// other side). The trajectory keeps the release [velocity] so there is no
/// speed jump when the finger lets go.
class PageTurnSimulation extends Simulation {
  PageTurnSimulation({
    required double start,
    required double velocity,
    required this.target,
    PageTurnPhysics physics = const PageTurnPhysics(),
    double timeScale = 1,
  }) {
    _integrate(start, velocity, physics, timeScale);
  }

  final double target;
  static const double _dt = 1 / 1000;
  final List<double> _positions = <double>[];
  final List<double> _velocities = <double>[];
  double _landingTime = double.infinity;

  /// When the page first touches down, in seconds.
  double get landingTime => _landingTime;
  double get duration => (_positions.length - 1) * _dt;

  void _integrate(
    double start,
    double velocity,
    PageTurnPhysics physics,
    double timeScale,
  ) {
    final dir = target >= start ? 1.0 : -1.0;
    final k = timeScale;
    var p = start.clamp(0.0, 1.0).toDouble();
    var v = velocity * dir < physics.minTossVelocity * k
        ? physics.minTossVelocity * k * dir
        : velocity
            .clamp(-physics.maxTossVelocity * k, physics.maxTossVelocity * k)
            .toDouble();
    var bounces = 0;
    _positions.add(p);
    _velocities.add(v);
    const maxSteps = 4000;
    for (var step = 0; step < maxSteps; step++) {
      final toTarget = (target - p) * dir;
      final weight = 0.28 + 0.72 * math.cos(math.pi * p).abs();
      var a = dir * physics.gravity * k * k * weight - physics.airDrag * k * v;
      final approaching = v * dir > 0;
      if (approaching && toTarget < physics.cushion) {
        final depth = 1 - (toTarget / physics.cushion).clamp(0.0, 1.0);
        a -= physics.cushionDrag * k * depth * v;
      }
      v += a * _dt;
      p += v * _dt;
      final crossed = (target - p) * dir <= 0;
      if (crossed) {
        _landingTime = math.min(_landingTime, (_positions.length) * _dt);
        final impact = v.abs();
        if (bounces < 2 && impact > 0.35 * k) {
          bounces++;
          p = target - (p - target);
          v = -v * physics.restitution;
        } else {
          _positions.add(target);
          _velocities.add(0);
          return;
        }
      }
      if (bounces > 0 && (target - p).abs() < 0.0015 && v.abs() < 0.05 * k) {
        _positions.add(target);
        _velocities.add(0);
        return;
      }
      _positions.add(p.clamp(0.0, 1.0).toDouble());
      _velocities.add(v);
    }
    _positions.add(target);
    _velocities.add(0);
  }

  int _index(double time) =>
      (time / _dt).round().clamp(0, _positions.length - 1);

  @override
  double x(double time) => _positions[_index(time)];

  @override
  double dx(double time) => _velocities[_index(time)];

  @override
  bool isDone(double time) => _index(time) >= _positions.length - 1;
}
