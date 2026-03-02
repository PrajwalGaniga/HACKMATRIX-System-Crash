import 'dart:math';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../widgets/game_countdown.dart';

/// BreathingTrainer — guided 4-4-4 box breathing with animated circle + haptic sync.
class BreathingTrainerGame extends StatefulWidget {
  const BreathingTrainerGame({super.key});
  @override
  State<BreathingTrainerGame> createState() => _BreathingTrainerGameState();
}

enum _Phase { inhale, hold, exhale, rest }

class _BreathingTrainerGameState extends State<BreathingTrainerGame> with TickerProviderStateMixin {
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;
  late AnimationController _glowCtrl;
  _Phase _phase = _Phase.inhale;
  int _cycles = 0;
  static const _phaseDurations = {
    _Phase.inhale: 4000,
    _Phase.hold: 4000,
    _Phase.exhale: 4000,
    _Phase.rest: 1000,
  };
  static const _phaseLabels = {
    _Phase.inhale: 'Breathe In',
    _Phase.hold: 'Hold',
    _Phase.exhale: 'Breathe Out',
    _Phase.rest: 'Rest',
  };

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _breathCtrl = AnimationController(vsync: this, duration: Duration(milliseconds: _phaseDurations[_Phase.inhale]!))
      ..addStatusListener(_onPhaseEnd);
    _breathAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));
    _startPhase(_Phase.inhale);
  }

  void _startPhase(_Phase phase) {
    _phase = phase;
    final dur = Duration(milliseconds: _phaseDurations[phase]!);
    _breathCtrl.duration = dur;
    if (phase == _Phase.inhale) {
      _breathAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));
      _breathCtrl.forward(from: 0);
      HapticService.rhythmicBuzz(duration: 100);
    } else if (phase == _Phase.hold) {
      _breathCtrl.stop();
      Future.delayed(dur, () { if (mounted) _startPhase(_Phase.exhale); });
    } else if (phase == _Phase.exhale) {
      _breathAnim = Tween<double>(begin: 1.0, end: 0.4).animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));
      _breathCtrl.forward(from: 0);
    } else {
      Future.delayed(dur, () { if (mounted) { setState(() => _cycles++); _startPhase(_Phase.inhale); } });
    }
    if (mounted) setState(() {});
  }

  void _onPhaseEnd(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_phase == _Phase.inhale) _startPhase(_Phase.hold);
      else if (_phase == _Phase.exhale) _startPhase(_Phase.rest);
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Color get _phaseColor {
    switch (_phase) {
      case _Phase.inhale: return const Color(0xFF63B3ED);
      case _Phase.hold: return const Color(0xFFB794F4);
      case _Phase.exhale: return const Color(0xFF68D391);
      case _Phase.rest: return Colors.white30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxR = size.width * 0.38;
    return Scaffold(
      backgroundColor: const Color(0xFF030510),
      body: GameCountdown(
        gameName: 'breathing_trainer',
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
                const Text('💨 Breathing Trainer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Text('$_cycles cycles', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace')),
              ]),
            ),
            const Spacer(),

            // Animated breathing circle
            AnimatedBuilder(
              animation: Listenable.merge([_breathAnim, _glowCtrl]),
              builder: (_, __) {
                final r = maxR * _breathAnim.value;
                return SizedBox(
                  width: maxR * 2 + 60,
                  height: maxR * 2 + 60,
                  child: Center(
                    child: Stack(alignment: Alignment.center, children: [
                      // Outer glow
                      Container(
                        width: r * 2 + 40 + _glowCtrl.value * 20,
                        height: r * 2 + 40 + _glowCtrl.value * 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _phaseColor.withValues(alpha: 0.06 + _glowCtrl.value * 0.04),
                        ),
                      ),
                      // Main circle
                      Container(
                        width: r * 2,
                        height: r * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _phaseColor.withValues(alpha: 0.12),
                          border: Border.all(color: _phaseColor.withValues(alpha: 0.6), width: 2.5),
                        ),
                        child: Center(
                          child: Text(
                            _phaseLabels[_phase]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _phaseColor),
                          ),
                        ),
                      ),
                      // Phase dots around circle
                      ...List.generate(4, (i) {
                        final angle = (i * pi / 2) - pi / 2;
                        final dx = (r + 20) * cos(angle);
                        final dy = (r + 20) * sin(angle);
                        final phases = [_Phase.inhale, _Phase.hold, _Phase.exhale, _Phase.rest];
                        final active = phases[i] == _phase;
                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Container(
                            width: active ? 10 : 6, height: active ? 10 : 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active ? _phaseColor : Colors.white24,
                            ),
                          ),
                        );
                      }),
                    ]),
                  ),
                );
              },
            ),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('4 · 4 · 4  Box Breathing\nFollow the circle. Let Aegis guide your breath.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.6)),
            ),
          ]),
        ),
      ),
    );
  }
}
