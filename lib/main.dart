import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/secretary_dashboard_screen.dart';
import 'screens/user_dashboard_screen.dart';
import 'screens/patient_registration_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/queue_management_screen.dart';
import 'screens/general_appointments_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. ATIVE O APP CHECK AQUI
  // Lógica para ativar o provedor correto
  AndroidProvider androidProvider = AndroidProvider.playIntegrity;
  if (kDebugMode) {
    // Se estiver em modo de debug, use o provedor de depuração
    androidProvider = AndroidProvider.debug;
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider: androidProvider, // Use a variável aqui
    appleProvider: AppleProvider.appAttest,
  );
  await initializeDateFormatting('pt_BR', null);
  runApp(const FilaVirtualApp());
}

class FilaVirtualApp extends StatelessWidget {
  const FilaVirtualApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fila Virtual',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A7CA5),
          primary: const Color(0xFF3A7CA5),
          secondary: const Color(0xFF6BBF59),
          background: const Color(0xFFF5F5F3),
          surface: Colors.white,
          error: const Color(0xFFE57373),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: const Color(0xFF2E2E2E),
          onSurface: const Color(0xFF2E2E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F3),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3A7CA5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F3),
          foregroundColor: Color(0xFF2E2E2E),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3A7CA5), width: 2),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF2E2E2E)),
          displayMedium: TextStyle(color: Color(0xFF2E2E2E)),
          displaySmall: TextStyle(color: Color(0xFF2E2E2E)),
          headlineLarge: TextStyle(color: Color(0xFF2E2E2E)),
          headlineMedium: TextStyle(color: Color(0xFF2E2E2E)),
          headlineSmall: TextStyle(color: Color(0xFF2E2E2E)),
          titleLarge:
              TextStyle(color: Color(0xFF2E2E2E), fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFF2E2E2E)),
          titleSmall: TextStyle(color: Color(0xFF2E2E2E)),
          bodyLarge: TextStyle(color: Color(0xFF2E2E2E)),
          bodyMedium: TextStyle(color: Color(0xFF6E6E6E)),
          labelLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const IntroScreen(),
        '/role_selection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/secretary_dashboard': (context) => const SecretaryDashboardScreen(),
        '/user_dashboard': (context) => const UserDashboardScreen(),
        '/patient_registration': (context) => const PatientRegistrationScreen(),
        '/appointments': (context) => const AppointmentsScreen(),
        '/queue_management': (context) => const QueueManagementScreen(),
        '/general_appointments': (context) => const GeneralAppointmentsScreen(),
      },
    );
  }
}
