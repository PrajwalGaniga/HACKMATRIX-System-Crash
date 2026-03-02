import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/intervention_model.dart';
import '../services/haptic_service.dart';
import 'intervention_hub.dart';
import 'game_bubble_wrap.dart';
import 'game_breathing.dart';
import 'game_mindful_puzzle.dart';
import 'game_coloring.dart';
import 'game_idle_garden.dart';

/// Full-screen high-priority warning overlay.
/// Displays Gemini's context-aware message and a "Take a 60s Break" CTA
/// with dynamic game chips (from game_options in the intervention payload).
class TiltWarningScreen extends StatefulWidget {
  final InterventionModel model;

  const TiltWarningScreen({super.key, required this.model});

  @override
  State<TiltWarningScreen> createState() => _TiltWarningScreenState();
}

class _TiltWarningScreenState extends State<TiltWarningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  String? _selectedGame;
  int _countdown = 3;
  Timer? _autoLaunchTimer;

  @override
  void initState() {
    super.initState();
    HapticService.heartbeat();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();

    // ── 3-second auto-launch countdown ────────────────────
    _autoLaunchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        // Auto-launch primary game from options, default BUBBLE_WRAP
        final gameToLaunch = widget.model.gameOptions.isNotEmpty
            ? widget.model.gameOptions.first
            : 'BUBBLE_WRAP';
        _launchGame(gameToLaunch);
      }
    });
  }

  @override
  void dispose() {
    _autoLaunchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _launchGame(String gameId) {
    HapticService.successTap();
    final route = _routeForGame(gameId);
    if (route != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => route),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => InterventionHub(intervention: widget.model)),
      );
    }
  }

  void _goToHub() {
    HapticService.successTap();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => InterventionHub(intervention: widget.model)),
    );
  }

  Widget? _routeForGame(String gameId) {
    switch (gameId.toUpperCase()) {
      case 'BUBBLE_WRAP':        return const BubbleWrapGame();
      case 'BREATHING_TRAINER':  return const BreathingTrainerGame();
      case 'MINDFUL_PUZZLE':     return const MindfulPuzzleGame();
      case 'RELAXING_COLORING':  return const RelaxingColoringGame();
      case 'IDLE_GARDEN':        return const IdleGardenGame();
      default: return null;
    }
  }

  String _gameDisplayName(String id) {
    const names = {
      'BUBBLE_WRAP': '🫧 Bubble Wrap',
      'BREATHING_TRAINER': '🌬️ Breathing',
      'MINDFUL_PUZZLE': '🧩 Puzzle',
      'RELAXING_COLORING': '🎨 Coloring',
      'IDLE_GARDEN': '🌿 Garden',
    };
    return names[id.toUpperCase()] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final isGaming = model.activeApp.toLowerCase().contains('pubg') ||
        model.activeApp.toLowerCase().contains('game');

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9).withValues(alpha: 0.95),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideUp,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color(0xFFF0FDF4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Text(model.toastEmoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aegis.ai Alert',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF4ADE80),
                                    letterSpacing: 2,
                                  ),
                                ),
                                Text(
                                  isGaming ? 'Tilt Detected — Deep Breath' : 'Stress Detected — Need a Break?',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E1E1E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Close (dismiss only)
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, color: Colors.black38, size: 24),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),

                      // Gemini message
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '"${model.toastMsg}"',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Breathing tip
                      if (model.breathingTip.isNotEmpty)
                        Text(
                          '💨 ${model.breathingTip}',
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.blueGrey[600], fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),

                      const SizedBox(height: 24),

                      // Game options chips
                      if (model.gameOptions.isNotEmpty) ...[
                        Text(
                          'Choose your break:',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.blueGrey[600], fontWeight: FontWeight.w600, letterSpacing: 1),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: model.gameOptions.map((gId) {
                            final selected = _selectedGame == gId;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedGame = gId),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF4ADE80).withValues(alpha: 0.2)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected ? const Color(0xFF4ADE80) : Colors.black12,
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  _gameDisplayName(gId),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: selected ? const Color(0xFF1E1E1E) : Colors.blueGrey[600],
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Primary CTA Button with countdown
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _autoLaunchTimer?.cancel();
                            _selectedGame != null
                                ? _launchGame(_selectedGame!)
                                : _launchGame(widget.model.gameOptions.isNotEmpty
                                    ? widget.model.gameOptions.first
                                    : 'BUBBLE_WRAP');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4ADE80),
                            foregroundColor: const Color(0xFF1E1E1E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _selectedGame != null
                                    ? 'Play ${_gameDisplayName(_selectedGame!)} Now'
                                    : widget.model.ctaLabel,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black38, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '$_countdown',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E1E1E)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'I\'m fine, dismiss',
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
