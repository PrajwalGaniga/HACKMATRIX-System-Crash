import 'dart:math';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../widgets/game_countdown.dart';

/// BubbleWrap — Grid of tappable bubble cells.
/// Endlessly regenerating. No timer, no score, pure tactile satisfaction.
class BubbleWrapGame extends StatefulWidget {
  const BubbleWrapGame({super.key});
  @override
  State<BubbleWrapGame> createState() => _BubbleWrapGameState();
}

class _BubbleWrapGameState extends State<BubbleWrapGame> {
  static const int _cols = 6;
  static const int _rows = 10;
  late List<List<bool>> _popped;
  int _popCount = 0;
  final Random _rng = Random();

  static const List<Color> _bubbleColors = [
    Color(0xFF63B3ED), Color(0xFFB794F4), Color(0xFF68D391),
    Color(0xFF76E4F7), Color(0xFFF6AD55), Color(0xFFFC8181),
  ];
  late List<List<Color>> _colors;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _popped = List.generate(_rows, (_) => List.filled(_cols, false));
    _colors = List.generate(_rows, (_) =>
      List.generate(_cols, (_) => _bubbleColors[_rng.nextInt(_bubbleColors.length)])
    );
  }

  void _pop(int r, int c) {
    if (_popped[r][c]) return;
    setState(() {
      _popped[r][c] = true;
      _popCount++;
    });
    HapticService.rhythmicBuzz(duration: 40);
    // Check if whole sheet is popped — refill with delay
    if (_popped.every((row) => row.every((v) => v))) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(_reset);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: GameCountdown(
        gameName: 'bubble_wrap',
        child: SafeArea(
          child: Column(children: [
            _Header(title: '🫧 Bubble Wrap', subtitle: 'Pop every bubble · Peace awaits', popCount: _popCount),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _cols,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _rows * _cols,
                  itemBuilder: (_, i) {
                    final r = i ~/ _cols; final c = i % _cols;
                    return _BubbleCell(
                      color: _colors[r][c],
                      popped: _popped[r][c],
                      onTap: () => _pop(r, c),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class _BubbleCell extends StatefulWidget {
  final Color color;
  final bool popped;
  final VoidCallback onTap;
  const _BubbleCell({required this.color, required this.popped, required this.onTap});
  @override
  State<_BubbleCell> createState() => _BubbleCellState();
}

class _BubbleCellState extends State<_BubbleCell> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_BubbleCell old) {
    super.didUpdateWidget(old);
    if (widget.popped && !old.popped) _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.popped ? null : widget.onTap,
    child: ScaleTransition(
      scale: _scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.popped ? Colors.white.withValues(alpha: 0.03) : widget.color.withValues(alpha: 0.25),
          border: Border.all(
            color: widget.popped ? Colors.white.withValues(alpha: 0.06) : widget.color.withValues(alpha: 0.7),
            width: widget.popped ? 1 : 2,
          ),
          boxShadow: widget.popped ? [] : [
            BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: widget.popped ? null : Center(
          child: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final String title, subtitle;
  final int popCount;
  const _Header({required this.title, required this.subtitle, required this.popCount});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white54, size: 16)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFB794F4).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
        child: Text('$popCount pops', style: const TextStyle(fontSize: 10, color: Color(0xFFB794F4), fontFamily: 'monospace')),
      ),
    ]),
  );
}
