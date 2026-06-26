import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart'; // Inizializzatore nativo per le date
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  // 1. Vincola i canali nativi Android/iOS
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Intercettatore globale dei crash
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Funzione asincrona bloccante: l'app NON si apre finché questi due non hanno finito
  Future<void> _initServices() async {
    await Firebase.initializeApp();
    await initializeDateFormatting('it_IT', null);
  }

  @override
  Widget build(BuildContext context) {
    // Schermata di crash logico personalizzata
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: const Color(0xFF7F1D1D),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                "CRASH RUNTIME FLUTTER:\n\n${details.exception}\n\n${details.stack}",
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
        ),
      );
    };

    return MaterialApp(
      title: 'Flolk Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          primary: const Color(0xFF6366F1),
          surface: const Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      // FutureBuilder protettivo: mostra un caricamento pulito finché Firebase non risponde
      home: FutureBuilder(
        future: _initServices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const AuthGate();
          }
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (!user.emailVerified) {
            return const AuthScreen();
          }
          return const HomeScreen();
        }

        return const AuthScreen();
      },
    );
  }
}
