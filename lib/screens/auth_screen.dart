import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true; // Stato per mostra/nascondi password

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // Mostra un messaggio di errore a schermo
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Gestione dell'autenticazione (Login / Registrazione)
  void _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    try {
      if (_isLogin) {
        // FIX BUG LOGIN: Eseguiamo un logout preventivo per ripulire sessioni sporche in cache
        await _auth.signOut();

        // Tentativo di Login
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // FIX BUG REGISTRAZIONE/LOGIN: Verifichiamo se l'utente ha confermato la mail prima di farlo entrare
        if (userCredential.user != null && !userCredential.user!.emailVerified) {
          await _auth.signOut();
          _showError("Devi prima confermare la tua email! Controlla la tua casella di posta.");
          setState(() => _isLoading = false);
          return;
        }

        // Se è verificato, aggiorna lo stato online su Firestore ed entra
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'isOnline': true,
        });

      } else {
        // Registrazione nuovo utente
        // Controlliamo prima se l'username è già preso su Firestore
        final usernameCheck = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .get();

        if (usernameCheck.docs.isNotEmpty) {
          _showError("Questo username è già registrato. Scegline un altro.");
          setState(() => _isLoading = false);
          return;
        }

        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          // FORCE SEND EMAIL: Invia la mail di sblocco/verifica account
          await userCredential.user!.sendEmailVerification();

          // Creiamo il record temporaneo su Firestore contrassegnando l'account come non verificato
          // NOTA: Viene eseguito PRIMA del signOut così non fallisce per via delle Security Rules
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': email,
            'username': username,
            'isOnline': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Scolleghiamo l'utente immediatamente costringendolo a verificare la mail
          await _auth.signOut();

          if (!mounted) return;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Row(
                children: [
                  Icon(Icons.mail_outline_rounded, color: Color(0xFF6366F1)),
                  SizedBox(width: 10),
                  Text("Verifica Email", style: TextStyle(color: Colors.white)),
                ],
              ),
              content: const Text(
                "Ti abbiamo inviato un link di conferma sulla tua email.\n\nClicca sul link contenuto nella mail per attivare il tuo account, dopodiché potrai effettuare il login.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _isLogin = true);
                  },
                  child: const Text("Ho capito, vai al Login", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Si è verificato un errore di autenticazione.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = "Dati non validi. Controlla email e password.";
      } else if (e.code == 'email-already-in-use') {
        errorMessage = "Questa email è già associata a un account.";
      } else if (e.code == 'weak-password') {
        errorMessage = "La password è troppo debole (almeno 6 caratteri).";
      } else if (e.code == 'invalid-email') {
        errorMessage = "L'indirizzo email non è valido.";
      }
      _showError(errorMessage);
    } catch (e) {
      _showError("Errore imprevisto: $e");
    } final {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sfondo scuro coerente con la chat
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icona o Logo App
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFF0F172A),
                    child: Icon(Icons.forum_rounded, size: 40, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isLogin ? "Bentornato!" : "Crea un Account",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  
                  // Campo Username (Solo in fase di registrazione)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Username",
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Inserisci un username";
                        if (val.trim().length < 3) return "L'username deve avere almeno 3 caratteri";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Campo Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.mail_outline_rounded, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Inserisci la tua email";
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) return "Inserisci una mail valida";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo Password con tasto MOSTRA/NASCONDI password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Inserisci la password";
                      if (val.length < 6) return "La password deve contenere almeno 6 caratteri";
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Pulsante Principale di Invio
                  if (_isLoading)
                    const CircularProgressIndicator(color: Color(0xFF6366F1))
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _submitAuthForm,
                      child: Text(
                        _isLogin ? "Accedi" : "Registrati",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Switcher tra Login e Registrazione
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _isLogin ? "Non hai un account? Registrati" : "Hai già un account? Accedi",
                      style: const TextStyle(color: Color(0xFF818CF8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
