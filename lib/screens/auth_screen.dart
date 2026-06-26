import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitData() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });
    
    final isLogin = _tabController.index == 0;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Per favore, compila tutti i campi.';
        _isLoading = false;
      });
      return;
    }

    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        _navigateToHome();
      } else {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        if (userCredential.user != null) {
          await userCredential.user!.sendEmailVerification();
          _showVerificationDialog();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nelle credenziali inserite.';
        _isLoading = false;
      });
    }
  }

  void _showVerificationDialog() {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        title: const Text('Verifica Email', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Ti abbiamo inviato un link di conferma. Cliccalo e poi effettua l\'accesso dalla schermata principale.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _tabController.animateTo(0);
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF00A884))),
          )
        ],
      ),
    );
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(_animationController),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2C34),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: _buildAuthFormScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthFormScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_person_rounded, size: 70, color: Color(0xFF00A884)),
        const SizedBox(height: 25),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF0B141A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent, // <--- CANCELLA LA RIGHINA BIANCA
            indicator: BoxDecoration(
              color: const Color(0xFF00A884),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'ACCEDI'),
              Tab(text: 'REGISTRATI'),
            ],
          ),
        ),
        const SizedBox(height: 35),
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF0B141A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF0B141A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 35),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitData,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A884),
            disabledBackgroundColor: const Color(0xFF00A884).withOpacity(0.6), // Evita l'effetto invisibile
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: _isLoading 
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) => Text(
                  _tabController.index == 0 ? 'ACCEDI' : 'REGISTRATI',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
