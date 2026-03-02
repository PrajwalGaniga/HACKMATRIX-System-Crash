import 'dart:math';
import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../widgets/game_countdown.dart';

/// MindfulPuzzle — 4×4 color gradient tile sorting.
/// Tiles are randomly shuffled; user swaps adjacent tiles to restore the gradient.
/// No timer pressure, no score — just gentle focus.
class MindfulPuzzleGame extends StatefulWidget {
  const MindfulPuzzleGame({super.key});
  @override
  State<MindfulPuzzleGame> createState() => _MindfulPuzzleGameState();
}

class _MindfulPuzzleGameState extends State<MindfulPuzzleGame> {
  static const int _n = 4;
  late List<Color> _tiles;
  late List<Color> _solution;
  int? _selected;
  int _swaps = 0;
  bool _solved = false;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _generatePuzzle();
  }

  void _generatePuzzle() {
    // Create a smooth gradient from top-left (blue) to bottom-right (amber)
    final topLeft = const Color(0xFF63B3ED);
    final topRight = const Color(0xFFB794F4);
    final bottomLeft = const Color(0xFF68D391);
    final bottomRight = const Color(0xFFF6AD55);

    _solution = List.generate(_n * _n, (i) {
      final r = i ~/ _n; final c = i % _n;
      final tx = c / (_n - 1); final ty = r / (_n - 1);
      return Color.lerp(
        Color.lerp(topLeft, topRight, tx)!,
        Color.lerp(bottomLeft, bottomRight, tx)!,
        ty,
      )!;
    });

    _tiles = List.from(_solution);
    // Shuffle — do random swaps to ensure solvability
    for (int i = 0; i < 20; i++) {
      final a = _rng.nextInt(_n * _n);
      final b = _rng.nextInt(_n * _n);
      final tmp = _tiles[a]; _tiles[a] = _tiles[b]; _tiles[b] = tmp;
    }
    _solved = false;
    _selected = null;
    _swaps = 0;
  }

  void _onTap(int idx) {
    if (_solved) return;
    if (_selected == null) {
      setState(() => _selected = idx);
    } else {
      final a = _selected!;
      setState(() {
        final tmp = _tiles[a]; _tiles[a] = _tiles[idx]; _tiles[idx] = tmp;
        _selected = null;
        _swaps++;
      });
      HapticService.rhythmicBuzz(duration: 30);
      // Check solved
      if (_tilesMatch()) {
        setState(() => _solved = true);
        HapticService.successTap();
      }
    }
  }

  bool _tilesMatch() {
    for (int i = 0; i < _tiles.length; i++) {
      if ((_tiles[i].value - _solution[i].value).abs() > 2) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: GameCountdown(
        gameName: 'mindful_puzzle',
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
                const Text('🎨 Mindful Puzzle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                Text('$_swaps swaps', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace')),
              ]),
            ),

            if (_solved) ...[
              const Spacer(),
              const Text('✨', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text('Perfect.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF68D391))),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => setState(_generatePuzzle),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF63B3ED), foregroundColor: Colors.black),
                child: const Text('New Puzzle'),
              ),
              const Spacer(),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                _selected == null ? 'Tap a tile to select it, then tap another to swap' : '✓ Selected — tap another tile to swap',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _selected == null ? Colors.grey[600] : const Color(0xFFB794F4)),
              ),
              const SizedBox(height: 16),

              // Puzzle grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _n, crossAxisSpacing: 5, mainAxisSpacing: 5,
                    ),
                    itemCount: _n * _n,
                    itemBuilder: (_, i) {
                      final isSelected = _selected == i;
                      return GestureDetector(
                        onTap: () => _onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _tiles[i],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: isSelected ? 3 : 0,
                            ),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 12)] : [],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Solution preview (small)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Text('Goal:', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 20,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _n, crossAxisSpacing: 2, mainAxisSpacing: 2),
                        itemCount: _n * _n,
                        itemBuilder: (_, i) => Container(
                          decoration: BoxDecoration(color: _solution[i], borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
