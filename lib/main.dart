import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core;
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart'; // Sostituisci con i tuoi path reali
import 'screens/home_screen.dart';  // Sostituisci con i tuoi path reali

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SecureChatApp());
}

class SecureChatApp extends StatelessWidget {
  const SecureChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Usa StreamBuilder per sentire se l'utente è già loggato sul dispositivo
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Se l'utente esiste, vai dritto alla Home senza mostrare il login
            return const HomeScreen();
          }
          // Altrimenti, mostra la schermata di login
          return const LoginScreen();
        },
      ),
    );
  }
}
