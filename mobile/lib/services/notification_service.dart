/// NotificationService — simplified stub.
/// flutter_local_notifications removed to fix desugaring build error.
/// All intervention alerting is handled in-app via _InAppBanner in home_screen.dart.
class NotificationService {
  static Future<void> init() async {}

  static Future<void> showInterventionAlert({
    required String title,
    required String body,
    required String gameId,
  }) async {
    // No-op — in-app banner handled by SocketService.onElevated in HomeScreen
  }

  static Future<void> showElevatedAlert({required String message}) async {
    // No-op
  }
}
