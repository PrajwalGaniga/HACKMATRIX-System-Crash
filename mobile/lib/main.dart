import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/socket_service.dart';
import 'services/sensor_service.dart';
import 'services/haptic_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/intervention_hub.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HapticService.init();
  final authService = AuthService();
  await authService.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => SensorService()),
      ],
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
    final sensor = context.read<SensorService>();

    // Route both Socket-based and Sensor-based high stress to the hub
    void routeToHub(intervention) {
      HapticService.heartbeat();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InterventionHub(intervention: intervention),
        ),
      );
    }

    socket.onHighTilt = routeToHub;
    sensor.onPacingDetected = routeToHub;
    
    socket.connect();
    // Start background sensor monitoring for mobile-only users
    sensor.startMonitoring();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegis.ai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFE8F5E9), // Light green mindful bg
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E1E1E), // Dark text & buttons
          secondary: Color(0xFF4ADE80), // Soft green accents
          surface: Colors.white,
          onPrimary: Colors.white,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      ),
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          return auth.isAuthenticated ? const HomeScreen() : const AuthScreen();
        },
      ),
    );
  }
}
