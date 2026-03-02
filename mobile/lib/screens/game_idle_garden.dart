import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../widgets/game_countdown.dart';

/// IdleGarden — Tap to plant seeds and grow a calming garden.
/// No failures, no speed, just gentle growth and visual comfort.
class IdleGardenGame extends StatefulWidget {
  const IdleGardenGame({super.key});
  @override
  State<IdleGardenGame> createState() => _IdleGardenGameState();
}

class _Plant {
  final Offset position;
  double growth; // 0.0 to 1.0
  final String emoji;
  final Color color;
  _Plant({required this.position, required this.emoji, required this.color, this.growth = 0.0});
}

class _IdleGardenGameState extends State<IdleGardenGame> with TickerProviderStateMixin {
  final List<_Plant> _plants = [];
  final Random _rng = Random();
  late AnimationController _growCtrl;
  Timer? _growTimer;
  int _taps = 0;

  static const _plantOptions = [
    ('🌸', Color(0xFFFC8181)), ('🌿', Color(0xFF68D391)), ('🌻', Color(0xFFF6AD55)),
    ('🌺', Color(0xFFB794F4)), ('🌵', Color(0xFF68D391)), ('🍀', Color(0xFF63B3ED)),
    ('🌷', Color(0xFFFC8181)), ('🌼', Color(0xFFF6AD55)),
  ];

  @override
  void initState() {
    super.initState();
    _growCtrl = AnimationController(vsync: this, duration: const Duration(hours: 1))..addListener(_growTick)..forward();
    _growTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      setState(() {
        for (final p in _plants) {
          p.growth = (p.growth + 0.015).clamp(0, 1);
        }
      });
    });
  }

  void _growTick() { if (mounted) setState(() {}); }

  void _plantSeed(TapDownDetails d) {
    if (_plants.length >= 20) return;
    final p = _plantOptions[_rng.nextInt(_plantOptions.length)];
    setState(() {
      _plants.add(_Plant(position: d.localPosition, emoji: p.$1, color: p.$2));
      _taps++;
    });
    HapticService.rhythmicBuzz(duration: 50);
  }

  @override
  void dispose() {
    _growCtrl.dispose();
    _growTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030E06),
      body: GameCountdown(
        gameName: 'idle_garden',
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white54, size: 16)),
                ),
                const SizedBox(width: 10),
                const Text('🌿 Idle Garden', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Text('$_taps planted', style: TextStyle(fontSize: 10, color: const Color(0xFF68D391), fontFamily: 'monospace')),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Tap anywhere to plant a seed 🌱', style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 4),

            // Garden canvas
            Expanded(
              child: GestureDetector(
                onTapDown: _plantSeed,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF030E06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF68D391).withValues(alpha: 0.15)),
                  ),
                  child: CustomPaint(
                    painter: _GardenPainter(plants: List.from(_plants)),
                    child: Container(),
                  ),
                ),
              ),
            ),

            // Hint when garden full
            if (_plants.length >= 20)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Garden is full 🌸 Beautiful!', style: TextStyle(fontSize: 12, color: const Color(0xFF68D391))),
              ),
          ]),
        ),
      ),
    );
  }
}

class _GardenPainter extends CustomPainter {
  final List<_Plant> plants;
  _GardenPainter({required this.plants});

  @override
  void paint(Canvas canvas, Size size) {
    // Ground line
    final groundY = size.height * 0.82;
    canvas.drawLine(
      Offset(0, groundY), Offset(size.width, groundY),
      Paint()..color = const Color(0xFF68D391).withValues(alpha: 0.15)..strokeWidth = 1.5,
    );

    for (final p in plants) {
      final cx = p.position.dx.clamp(20.0, size.width - 20);
      final cy = groundY;
      final stemH = 50 * p.growth;
      final emojiSize = 24.0 * p.growth;

      // Stem
      if (stemH > 2) {
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx, cy - stemH),
          Paint()..color = const Color(0xFF68D391).withValues(alpha: 0.6 * p.growth)..strokeWidth = 2,
        );
      }

      // Emoji flower (drawn as text)
      if (p.growth > 0.3 && emojiSize > 4) {
        final tp = TextPainter(
          text: TextSpan(text: p.emoji, style: TextStyle(fontSize: emojiSize)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy - stemH - tp.height));
      }

      // Glow under flower
      if (p.growth > 0.5) {
        canvas.drawCircle(
          Offset(cx, cy - stemH),
          8 * p.growth,
          Paint()..color = p.color.withValues(alpha: 0.15 * p.growth)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GardenPainter old) => true;
}
