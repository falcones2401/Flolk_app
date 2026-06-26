import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';

void main() {
  // Assicura il legame con i canali nativi prima di fare qualsiasi cosa
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Forza l'applicazione ad aspettare le configurazioni native di Firebase e delle date
  Future<void> _initializeFirebaseAndDates() async {
    await Firebase.initializeApp();
    await initializeDateFormatting('it_IT', null);
  }

  @override
  Widget build(BuildContext context) {
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
      // Il FutureBuilder blocca l'app finché Firebase non è pronto al 100%
      home: FutureBuilder(
        future: _initializeFirebaseAndDates(),
        builder: (context, snapshot) {
          // Se Firebase fallisce l'avvio nativo, intercettiamo l'errore qui!
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: const Color(0xFF7F1D1D),
              body: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      "ERRORE CRITICO DI CONFIGURAZIONE:\n\n${snapshot.error}\n\nVerifica che il file google-services.json sia presente in android/app/",
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
                    ),
                  ),
                ),
              ),
            );
          }

          // Se ha finito l'inizializzazione con successo, passa alla verifica dell'utente
          if (snapshot.connectionState == ConnectionState.done) {
            return const AuthGate();
          }

          // Schermata di caricamento temporanea (Splash Screen)
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
