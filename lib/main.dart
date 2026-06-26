import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inizializzazione nativa di Firebase per Android/iOS
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flolk Chat',
      debugShowCheckedModeBanner: false,
      // Tema scuro coordinato con il resto dell'applicazione
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF818CF8),
          surface: const Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      // Gestore dinamico dello stato di attivazione dell'utente
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
        // Se Firebase sta ancora verificando i token di sessione locali
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          );
        }

        // Se l'utente è loggato nel sistema di Firebase
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;

          // FIX CRITICO: Controlliamo se l'utente ha validato il link email
          // Se non lo ha fatto, forziamo il logout visivo e lo rimandiamo ad autenticarsi
          if (!user.emailVerified) {
            return const AuthScreen();
          }

          // Se l'utente è loggato ed è verificato, andiamo alla HomeScreen
          return const HomeScreen();
        }

        // Se non c'è nessuna sessione utente attiva, mostra Login/Registrazione
        return const AuthScreen();
      },
    );
  }
}