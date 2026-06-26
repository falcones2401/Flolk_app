import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  // Assicura il legame con i canali nativi
  WidgetsFlutterBinding.ensureInitialized();
  
  // Protezione globale dai crash visivi
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Funzione asincrona che prepara l'ambiente PRIMA di dare accesso all'interfaccia
  Future<void> _initializeServices() async {
    await Firebase.initializeApp();
    await initializeDateFormatting('it_IT', null);
  }

  @override
  Widget build(BuildContext context) {
    // Schermata di errore personalizzata in caso di altri problemi logici interni
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
        ),
        useMaterial3: true,
      ),
      // Usiamo un FutureBuilder globale: Finché Firebase non ha finito l'inizializzazione nativa,
      // l'app mostra uno splash screen scuro con caricamento protetto, evitando il crash.
      home: FutureBuilder(
        future: _initializeServices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const AuthGate();
          }
          
          // Schermata di caricamento iniziale sicura (Splash Screen temporaneo di pochissimi millisecondi)
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
