import re

def update_home_screen():
    with open('c:/Users/ASUS/Desktop/Projects/HackMatrix/mobile/lib/screens/home_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # Imports
    content = content.replace("import '../services/socket_service.dart';", "import '../services/socket_service.dart';\nimport '../services/auth_service.dart';")

    # In _HomeScreenState
    content = re.sub(r'  Map<String, dynamic> _user = \{\};\n.*?void _startAccel\(\)', "  void _startAccel()", content, flags=re.DOTALL)
    
    # InitState
    content = re.sub(r'    _fetchUser\(\);\n    _startAccel\(\);', "    _startAccel();", content)

    # _Navbar
    navbar_sig = "class _Navbar extends StatelessWidget {\n  final SocketService socket;\n  const _Navbar({required this.socket});"
    navbar_new = "class _Navbar extends StatelessWidget {\n  final SocketService socket;\n  const _Navbar({required this.socket});"
    # Find Spacer() in Navbar Row
    nav_b_regex = r'      const Spacer\(\),\n      IconButton\('
    nav_b_new = r'''      const Spacer(),
      IconButton(
        icon: const Icon(Icons.logout, color: Colors.black54, size: 20),
        onPressed: () => context.read<AuthService>().logout(),
      ),
      IconButton('''
    content = re.sub(nav_b_regex, nav_b_new, content)

    # In build() where _DashboardTab is instantiated
    content = content.replace("              _DashboardTab(user: _user, socket: socket, shakeIntensity: _shakeIntensity),", "              _DashboardTab(user: context.watch<AuthService>().user ?? {}, socket: socket, shakeIntensity: _shakeIntensity),")

    # ProfileCard static "Prajwal" change
    content = content.replace("Text(user['name'] ?? 'Prajwal', style: const TextStyle(fontSize: 18, ", "Text(user['name'] ?? 'User', style: const TextStyle(fontSize: 18, ")
    content = content.replace("Good morning, ${user['name'] ?? 'Prajwal'}.", "Good morning, ${user['name'] ?? 'User'}.")

    # _SettingsTab connection info
    settings_info_regex = r"            Text\('User: Prajwal \(CGPA 9.0\)', style: TextStyle\(fontSize: 11, color: Colors.black54\)\),\n            const SizedBox\(height: 4\),\n            Text\('Twilio: \+91 9110 687 983', style: TextStyle\(fontSize: 11, color: Colors.black54\)\),"
    settings_info_new = r'''            Text('User: ${context.watch<AuthService>().user?['name'] ?? 'Prajwal'}', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 4),
            Text('Guardian: ${context.watch<AuthService>().user?['guardian_phone'] ?? 'Not set'}', style: TextStyle(fontSize: 11, color: Colors.black54)),'''
    content = re.sub(settings_info_regex, settings_info_new, content)

    # Add Guardian Edit Button to Settings
    settings_tile_regex = r"        const SizedBox\(height: 20\),\n        Container\("
    settings_tile_new = r'''        _SettingTile(
          icon: '🛡️', title: 'Guardian Contact',
          subtitle: 'Update emergency contact number',
          value: false, onChanged: (_) async {
            final auth = context.read<AuthService>();
            final ctrl = TextEditingController(text: auth.user?['guardian_phone'] ?? '');
            final newG = await showDialog<String>(context: context, builder: (_) => AlertDialog(
              title: const Text('Update Guardian Number'),
              content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '+1234567890')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
              ],
            ));
            if (newG != null && newG.isNotEmpty) auth.updateGuardian(newG);
          },
          color: const Color(0xFFF6E05E),
        ),
        const SizedBox(height: 20),
        Container('''
    content = re.sub(settings_tile_regex, settings_tile_new, content)

    with open('c:/Users/ASUS/Desktop/Projects/HackMatrix/mobile/lib/screens/home_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

def update_sensor_service():
    with open('c:/Users/ASUS/Desktop/Projects/HackMatrix/mobile/lib/services/sensor_service.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # Import AuthService inside sensor_service may be tricky without context, 
    # instead we can just call the /api/sos-alert endpoint directly using the token from shared preferences.
    sos_import = "import 'package:http/http.dart' as http;\nimport 'package:shared_preferences/shared_preferences.dart';\n"
    content = content.replace("import 'package:flutter/material.dart';", sos_import + "import 'package:flutter/material.dart';")

    sos_trigger_regex = r"    // Call Guardian\n    await _callGuardian\(\+\+919110687983'\);"
    sos_trigger_new = r"""    // Call Guardian via backend SOS Alert
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString('aegis_token');
      if (t != null) {
        await http.post(
          Uri.parse('http://10.0.2.2:8000/api/sos-alert'),
          headers: {'Authorization': 'Bearer $t'},
        );
      }
    } catch (_) {}
    await _callGuardian('+919110687983');"""
    # Wait, the code has `await _callGuardian('+919110687983');`
    content = re.sub(r"    // Call Guardian\n    await _callGuardian\('\+919110687983'\);", sos_trigger_new, content)

    with open('c:/Users/ASUS/Desktop/Projects/HackMatrix/mobile/lib/services/sensor_service.dart', 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    update_home_screen()
    update_sensor_service()
    print("UI patches applied.")
