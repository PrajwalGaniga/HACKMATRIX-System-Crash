import 'dart:math';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../widgets/game_countdown.dart';

/// Relaxing Coloring Canvas — Minimalist mandala coloring game.
class RelaxingColoringGame extends StatefulWidget {
  const RelaxingColoringGame({super.key});
  @override
  State<RelaxingColoringGame> createState() => _RelaxingColoringGameState();
}

class _RelaxingColoringGameState extends State<RelaxingColoringGame> {
  // Mandala structure: 5 concentric rings, 12 slices per ring = 60 regions
  static const int _rings = 5;
  static const int _slices = 12;

  // Stores color for each region: colors[ring][slice]
  late List<List<Color?>> _colors;

  // Palette
  static const List<Color> _palette = [
    Color(0xFFFC8181), Color(0xFFF6AD55), Color(0xFFF6E05E),
    Color(0xFF68D391), Color(0xFF4FD1C5), Color(0xFF63B3ED),
    Color(0xFFB794F4), Color(0xFFED64A6), Colors.white,
  ];

  Color _activeColor = _palette[5]; // Default blue
  int _painted = 0;

  @override
  void initState() {
    super.initState();
    _colors = List.generate(_rings, (_) => List.filled(_slices, null));
  }

  void _onCanvasTap(TapDownDetails details, Size size) {
    // Canvas center
    final center = Offset(size.width / 2, size.height / 2);
    final pos = details.localPosition;
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;

    // Polar coordinates
    final distance = sqrt(dx * dx + dy * dy);
    var angle = atan2(dy, dx); // -pi to pi
    if (angle < 0) angle += 2 * pi; // 0 to 2pi

    // Max radius for the mandala is width * 0.45
    final maxR = size.width * 0.45;
    final ringWidth = maxR / _rings;

    // Find which ring
    if (distance > maxR) return; // outside mandala
    final ringIdx = (distance / ringWidth).floor().clamp(0, _rings - 1);

    // Find which slice (0 to 11)
    final sliceAngle = (2 * pi) / _slices;
    final sliceIdx = (angle / sliceAngle).floor().clamp(0, _slices - 1);

    if (_colors[ringIdx][sliceIdx] != _activeColor) {
      setState(() {
        if (_colors[ringIdx][sliceIdx] == null) _painted++;
        _colors[ringIdx][sliceIdx] = _activeColor;
      });
      HapticService.rhythmicBuzz(duration: 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030510),
      body: GameCountdown(
        gameName: 'relaxing_coloring',
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
                const Text('🎨 Relaxing Coloring', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Text('$_painted painted', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace')),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Tap a color, then tap the mandala', style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),

            const Spacer(),

            // Canvas
            LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxWidth);
                return GestureDetector(
                  onTapDown: (d) => _onCanvasTap(d, size),
                  child: CustomPaint(
                    size: size,
                    painter: _MandalaPainter(colors: _colors, rings: _rings, slices: _slices),
                  ),
                );
              }
            ),

            const Spacer(),

            // Palette
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Wrap(
                spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                children: _palette.map((color) {
                  final active = color == _activeColor;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _activeColor = color);
                      HapticService.successTap();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: active ? 36 : 28,
                      height: active ? 36 : 28,
                      decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: active ? 3 : 0),
                        boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)] : [],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  final List<List<Color?>> colors;
  final int rings;
  final int slices;
  _MandalaPainter({required this.colors, required this.rings, required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.45;
    final ringW = maxR / rings;
    final sliceAngle = (2 * pi) / slices;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw slices (filled)
    for (int r = 0; r < rings; r++) {
      final innerR = r * ringW;
      final outerR = (r + 1) * ringW;
      for (int s = 0; s < slices; s++) {
        final startAngle = s * sliceAngle;
        
        final path = Path();
        path.arcTo(Rect.fromCircle(center: center, radius: innerR), startAngle, sliceAngle, false);
        path.arcTo(Rect.fromCircle(center: center, radius: outerR), startAngle + sliceAngle, -sliceAngle, false);
        path.close();

        final c = colors[r][s];
        if (c != null) {
          canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.7)..style = PaintingStyle.fill);
        }
        // Draw outline
        canvas.drawPath(path, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_MandalaPainter old) => true;
}
