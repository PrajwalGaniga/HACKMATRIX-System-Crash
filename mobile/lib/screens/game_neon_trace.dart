import 'dart:math';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

/// NeonTrace — Calming scoreless path-following game.
/// User draws over a glowing path. No speed requirements, no failure state.
/// Pure grounding mechanic — tactile + visual satisfaction.
class NeonTraceGame extends StatefulWidget {
  const NeonTraceGame({super.key});
  @override
  State<NeonTraceGame> createState() => _NeonTraceGameState();
}

class _NeonTraceGameState extends State<NeonTraceGame> with TickerProviderStateMixin {
  late AnimationController _pathAnim;
  late AnimationController _glowController;
  final List<Offset> _userPath = [];
  List<Offset> _targetPath = [];
  bool _hasStarted = false;
  bool _complete = false;
  int _tracePoints = 0;

  @override
  void initState() {
    super.initState();
    _pathAnim = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_targetPath.isEmpty) _generatePath(MediaQuery.sizeOf(context));
  }

  void _generatePath(Size size) {
    // Gentle figure-8 / infinity loop path
    const steps = 80;
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    _targetPath = List.generate(steps, (i) {
      final t = i / steps * 2 * pi;
      final scale = min(size.width, size.height) * 0.3;
      return Offset(
        cx + scale * sin(t),
        cy + scale * sin(t) * cos(t),
      );
    });
  }

  void _onPanStart(DragStartDetails d) {
    if (!_hasStarted) {
      setState(() => _hasStarted = true);
      HapticService.rhythmicBuzz(duration: 50);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _userPath.add(d.localPosition);
      if (_userPath.length > 200) _userPath.removeAt(0);
      _tracePoints++;
      if (_tracePoints > 60 && _tracePoints % 20 == 0) {
        HapticService.rhythmicBuzz(duration: 30);
      }
      if (_tracePoints >= 100 && !_complete) {
        _complete = true;
        HapticService.successTap();
      }
    });
  }

  @override
  void dispose() {
    _pathAnim.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030510),
      body: Stack(children: [
        // Canvas
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pathAnim, _glowController]),
            builder: (_, __) => CustomPaint(
              painter: _NeonPainter(
                targetPath: _targetPath,
                userPath: _userPath,
                glowPulse: _glowController.value,
                pathPhase: _pathAnim.value,
              ),
              size: Size(MediaQuery.sizeOf(context).width, MediaQuery.sizeOf(context).height),
            ),
          ),
        ),

        // UI overlay
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('🌌 Neon Trace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF63B3ED).withOpacity(0.2)),
              ),
              child: Text(
                _complete ? '✨ Beautiful. You are grounded.' : !_hasStarted ? '✋ Touch and trace the glowing path to calm your mind' : '🖐 Keep tracing… breathe slowly…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _complete ? const Color(0xFF68D391) : const Color(0xFF63B3ED)),
              ),
            ),
            const Spacer(),
            if (_complete)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Text('🌟', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  const Text('Grounded.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF68D391))),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF63B3ED), foregroundColor: Colors.black),
                    child: const Text('Back to Dashboard'),
                  )),
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Progress', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    Text('${min(_tracePoints, 100)}%', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF63B3ED))),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_tracePoints / 100).clamp(0, 1),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF63B3ED)),
                      minHeight: 6,
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _NeonPainter extends CustomPainter {
  final List<Offset> targetPath;
  final List<Offset> userPath;
  final double glowPulse;
  final double pathPhase;

  _NeonPainter({required this.targetPath, required this.userPath, required this.glowPulse, required this.pathPhase});

  @override
  void paint(Canvas canvas, Size size) {
    // Target path — pulsing glow
    if (targetPath.length > 1) {
      final glowPaint = Paint()
        ..color = const Color(0xFF63B3ED).withOpacity(0.15 + glowPulse * 0.2)
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

      final linePaint = Paint()
        ..color = const Color(0xFF63B3ED).withOpacity(0.4 + glowPulse * 0.3)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(targetPath[0].dx, targetPath[0].dy);
      for (int i = 1; i < targetPath.length; i++) {
        path.lineTo(targetPath[i].dx, targetPath[i].dy);
      }
      path.close();
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);

      // Moving dot along path
      final idx = ((pathPhase * targetPath.length).toInt()).clamp(0, targetPath.length - 1);
      final dotPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(targetPath[idx], 10 * (0.8 + glowPulse * 0.4), dotPaint);
    }

    // User trace — amber neon
    if (userPath.length > 1) {
      final tracePaint = Paint()
        ..color = const Color(0xFFFFBF00).withOpacity(0.8)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final tracePath = Path()..moveTo(userPath[0].dx, userPath[0].dy);
      for (int i = 1; i < userPath.length; i++) {
        tracePath.lineTo(userPath[i].dx, userPath[i].dy);
      }
      canvas.drawPath(tracePath, tracePaint);
      // Core line
      canvas.drawPath(tracePath, Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_NeonPainter old) => true;
}
