import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/socket_service.dart';
import 'services/haptic_service.dart';
import 'screens/home_screen.dart';
import 'screens/intervention_hub.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HapticService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SocketService(),
      child: const AegisApp(),
    ),
  );
}

class AegisApp extends StatefulWidget {
  const AegisApp({super.key});
  @override
  State<AegisApp> createState() => _AegisAppState();
}

class _AegisAppState extends State<AegisApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupSocket());
  }

  void _setupSocket() {
    final socket = context.read<SocketService>();
    socket.onHighTilt = (intervention) async {
      // 1. Heartbeat haptic pulse
      HapticService.loopHeartbeat(times: 5);
      // 2. Direct pushReplacement — no permission check needed
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InterventionHub(intervention: intervention),
        ),
      );
    };
    socket.connect();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegis.ai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080B14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF63B3ED),
          secondary: Color(0xFFFFBF00),
          surface: Color(0xFF0D1117),
          onPrimary: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomeScreen(),
    );
  }
}
