import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/socket_service.dart';
import '../services/haptic_service.dart';
import '../models/intervention_model.dart';
import '../widgets/recovery_chart.dart';
import 'intervention_hub.dart';
import 'game_shake.dart';
import 'game_neon_trace.dart';
import 'game_bubble_pop.dart';
import 'game_bubble_wrap.dart';
import 'game_coloring.dart';
import 'game_breathing.dart';
import 'game_mindful_puzzle.dart';
import 'game_idle_garden.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _backend = SocketService.backendUrl;
  Map<String, dynamic> _user = {};
  StreamSubscription? _accelSub;
  double _shakeIntensity = 0.0;
  int _selectedTab = 0;
  bool _notifEnabled = true;
  bool _vibrateEnabled = true;
  bool _autoNavigate = true;
  InterventionModel? _inAppNotif;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _startAccel();
    // Wire in-app notification banner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocketService>().onElevated = _showInAppBanner;
    });
  }

  Future<void> _fetchUser() async {
    try {
      final r = await http.get(Uri.parse('$_backend/api/user'));
      if (r.statusCode == 200) setState(() => _user = jsonDecode(r.body));
    } catch (_) {
      setState(() => _user = {
        'name': 'Prajwal', 'cgpa': 9.0,
        'interests': ['React', 'ML', 'E-Sports'],
        'role': 'ML Engineer / Pro Gamer',
        'recovery_score': 87, 'tilt_events_avoided': 12,
        'blink_normalization': 76, 'sessions_today': 4,
      });
    }
  }

  void _startAccel() {
    _accelSub = accelerometerEventStream().listen((ev) {
      final v = (ev.x.abs() + ev.y.abs() + ev.z.abs()) / 3;
      if (mounted) setState(() => _shakeIntensity = v.clamp(0, 20));
      context.read<SocketService>().sendAccelData(x: ev.x, y: ev.y, z: ev.z);
    });
  }

  void _showInAppBanner(InterventionModel m) {
    if (!_notifEnabled || !mounted) return;
    setState(() => _inAppNotif = m);
    _notifTimer?.cancel();
    _notifTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _inAppNotif = null);
    });
    if (_vibrateEnabled) HapticService.rhythmicBuzz();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _notifTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: SafeArea(
        child: Column(children: [
          _Navbar(socket: socket),
          // In-app notification banner
          if (_inAppNotif != null)
            _InAppBanner(
              intervention: _inAppNotif!,
              onDismiss: () => setState(() => _inAppNotif = null),
            ),
          Expanded(
            child: IndexedStack(index: _selectedTab, children: [
              _DashboardTab(user: _user, socket: socket, shakeIntensity: _shakeIntensity),
              _GamesTab(),
              _LogsTab(history: socket.history, callLog: socket.callLog),
              _SettingsTab(
                notifEnabled: _notifEnabled,
                vibrateEnabled: _vibrateEnabled,
                autoNavigate: _autoNavigate,
                onNotifChanged: (v) => setState(() => _notifEnabled = v),
                onVibrateChanged: (v) => setState(() => _vibrateEnabled = v),
                onAutoNavChanged: (v) => setState(() => _autoNavigate = v),
              ),
            ]),
          ),
          _BottomNav(selected: _selectedTab, onTap: (i) => setState(() => _selectedTab = i)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Navbar
// ─────────────────────────────────────────────────────────
class _Navbar extends StatelessWidget {
  final SocketService socket;
  const _Navbar({required this.socket});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: const BoxDecoration(
      color: Color(0xFF080B14),
      border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
    ),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF63B3ED), Color(0xFFB794F4)]),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Center(child: Text('🛡️', style: TextStyle(fontSize: 16))),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Aegis.ai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
        Text('Bio-Stabilizer · v2.0', style: TextStyle(fontSize: 9, color: Colors.grey[600], letterSpacing: 0.8)),
      ]),
      const Spacer(),
      _ConnDot(connected: socket.connected),
    ]),
  );
}

class _ConnDot extends StatelessWidget {
  final bool connected;
  const _ConnDot({required this.connected});
  @override
  Widget build(BuildContext context) {
    final c = connected ? const Color(0xFF68D391) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
        const SizedBox(width: 5),
        Text(connected ? 'Live' : 'Off', style: TextStyle(fontSize: 10, color: c, fontFamily: 'monospace')),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
// In-App Notification Banner
// ─────────────────────────────────────────────────────────
class _InAppBanner extends StatelessWidget {
  final InterventionModel intervention;
  final VoidCallback onDismiss;
  const _InAppBanner({required this.intervention, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isHigh = intervention.isHigh;
    final color = isHigh ? const Color(0xFFFF6B35) : const Color(0xFFF6AD55);
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16)],
        ),
        child: Row(children: [
          Text(intervention.toastEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isHigh ? '⚡ High Tilt Detected' : '⚠ Elevated Stress',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace'),
            ),
            Text(
              intervention.toastMsg.isNotEmpty ? intervention.toastMsg : intervention.interventionTip,
              style: TextStyle(fontSize: 12, color: Colors.grey[300]),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            if (intervention.breathingTip.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('💨 ${intervention.breathingTip}', style: const TextStyle(fontSize: 10, color: Color(0xFF76E4F7))),
              ),
          ])),
          const SizedBox(width: 8),
          Icon(Icons.close, size: 16, color: Colors.grey[600]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Tab 1: Dashboard
// ─────────────────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> user;
  final SocketService socket;
  final double shakeIntensity;
  const _DashboardTab({required this.user, required this.socket, required this.shakeIntensity});

  @override
  Widget build(BuildContext context) {
    final i = socket.lastIntervention;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Active app
        if (socket.activeApp.isNotEmpty)
          _InfoPill(label: '📍', value: socket.activeApp),
        const SizedBox(height: 12),

        // Stress status
        _StressCard(intervention: i),
        const SizedBox(height: 12),

        // Breathing guide (shows when elevated/high)
        if (i != null && i.action != 'NONE')
          _BreathingCard(tip: i.breathingTip, reminder: i.restReminder),
        if (i != null && i.action != 'NONE') const SizedBox(height: 12),

        // Profile
        _ProfileCard(user: user),
        const SizedBox(height: 12),

        // Recovery chart
        RecoveryChart(scores: const [72, 75, 78, 82, 80, 85, 87]),
        const SizedBox(height: 12),

        // Accel live
        _AccelCard(intensity: shakeIntensity),
        const SizedBox(height: 12),

        // Quick test
        _TestButton(onTap: () {
          HapticService.heartbeat();
          socket.simulateStress();
        }),
      ]),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label, value;
  const _InfoPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF76E4F7).withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFF76E4F7).withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 6),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _StressCard extends StatelessWidget {
  final InterventionModel? intervention;
  const _StressCard({this.intervention});
  @override
  Widget build(BuildContext context) {
    final level = intervention?.stressLevel ?? 'IDLE';
    final color = level == 'HIGH' ? Colors.redAccent : level == 'ELEVATED' ? const Color(0xFFF6AD55) : level == 'STABLE' ? const Color(0xFF68D391) : Colors.grey;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 18)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🧠', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('Gemini Cognitive Engine', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace', letterSpacing: 0.6)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.4))),
            child: Text(level, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
          ),
        ]),
        const SizedBox(height: 10),
        if (intervention?.reasoning.isNotEmpty == true) ...[
          Text(intervention!.reasoning, style: TextStyle(fontSize: 12, color: Colors.grey[300])),
          const SizedBox(height: 5),
          Text('"${intervention!.interventionTip}"', style: const TextStyle(fontSize: 11, color: Color(0xFF76E4F7), fontStyle: FontStyle.italic)),
        ] else
          Text('Monitoring… awaiting biosignals', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ]),
    );
  }
}

class _BreathingCard extends StatelessWidget {
  final String tip, reminder;
  const _BreathingCard({required this.tip, required this.reminder});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF63B3ED).withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF63B3ED).withValues(alpha: 0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('💨 Breathing Guide', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF63B3ED), letterSpacing: 0.6)),
      const SizedBox(height: 6),
      if (tip.isNotEmpty) Text(tip, style: TextStyle(fontSize: 12, color: Colors.grey[300])),
      if (reminder.isNotEmpty) ...[
        const SizedBox(height: 5),
        Text('🌿 $reminder', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
      ],
    ]),
  );
}

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const _ProfileCard({required this.user});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
    child: Column(children: [
      Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF63B3ED), Color(0xFFB794F4)]), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('🎮', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user['name'] ?? 'Prajwal', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(user['role'] ?? 'ML Engineer / Pro Gamer', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ])),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        _Stat('CGPA', '${user['cgpa'] ?? 9.0}', const Color(0xFF63B3ED)),
        const SizedBox(width: 8),
        _Stat('Recovery', '${user['recovery_score'] ?? 87}%', const Color(0xFF68D391)),
        const SizedBox(width: 8),
        _Stat('Tilt Saved', '${user['tilt_events_avoided'] ?? 12}', const Color(0xFFB794F4)),
      ]),
    ]),
  );
}

class _Stat extends StatelessWidget {
  final String label, value; final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(9), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontFamily: 'monospace')),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
    ]),
  ));
}

class _AccelCard extends StatelessWidget {
  final double intensity;
  const _AccelCard({required this.intensity});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('📡  Accelerometer · HAR Stream', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace')),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: intensity / 20,
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          valueColor: AlwaysStoppedAnimation(intensity > 12 ? Colors.redAccent : intensity > 6 ? const Color(0xFFF6AD55) : const Color(0xFF63B3ED)),
          minHeight: 7,
        ),
      ),
      const SizedBox(height: 5),
      Text('${intensity.toStringAsFixed(1)} m/s²   ${intensity > 12 ? "HIGH MOTION" : intensity > 6 ? "Moderate" : "Stable"}', style: TextStyle(fontSize: 9, color: Colors.grey[600], fontFamily: 'monospace')),
    ]),
  );
}

class _TestButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TestButton({required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: const Text('🚨'),
      label: const Text('Simulate HIGH Stress', style: TextStyle(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────
// Tab 2: Games
// ─────────────────────────────────────────────────────────
class _GamesTab extends StatelessWidget {
  const _GamesTab();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🎮  Stress Relief Games', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace', letterSpacing: 1)),
        const SizedBox(height: 4),
        Text('No scores. No levels. Just relief.', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        const SizedBox(height: 16),
        _GameCard(
          emoji: '🫧', title: 'Virtual Bubble Wrap Simulator',
          subtitle: 'Pop the grid of bubble cells\nTactile satisfaction · Fidget outlet',
          color: const Color(0xFF76E4F7),
          why: 'Repetitive tapping provides a simple distraction to replace anxious thoughts.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BubbleWrapGame())),
        ),
        const SizedBox(height: 12),
        _GameCard(
          emoji: '🎨', title: 'Relaxing Coloring Canvas',
          subtitle: 'Fill the mandala with color\nArt therapy · Meditative focus',
          color: const Color(0xFFF6AD55),
          why: 'Focusing on coloring patterns helps the mind relax and achieve a meditative state.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RelaxingColoringGame())),
        ),
        const SizedBox(height: 12),
        _GameCard(
          emoji: '💨', title: 'Guided Breathing Trainer',
          subtitle: '4-4-4 box breathing\nPhysiological self-regulation',
          color: const Color(0xFF63B3ED),
          why: 'Gamified deep-breathing exercises stabilize heart-rate variability.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingTrainerGame())),
        ),
        const SizedBox(height: 12),
        _GameCard(
          emoji: '🧩', title: 'Mindful Puzzle Game',
          subtitle: 'Gentle color gradient sorting\nCognitive focus · Flow state',
          color: const Color(0xFFB794F4),
          why: 'Solving puzzles channels creative energy into solvable problems, distracting from stress.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MindfulPuzzleGame())),
        ),
        const SizedBox(height: 12),
        _GameCard(
          emoji: '🌿', title: 'Idle Garden Simulator',
          subtitle: 'Tap to plant emoji seeds\nNurturing · Slow accomplishment',
          color: const Color(0xFF68D391),
          why: 'Cozy and slow-paced gameplay soothes nerves and refocuses racing thoughts.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IdleGardenGame())),
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white12),
        const SizedBox(height: 20),
        _GameCard(
          emoji: '💥', title: 'Gravity Dust',
          subtitle: 'Shake to clear stress particles\nSomatic discharge · Adrenaline dump',
          color: const Color(0xFFFF6B35),
          why: 'Physical shaking releases built-up adrenaline and resets your nervous system.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GravityDustGame())),
        ),
        const SizedBox(height: 12),
        _GameCard(
          emoji: '🌌', title: 'Neon Trace',
          subtitle: 'Follow the glowing path with your finger\nPanic-loop killer · Grounding',
          color: const Color(0xFF4FD1C5),
          why: 'Motor tasks force your brain to the present moment, halting tilt and panic loops.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NeonTraceGame())),
        ),
        const SizedBox(height: 12),
        _GameCard(
          emoji: '🫧', title: 'Bubble Pop',
          subtitle: 'Tap floating bubbles to pop them\nTactile grounding · Sensory reset',
          color: const Color(0xFFFC8181),
          why: 'The tactile satisfaction of popping activates the parasympathetic nervous system.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BubblePopGame())),
        ),
      ]),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji, title, subtitle, why;
  final Color color;
  final VoidCallback onTap;
  const _GameCard({required this.emoji, required this.title, required this.subtitle, required this.why, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[400], height: 1.4)),
          const SizedBox(height: 5),
          Text('Why: $why', style: TextStyle(fontSize: 9, color: Colors.grey[600], fontStyle: FontStyle.italic, height: 1.3)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.5), size: 14),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────
// Tab 3: Logs (Intervention History + Call Log)
// ─────────────────────────────────────────────────────────
class _LogsTab extends StatelessWidget {
  final List<InterventionModel> history;
  final List<Map<String, dynamic>> callLog;
  const _LogsTab({required this.history, required this.callLog});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          tabs: const [Tab(text: '📋  Interventions'), Tab(text: '📞  Call Log')],
          labelStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
          indicatorColor: const Color(0xFF63B3ED),
          labelColor: const Color(0xFF63B3ED),
          unselectedLabelColor: Colors.grey,
        ),
        Expanded(
          child: TabBarView(children: [
            _InterventionList(history: history),
            _CallHistory(callLog: callLog),
          ]),
        ),
      ]),
    );
  }
}

class _InterventionList extends StatelessWidget {
  final List<InterventionModel> history;
  const _InterventionList({required this.history});
  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(child: Text('No interventions yet.\nTrigger a stress test from React.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], height: 1.6)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final h = history[i];
        final color = h.isHigh ? Colors.redAccent : h.isElevated ? const Color(0xFFF6AD55) : const Color(0xFF68D391);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${h.toastEmoji} ${h.stressLevel} — ${h.action}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Text(DateFormat('MMM d, h:mm a').format(h.timestamp), style: TextStyle(fontSize: 9, color: Colors.grey[600], fontFamily: 'monospace')),
              ])),
              if (h.triggerCall) const Text('📞 Called', style: TextStyle(fontSize: 9, color: Color(0xFF76E4F7))),
            ]),
            if (h.gameId != null && h.gameId!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('🎮 Game: ${h.gameId!.replaceAll('_', ' ')}', style: TextStyle(fontSize: 9, color: Colors.grey[600], fontFamily: 'monospace')),
            ],
            if (h.toastMsg.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('"${h.toastMsg}"', style: TextStyle(fontSize: 11, color: Colors.grey[400], fontStyle: FontStyle.italic)),
            ),
            if (h.breathingTip.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('💨 ${h.breathingTip}', style: TextStyle(fontSize: 9, color: const Color(0xFF76E4F7).withValues(alpha: 0.8))),
            ),
            if (h.activeApp.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('📍 ${h.activeApp}', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            ),
          ]),
        );
      },
    );
  }
}

class _CallHistory extends StatelessWidget {
  final List<Map<String, dynamic>> callLog;
  const _CallHistory({required this.callLog});
  @override
  Widget build(BuildContext context) {
    if (callLog.isEmpty) {
      return Center(child: Text('No calls yet.\nTwilio calls appear here when HIGH stress is detected.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], height: 1.6)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: callLog.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = callLog[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF76E4F7).withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF76E4F7).withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Center(child: Text('📞', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('+91 9110 687 983', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              Text('Polly.Joanna · ${c['status'] ?? 'initiated'}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ])),
            Text(c['time'] ?? '', style: TextStyle(fontSize: 9, color: Colors.grey[600], fontFamily: 'monospace')),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Tab 4: Settings
// ─────────────────────────────────────────────────────────
class _SettingsTab extends StatelessWidget {
  final bool notifEnabled, vibrateEnabled, autoNavigate;
  final ValueChanged<bool> onNotifChanged, onVibrateChanged, onAutoNavChanged;
  const _SettingsTab({
    required this.notifEnabled, required this.vibrateEnabled, required this.autoNavigate,
    required this.onNotifChanged, required this.onVibrateChanged, required this.onAutoNavChanged,
  });
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('⚙️  Settings', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace', letterSpacing: 1)),
        const SizedBox(height: 14),
        _SettingTile(
          icon: '🔔', title: 'In-App Notifications',
          subtitle: 'Show banner alerts when stress is detected',
          value: notifEnabled, onChanged: onNotifChanged,
          color: const Color(0xFFF6AD55),
        ),
        _SettingTile(
          icon: '📳', title: 'Haptic Feedback',
          subtitle: 'Heartbeat vibration during interventions',
          value: vibrateEnabled, onChanged: onVibrateChanged,
          color: const Color(0xFF63B3ED),
        ),
        _SettingTile(
          icon: '🚀', title: 'Auto-Navigate to Game',
          subtitle: 'Open game screen automatically on HIGH tilt signal',
          value: autoNavigate, onChanged: onAutoNavChanged,
          color: const Color(0xFF68D391),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ℹ️  Connection Info', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Text('Backend: ${SocketService.backendUrl}', style: TextStyle(fontSize: 11, color: const Color(0xFF76E4F7), fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text('User: Prajwal (CGPA 9.0)', style: TextStyle(fontSize: 11, color: Colors.grey[400], fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text('Twilio → +91 9110 687 983', style: TextStyle(fontSize: 11, color: Colors.grey[400], fontFamily: 'monospace')),
          ]),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String icon, title, subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _SettingTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: value ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.07)),
    ),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: color, inactiveThumbColor: Colors.grey[700]),
    ]),
  );
}

// ─────────────────────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.dashboard_outlined, '  Home'),
      (Icons.sports_esports_outlined, 'Games'),
      (Icons.history_outlined, '  Logs'),
      (Icons.settings_outlined, '  Settings'),
    ];
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF0D1117), border: Border(top: BorderSide(color: Color(0x12FFFFFF)))),
      child: Row(children: items.asMap().entries.map((e) {
        final idx = e.key; final (icon, label) = e.value;
        final sel = idx == selected;
        final c = sel ? const Color(0xFF63B3ED) : Colors.grey[600]!;
        return Expanded(child: InkWell(
          onTap: () => onTap(idx),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: c, size: 20),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 9, color: c)),
            ]),
          ),
        ));
      }).toList()),
    );
  }
}
