import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _message = '';
  bool _isSigningIn = true;

  Future<void> _submitForm() async {
    setState(() {
      _message = '';
    });

    try {
      if (_isSigningIn) {
        // Sign In
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        setState(() {
          _message = 'Signed in successfully!';
        });
      } else {
        // Sign Up
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        setState(() {
          _message = 'Signed up successfully!';
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = e.message ?? 'An unknown error occurred.';
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _message = '';
    });
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      UserCredential userCredential = await _auth.signInWithPopup(googleProvider);

      setState(() {
        _message = 'Signed in with Google successfully!';
      });
      print("Google user signed in: ${userCredential.user?.displayName}");

      if (mounted) {
        Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user') {
        setState(() {
          _message = 'Google sign-in popup closed.';
        });
      } else {
        setState(() {
          _message = e.message ?? 'Error signing in with Google.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'An unexpected error occurred during Google sign-in: $e';
      });
      print(e);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSigningIn ? 'Sign In' : 'Sign Up'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(_isSigningIn ? 'Sign In' : 'Sign Up'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSigningIn = !_isSigningIn;
                    _message = '';
                  });
                },
                child: Text(_isSigningIn
                    ? 'Need an account? Sign Up'
                    : 'Already have an account? Sign In'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/4/4a/Logo_2013_Google.png',
                  height: 24.0,
                ),
                label: const Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _message,
                style: TextStyle(
                    color: _message.contains('successfully')
                        ? Colors.green
                        : Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
