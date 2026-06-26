import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart'; // IMPORTANTE: Per inizializzare i dati delle date
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  // 1. Assicura il legame con i canali nativi di Android/iOS
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Protezione totale dai crash di rendering (Cattura l'errore e lo mostra a schermo)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  try {
    // 3. Inizializza i pacchetti delle date per evitare crash a runtime
    await initializeDateFormatting('it_IT', null);
    
    // 4. Inizializzazione nativa di Firebase
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Errore critico in fase di avvio: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Gestore degli errori visivi globale: se un widget crasha, vedrai l'errore scritto su sfondo rosso
    // invece dello schermo bianco vuoto della morte di Codemagic.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: const Color(0xFF7F1D1D),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                "CRASH RUNTME FLUTTER:\n\n${details.exception}\n\n${details.stack}",
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
      home: const AuthGate(),
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
