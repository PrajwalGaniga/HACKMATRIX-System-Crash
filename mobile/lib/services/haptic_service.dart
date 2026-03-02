import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

/// HapticService — delivers rhythmic heartbeat and hype patterns.
class HapticService {
  static bool _supported = false;

  static Future<void> init() async {
    _supported = (await Vibration.hasVibrator()) ?? false;
    debugPrint('Vibration supported: $_supported');
  }

  /// "Heartbeat" — two-beat pulse that guides breathing during HIGH tilt.
  static Future<void> heartbeat() async {
    if (!_supported) return;
    // Pattern: wait 0ms, buzz 80ms, off 100ms, buzz 120ms, off 800ms
    await Vibration.vibrate(
      pattern: [0, 80, 100, 120, 800, 80, 100, 120],
      intensities: [0, 200, 0, 200, 0, 180, 0, 180],
    );
  }

  /// "Rhythmic Buzz" — continuous haptic for Shake-It-Out game feedback.
  static Future<void> rhythmicBuzz({int duration = 300}) async {
    if (!_supported) return;
    await Vibration.vibrate(duration: duration, amplitude: 180);
  }

  /// Short success tap — used when stress particles clear.
  static Future<void> successTap() async {
    if (!_supported) return;
    await Vibration.vibrate(duration: 60, amplitude: 255);
  }

  /// Cancel any ongoing vibration.
  static Future<void> cancel() async {
    await Vibration.cancel();
  }

  /// Loop heartbeat N times (for ambient breathing guide).
  static Future<void> loopHeartbeat({int times = 5}) async {
    for (int i = 0; i < times; i++) {
      await heartbeat();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}
