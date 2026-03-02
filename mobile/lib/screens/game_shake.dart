import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/haptic_service.dart';

class GravityDustGame extends StatefulWidget {
  const GravityDustGame({super.key});
  @override
  State<GravityDustGame> createState() => _GravityDustGameState();
}

class _Particle {
  Offset position;
  Offset velocity;
  final double radius;
  final double opacity;
  final Color color;
  _Particle({required this.position, required this.velocity, required this.radius, required this.opacity, required this.color});
}

class _GravityDustGameState extends State<GravityDustGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  final List<_Particle> _particles = [];
  final Random _rng = Random();
  StreamSubscription? _accelSub;
  double _shakeLevel = 0.0;
  int _cleared = 0;
  bool _complete = false;
  bool _spawned = false;
  static const int _totalParticles = 60;

  static const List<Color> _stressColors = [
    Color(0xFFFF4444), Color(0xFFFF6B35), Color(0xFFFF8C00),
    Color(0xFFCC0000), Color(0xFFFF2222),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(hours: 1))
      ..addListener(_tick)
      ..forward();
    _startSensorStream();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_spawned) {
      _spawned = true;
      final size = MediaQuery.sizeOf(context);
      for (int i = 0; i < _totalParticles; i++) {
        _particles.add(_Particle(
          position: Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
          velocity: Offset((_rng.nextDouble() - 0.5) * 1.5, (_rng.nextDouble() - 0.5) * 1.5),
          radius: 4 + _rng.nextDouble() * 12,
          opacity: 0.7 + _rng.nextDouble() * 0.3,
          color: _stressColors[_rng.nextInt(_stressColors.length)],
        ));
      }
    }
  }

  void _startSensorStream() {
    _accelSub = accelerometerEventStream().listen((ev) {
      final shake = (ev.x.abs() + ev.y.abs() + ev.z.abs()) / 3;
      if (!mounted) return;
      setState(() => _shakeLevel = shake.clamp(0, 20));

      if (shake > 6 && _particles.isNotEmpty) {
        HapticService.rhythmicBuzz(duration: 80);
        final toRemove = (shake / 3).ceil().clamp(0, 5);
        setState(() {
          for (int i = 0; i < toRemove && _particles.isNotEmpty; i++) {
            _particles.removeAt(_rng.nextInt(_particles.length));
            _cleared++;
          }
          if (_particles.isEmpty && !_complete) {
            _complete = true;
          }
        });
        if (_complete) {
          HapticService.successTap();
          _saveRecoveryEvent();
        }
      }
    });
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.position += p.velocity;
        final size = MediaQuery.sizeOf(context);
        if (p.position.dx < 0 || p.position.dx > size.width) p.velocity = Offset(-p.velocity.dx, p.velocity.dy);
        if (p.position.dy < 0 || p.position.dy > size.height) p.velocity = Offset(p.velocity.dx, -p.velocity.dy);
        if (_shakeLevel < 4) p.velocity = p.velocity * 0.99;
      }
    });
  }

  Future<void> _saveRecoveryEvent() async {
    try {
      await http.post(
        Uri.parse('http://10.0.2.2:8000/api/recovery-event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'game': 'gravity_dust', 'cleared': _cleared, 'user': 'Prajwal'}),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    _accelSub?.cancel();
    HapticService.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        CustomPaint(
          painter: _DustPainter(particles: List.from(_particles)),
          size: MediaQuery.sizeOf(context),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('💥 Gravity Dust', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Text('${_particles.length} particles', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
              ]),
            ),
            if (!_complete)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
                ),
                child: const Text('🤝 SHAKE THE PHONE to clear stress particles', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFFFF6B35), fontFamily: 'monospace')),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _complete ? _CompleteBanner() : Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Shake Intensity', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  Text('${_shakeLevel.toStringAsFixed(1)} m/s²', style: const TextStyle(fontSize: 11, color: Color(0xFFFF6B35), fontFamily: 'monospace')),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _shakeLevel / 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${_totalParticles - _particles.length}/$_totalParticles cleared', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DustPainter extends CustomPainter {
  final List<_Particle> particles;
  _DustPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(p.position, p.radius, paint);
      canvas.drawCircle(p.position, p.radius * 0.4, Paint()..color = Colors.white.withValues(alpha: 0.4));
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => true;
}

class _CompleteBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
    const Text('🎉', style: TextStyle(fontSize: 48)),
    const SizedBox(height: 8),
    const Text('All Clear!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF68D391))),
    const SizedBox(height: 4),
    Text('Recovery event logged.', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
    const SizedBox(height: 16),
    ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF68D391), foregroundColor: Colors.black),
      child: const Text('Back to Dashboard'),
    ),
  ]);
}
