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
      backgroundColor: const Color(0xFFF0FDF4),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFE8F5E9), Color(0xFFF0FDF4)],
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
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                        SizedBox(width: 5),
                        Text('TILT DETECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 1)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.black38, size: 24), onPressed: () { _launchTimer?.cancel(); Navigator.pop(context); }),
                ]),
              ),

              const SizedBox(height: 16),
              Text(i.toastEmoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 10),
              const Text('Aegis is here for you.', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1E1E1E))),
              const SizedBox(height: 8),
              if (i.toastMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(i.toastMsg, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4, fontWeight: FontWeight.w500)),
                ),
              const SizedBox(height: 16),

              // Breathing + rest
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
                  child: Column(children: [
                    Text('💨 ${i.breathingTip.isNotEmpty ? i.breathingTip : "Breathe in 4s · Hold 4s · Out 4s"}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                    if (i.restReminder.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('🌿 ${i.restReminder}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
              ),
              if (i.triggerCall) Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.withValues(alpha: 0.3))),
                  child: const Text('📞 Calling +91 9110 687 983 via Twilio', style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                ),
              ),

              const Spacer(),

              // Auto-launch banner
              if (i.gameId != null && i.gameId!.isNotEmpty && _countdown > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selectedGame.color.withValues(alpha: 0.4), width: 1.5),
                      boxShadow: [BoxShadow(color: selectedGame.color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(children: [
                      Text(selectedGame.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('🧠 Gemini chose ${selectedGame.title}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text(selectedGame.subtitle, style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
                      ])),
                      GestureDetector(
                        onTap: () { _launchTimer?.cancel(); _launchGame(i.gameId!); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: selectedGame.color, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                          child: Text('$_countdown  ▶', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ),
                ),

              const SizedBox(height: 12),

              // All games horizontal scroll
              SizedBox(
                height: 110,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _games.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, idx) {
                    final g = _games[idx];
                    return GestureDetector(
                      onTap: () => _launchGame(g.id),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: g.id == i.gameId ? g.color : Colors.black12, width: g.id == i.gameId ? 2 : 1),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(g.emoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 6),
                          Text(g.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]), maxLines: 1, overflow: TextOverflow.ellipsis),
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
