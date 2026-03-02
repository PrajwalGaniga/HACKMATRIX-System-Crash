import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final Map<String, bool> _granted = {
    'Notifications': false,
    'Accelerometer': false,
    'Camera': false,
    'Display Over Apps': false,
  };

  bool get _allGranted => _granted.values.every((v) => v);

  Future<void> _requestAll() async {
    // Notifications
    final notif = await Permission.notification.request();
    // Camera
    final cam = await Permission.camera.request();
    // Sensors (accelerometer) – no explicit permission on most Android
    // System alert window (display over apps)
    final overlay = await Permission.systemAlertWindow.request();

    setState(() {
      _granted['Notifications'] = notif.isGranted;
      _granted['Camera'] = cam.isGranted;
      _granted['Accelerometer'] = true; // sensors_plus doesn't need permission
      _granted['Display Over Apps'] = overlay.isGranted || overlay.isLimited;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080B14), Color(0xFF0D1117), Color(0xFF080B14)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Logo
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF63B3ED), Color(0xFFB794F4)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('🛡️', style: TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Aegis.ai', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white)),
                    Text('Bio-Stabilizer · v2.0', style: TextStyle(fontSize: 11, color: Colors.grey[600], letterSpacing: 1.2)),
                  ]),
                ]),
                const SizedBox(height: 36),
                const Text('Permissions Hub', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text('Aegis needs these to protect your mental performance.', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                const SizedBox(height: 28),
                // Permission tiles
                ..._granted.entries.map((e) => _PermissionTile(
                  label: e.key,
                  granted: e.value,
                  icon: _iconFor(e.key),
                )),
                const Spacer(),
                // CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _allGranted ? widget.onComplete : _requestAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allGranted ? const Color(0xFF68D391) : const Color(0xFF63B3ED),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: Text(_allGranted ? '✅ All granted — Enter Aegis' : '🔐 Grant Permissions'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _iconFor(String label) {
    switch (label) {
      case 'Notifications': return '🔔';
      case 'Camera': return '📸';
      case 'Accelerometer': return '📡';
      case 'Display Over Apps': return '🪟';
      default: return '🔑';
    }
  }
}

class _PermissionTile extends StatelessWidget {
  final String label, icon;
  final bool granted;
  const _PermissionTile({required this.label, required this.icon, required this.granted});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted ? const Color(0xFF68D391).withOpacity(0.4) : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
        Icon(
          granted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: granted ? const Color(0xFF68D391) : Colors.grey[600],
          size: 22,
        ),
      ]),
    );
  }
}
