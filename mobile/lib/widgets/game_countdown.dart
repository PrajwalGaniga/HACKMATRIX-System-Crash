import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/socket_service.dart';

/// Shared 60-second countdown widget used by all games.
/// Shows a progress ring + "Returning to Aegis" message.
/// Calls the /api/recovery-event endpoint on completion.
class GameCountdown extends StatefulWidget {
  final Widget child;
  final String gameName;
  final VoidCallback? onComplete;
  const GameCountdown({
    super.key,
    required this.child,
    required this.gameName,
    this.onComplete,
  });
  @override
  State<GameCountdown> createState() => _GameCountdownState();
}

class _GameCountdownState extends State<GameCountdown> {
  static const int _totalSeconds = 60;
  int _remaining = _totalSeconds;
  Timer? _timer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0 && !_completed) {
        _completed = true;
        t.cancel();
        _saveAndReturn();
      }
    });
  }

  Future<void> _saveAndReturn() async {
    try {
      await http.post(
        Uri.parse('${SocketService.backendUrl}/api/recovery-event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'game': widget.gameName, 'user': 'Prajwal', 'duration': 60}),
      );
    } catch (_) {}
    if (mounted) {
      widget.onComplete?.call();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / _totalSeconds;
    return Stack(children: [
      widget.child,
      // Countdown pill — top right
      Positioned(
        top: MediaQuery.paddingOf(context).top + 60,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _timerColor(progress).withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.5,
                backgroundColor: Colors.white12,
                color: _timerColor(progress),
              ),
            ),
            const SizedBox(width: 7),
            Text('${_remaining}s', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: _timerColor(progress), fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);
  }

  Color _timerColor(double p) {
    if (p > 0.5) return const Color(0xFF68D391);
    if (p > 0.25) return const Color(0xFFF6AD55);
    return Colors.redAccent;
  }
}
