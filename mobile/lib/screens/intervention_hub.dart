import 'dart:async';
import 'package:flutter/material.dart';
import '../models/intervention_model.dart';
import '../services/haptic_service.dart';
import 'game_bubble_wrap.dart';
import 'game_coloring.dart';
import 'game_breathing.dart';
import 'game_mindful_puzzle.dart';
import 'game_idle_garden.dart';

/// Master list of the 5 targetless games
class _GameInfo {
  final String id, emoji, title, subtitle;
  final Color color;
  final Widget Function() builder;
  const _GameInfo({required this.id, required this.emoji, required this.title, required this.subtitle, required this.color, required this.builder});
}

const _games = [
  _GameInfo(id: 'BUBBLE_WRAP',       emoji: '🫧', title: 'Bubble Wrap',      subtitle: 'Pop the grid • Reset senses',       color: Color(0xFF76E4F7), builder: BubbleWrapGame.new),
  _GameInfo(id: 'RELAXING_COLORING', emoji: '🎨', title: 'Coloring',         subtitle: 'Fill the mandala • Art therapy',    color: Color(0xFFF6AD55), builder: RelaxingColoringGame.new),
  _GameInfo(id: 'BREATHING_TRAINER', emoji: '💨', title: 'Breathing',        subtitle: '4-4-4 Box • Guided circle',         color: Color(0xFF63B3ED), builder: BreathingTrainerGame.new),
  _GameInfo(id: 'MINDFUL_PUZZLE',    emoji: '🧩', title: 'Mindful Puzzle',   subtitle: 'Color tiles • Slow focus',          color: Color(0xFFB794F4), builder: MindfulPuzzleGame.new),
  _GameInfo(id: 'IDLE_GARDEN',       emoji: '🌿', title: 'Idle Garden',      subtitle: 'Tap to plant • Watch it grow',      color: Color(0xFF68D391), builder: IdleGardenGame.new),
];

_GameInfo _findGame(String? id) =>
    _games.firstWhere((g) => g.id == id, orElse: () => _games[0]);

class InterventionHub extends StatefulWidget {
  final InterventionModel intervention;
  const InterventionHub({super.key, required this.intervention});
  @override
  State<InterventionHub> createState() => _InterventionHubState();
}

class _InterventionHubState extends State<InterventionHub> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulseAnim;
  int _countdown = 3;
  Timer? _launchTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    HapticService.loopHeartbeat(times: 3);

    // Auto-launch Gemini-selected game after 3s countdown
    if (widget.intervention.gameId != null && widget.intervention.gameId!.isNotEmpty) {
      _launchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() => _countdown--);
        if (_countdown <= 0) {
          t.cancel();
          _launchGame(widget.intervention.gameId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _launchTimer?.cancel();
    HapticService.cancel();
    super.dispose();
  }

  void _launchGame(String id) {
    _launchTimer?.cancel();
    final info = _findGame(id);
    Navigator.push(context, MaterialPageRoute(builder: (_) => info.builder()));
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.intervention;
    final selectedGame = _findGame(i.gameId);
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3), radius: 1.1,
              colors: [const Color(0xFFFF6B35).withValues(alpha: 0.1), const Color(0xFF080B14), Colors.black],
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(children: [
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 13),
                        SizedBox(width: 5),
                        Text('HIGH TILT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.redAccent, fontFamily: 'monospace')),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white30, size: 20), onPressed: () { _launchTimer?.cancel(); Navigator.pop(context); }),
                ]),
              ),

              const SizedBox(height: 16),
              Text(i.toastEmoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 10),
              const Text('Aegis is standing guard.', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              if (i.toastMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(i.toastMsg, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[400], height: 1.4)),
                ),
              const SizedBox(height: 10),

              // Breathing + rest
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF63B3ED).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF63B3ED).withValues(alpha: 0.2))),
                  child: Column(children: [
                    Text('💨 ${i.breathingTip.isNotEmpty ? i.breathingTip : "Breathe in 4s · Hold 4s · Out 4s"}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF76E4F7))),
                    if (i.restReminder.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('🌿 ${i.restReminder}', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ]),
                ),
              ),
              if (i.triggerCall) Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFF76E4F7).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                  child: const Text('📞 Calling +91 9110 687 983 via Twilio', style: TextStyle(fontSize: 10, color: Color(0xFF76E4F7), fontFamily: 'monospace')),
                ),
              ),

              const Spacer(),

              // Auto-launch banner
              if (i.gameId != null && i.gameId!.isNotEmpty && _countdown > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedGame.color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selectedGame.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Text(selectedGame.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('🧠 Gemini chose ${selectedGame.title}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selectedGame.color)),
                        Text(selectedGame.subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ])),
                      GestureDetector(
                        onTap: () { _launchTimer?.cancel(); _launchGame(i.gameId!); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: selectedGame.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
                          child: Text('$_countdown  ▶', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selectedGame.color, fontFamily: 'monospace')),
                        ),
                      ),
                    ]),
                  ),
                ),

              const SizedBox(height: 12),

              // All games horizontal scroll
              SizedBox(
                height: 90,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _games.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, idx) {
                    final g = _games[idx];
                    return GestureDetector(
                      onTap: () => _launchGame(g.id),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: g.color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: g.color.withValues(alpha: g.id == i.gameId ? 0.6 : 0.25), width: g.id == i.gameId ? 1.5 : 1),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(g.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(g.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: g.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
