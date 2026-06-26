import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
// IMPORTANTE: Importiamo le opzioni di Firebase
import 'services/firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializzazione corretta passando le opzioni della piattaforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
          // Se Firebase sta caricando lo stato di login, mostra la rotella verde
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A884)),
                ),
              ),
            );
          }
          
          // Se l'utente è loggato, vai alla Home
          if (snapshot.hasData) return const HomeScreen();
          
          // Altrimenti mostra la schermata di login/registrazione
          return const AuthScreen();
        },
      ),
    );
  }
}
