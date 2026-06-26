import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FlolkApp());
}

class FlolkApp extends StatelessWidget {
  const FlolkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flolk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00A884),
        scaffoldBackgroundColor: const Color(0xFF0B141A),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // GESTIONE ATTESA: Se Firebase sta caricando, mostra una rotella di caricamento
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
                ),
              ),
            );
          }
          
          // Se snapshot ha dati, l'utente è loggato
          if (snapshot.hasData) return const HomeScreen();
          
          // Altrimenti mostra la schermata di login
          return const AuthScreen();
        },
      ),
    );
  }
}
