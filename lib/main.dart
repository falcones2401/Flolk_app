import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializzazione robusta che passa direttamente le opzioni generate da FlutterFire
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const SecureChatApp());
}

class SecureChatApp extends StatelessWidget {
  const SecureChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B141A),
        colorScheme: const ColorScheme.dark().copyWith(
          primary: const Color(0xFF00A884),
          secondary: const Color(0xFF00A884),
        ),
      ),
      home: const AuthScreen(),
    );
  }
}
