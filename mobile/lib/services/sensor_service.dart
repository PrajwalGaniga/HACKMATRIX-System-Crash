import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

import '../models/intervention_model.dart';
import 'haptic_service.dart';

class SensorService extends ChangeNotifier {
  static const double pacingThreshold = 3.5; // Trigger MAD
  static const int pacingDurationSeconds = 15;
  
  StreamSubscription? _accelSub;
  
  // Pacing detection buffer
  final List<double> _magnitudes = [];
  int _pacingActiveTicks = 0; // 1 tick = ~100ms
  
  // Drop detection state
  bool _isFreeFalling = false;
  
  bool _monitoring = false;
  bool get isMonitoring => _monitoring;

  /// Triggered when the sensor detects continuous high-stress pacing
  Function(InterventionModel)? onPacingDetected;

  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    _pacingActiveTicks = 0;
    _magnitudes.clear();

    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      // 1. Calculate magnitude
      double mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // 2. Drop Detection Logic (SOS)
      if (mag < 2.0) {
        // Near 0 Gs -> Freefall
        _isFreeFalling = true;
      } else if (_isFreeFalling && mag > 25.0) {
        // High impact after freefall
        _isFreeFalling = false;
        _triggerGuardianSOS();
      } else if (mag > 8.0 && mag < 12.0) {
        // Normal gravity range, reset freefall
        _isFreeFalling = false;
      }

      // 3. Pacing/Agitation Logic (MAD over 1 second window)
      _magnitudes.add(mag);
      if (_magnitudes.length > 10) { // ~1 second window at 10Hz
        _magnitudes.removeAt(0);
        
        double mean = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
        double mad = _magnitudes.map((m) => (m - mean).abs()).reduce((a, b) => a + b) / _magnitudes.length;
        
        if (mad > pacingThreshold) {
          _pacingActiveTicks++;
          if (_pacingActiveTicks >= pacingDurationSeconds * 10) { // 15 seconds
            _triggerPacingIntervention();
            _pacingActiveTicks = 0; // Cooldown
          }
        } else {
          // Decay the pacing ticks slowly if they stop
          if (_pacingActiveTicks > 0) _pacingActiveTicks--;
        }
      }
    });
    notifyListeners();
  }

  void stopMonitoring() {
    _accelSub?.cancel();
    _monitoring = false;
    notifyListeners();
  }

  void _triggerPacingIntervention() {
    debugPrint("🚨 HIGH PACING DETECTED BY SENSOR HUB");
    HapticService.heartbeat();
    
    final model = InterventionModel(
      stressLevel: 'HIGH',
      action: 'INTERVENE',
      confidence: 0.98,
      reasoning: 'Continuous high-energy pacing detected via accelerometer.',
      toastMsg: 'You seem agitated. Let\'s clear that stress physically.',
      toastEmoji: '💥',
      breathingTip: 'Breathe to the rhythm of the haptics.',
      restReminder: 'Stop walking and ground your feet.',
      activeApp: 'Mobile Sensor Hub',
      triggerCall: false,
      gameId: 'GRAVITY_DUST',
      gameOptions: ['GRAVITY_DUST', 'BUBBLE_WRAP'],
      ctaLabel: 'Shake to Clear Stress',
      timestamp: DateTime.now(),
    );
    
    onPacingDetected?.call(model);
  }

  Future<void> _triggerGuardianSOS() async {
    debugPrint("🚨 DROP DETECTED - CALLING GUARDIAN SOS");
    HapticService.rhythmicBuzz(duration: 1000); // Long warning buzz
    
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: '+919110687983',
    );
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint("Could not dial SOS number.");
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }
}
