import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

/// BubblePop — Tactile grounding game.
/// Floating soft-coloured bubbles rise from the bottom.
/// Tap to pop — haptic + visual burst. No timer, no score, pure sensory relief.
class BubblePopGame extends StatefulWidget {
  const BubblePopGame({super.key});
  @override
  State<BubblePopGame> createState() => _BubblePopGameState();
}

class _Bubble {
  Offset position;
  double radius;
  Color color;
  double opacity;
  double speed;
  bool popping;
  double popProgress;

  _Bubble({
    required this.position,
    required this.radius,
    required this.color,
    required this.speed,
    this.opacity = 0.85,
    this.popping = false,
    this.popProgress = 0.0,
  });
}

class _BubblePopGameState extends State<BubblePopGame> with TickerProviderStateMixin {
  late AnimationController _ticker;
  final List<_Bubble> _bubbles = [];
  final Random _rng = Random();
  int _popped = 0;
  Timer? _spawnTimer;
  Size _size = Size.zero;

  static const List<Color> _calmColors = [
    Color(0xFFB794F4), Color(0xFF76E4F7), Color(0xFF68D391),
    Color(0xFF63B3ED), Color(0xFFF6AD55), Color(0xFFFC8181),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(hours: 1))
      ..addListener(_tick)
      ..forward();
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _spawnBubble());
    // Spawn initial bubbles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _size = MediaQuery.sizeOf(context);
      for (int i = 0; i < 8; i++) {
        Future.delayed(Duration(milliseconds: i * 200), _spawnBubble);
      }
    });
  }

  void _spawnBubble() {
    if (!mounted || _bubbles.length >= 18) return;
    final s = _size;
    if (s == Size.zero) return;
    setState(() {
      _bubbles.add(_Bubble(
        position: Offset(
          20 + _rng.nextDouble() * (s.width - 40),
          s.height + 40,
        ),
        radius: 26 + _rng.nextDouble() * 30,
        color: _calmColors[_rng.nextInt(_calmColors.length)],
        speed: 0.6 + _rng.nextDouble() * 0.9,
      ));
    });
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      final s = _size;
      _bubbles.removeWhere((b) {
        if (b.popping) {
          b.popProgress += 0.08;
          b.opacity = (1.0 - b.popProgress).clamp(0, 1);
          return b.popProgress >= 1.0;
        }
        b.position = Offset(b.position.dx + sin(b.position.dy * 0.02) * 0.5, b.position.dy - b.speed);
        return s != Size.zero && b.position.dy < -60;
      });
    });
  }

  void _onTap(TapDownDetails details) {
    final tapPos = details.localPosition;
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final b = _bubbles[i];
      if (b.popping) continue;
      final dist = (b.position - tapPos).distance;
      if (dist <= b.radius + 10) {
        setState(() {
          b.popping = true;
          _popped++;
        });
        HapticService.rhythmicBuzz(duration: 60);
        break;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF030510),
      body: GestureDetector(
        onTapDown: _onTap,
        child: Stack(children: [
          // Bubble canvas
          CustomPaint(
            painter: _BubblePainter(bubbles: List.from(_bubbles)),
            size: _size,
          ),
          // UI
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white54, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('🫧 Bubble Pop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  Text('$_popped popped', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace')),
                ]),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB794F4).withValues(alpha: 0.2)),
                ),
                child: const Text('Tap the bubbles 🫧 No rules. Just pop.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFFB794F4))),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  if (_popped >= 20) ...[
                    const Text('✨', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 6),
                    const Text('That felt good, right?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF68D391))),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB794F4), foregroundColor: Colors.black),
                      child: const Text('Back to Dashboard'),
                    )),
                  ] else ...[
                    Text('Feeling lighter? Keep going… ($_popped sensory resets)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  _BubblePainter({required this.bubbles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      if (b.popping) {
        // Pop burst — expanding ring + fading
        final scale = 1.0 + b.popProgress * 0.8;
        final paint = Paint()
          ..color = b.color.withValues(alpha: b.opacity * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * b.popProgress);
        canvas.drawCircle(b.position, b.radius * scale, paint);
        // Sparkle mini circles
        final sparklePaint = Paint()..color = b.color.withValues(alpha: b.opacity * 0.8);
        for (int i = 0; i < 6; i++) {
          final angle = i * 3.14159 / 3;
          final offset = Offset(
            b.position.dx + cos(angle) * b.radius * 1.5 * b.popProgress,
            b.position.dy + sin(angle) * b.radius * 1.5 * b.popProgress,
          );
          canvas.drawCircle(offset, 4 * (1 - b.popProgress), sparklePaint);
        }
      } else {
        // Normal bubble — outer glow
        canvas.drawCircle(b.position, b.radius, Paint()
          ..color = b.color.withValues(alpha: b.opacity * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
        // Bubble ring
        canvas.drawCircle(b.position, b.radius, Paint()
          ..color = b.color.withValues(alpha: b.opacity * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        // Inner fill
        canvas.drawCircle(b.position, b.radius * 0.85, Paint()
          ..color = b.color.withValues(alpha: b.opacity * 0.07));
        // Shine
        canvas.drawCircle(
          Offset(b.position.dx - b.radius * 0.3, b.position.dy - b.radius * 0.35),
          b.radius * 0.18,
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) => true;
}
