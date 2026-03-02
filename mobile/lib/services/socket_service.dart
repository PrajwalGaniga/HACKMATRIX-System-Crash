import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import '../models/intervention_model.dart';
import 'package:intl/intl.dart';

class SocketService extends ChangeNotifier {
  static const String backendUrl = 'https://dawdlingly-pseudoinsane-pa.ngrok-free.dev';

  io.Socket? _socket;
  bool _connected = false;
  String _activeApp = 'Detecting…';
  InterventionModel? _lastIntervention;
  final List<InterventionModel> _history = [];
  final List<Map<String, dynamic>> _callLog = [];

  bool get connected => _connected;
  String get activeApp => _activeApp;
  InterventionModel? get lastIntervention => _lastIntervention;
  List<InterventionModel> get history => List.unmodifiable(_history);
  List<Map<String, dynamic>> get callLog => List.unmodifiable(_callLog);

  /// Called when HIGH intervention arrives — navigate to InterventionHub
  Function(InterventionModel)? onHighTilt;
  /// Called when ELEVATED arrives — show in-app banner only
  Function(InterventionModel)? onElevated;

  void connect() {
    _socket = io.io(backendUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 2000,
      'reconnectionAttempts': 30,
    });

    _socket!.onConnect((_) {
      _connected = true;
      debugPrint('✅ Aegis socket connected to $backendUrl');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      debugPrint('❌ Aegis socket disconnected');
      notifyListeners();
    });

    _socket!.on('connected', (data) {
      if (data is Map && data['active_app'] != null) {
        _activeApp = data['active_app'];
        notifyListeners();
      }
    });

    _socket!.on('intervention', (data) {
      try {
        final model = InterventionModel.fromJson(
          Map<String, dynamic>.from(data as Map),
        );
        _lastIntervention = model;
        _history.insert(0, model);
        if (_history.length > 30) _history.removeLast();

        // Track Twilio calls
        if (model.triggerCall) {
          _callLog.insert(0, {
            'status': 'initiated',
            'stress': model.stressLevel,
            'time': DateFormat('h:mm a').format(DateTime.now()),
            'msg': model.toastMsg,
          });
          if (_callLog.length > 20) _callLog.removeLast();
        }

        notifyListeners();

        // Route to appropriate handler
        if (model.isHigh) {
          onHighTilt?.call(model);
        } else if (model.isElevated) {
          onElevated?.call(model);
        }
      } catch (e) {
        debugPrint('Intervention parse error: $e');
      }
    });

    _socket!.connect();
  }

  void sendAccelData({required double x, required double y, required double z}) {
    if (!_connected) return;
    _socket!.emit('accel_data', {'x': x, 'y': y, 'z': z});
  }

  void simulateStress() {
    _socket!.emit('au_metadata', {'au4': 0.85, 'au23': 0.90, 'blink_rate': 6});
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
