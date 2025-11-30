// lib/auth_page.dart
import 'package:flutter/material.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/utils/ui_helper.dart';

/// The entry point for user authentication (Login/Register).
///
/// This widget handles both Sign In and Sign Up flows, allowing users to
/// toggle between them. It uses [AuthService] for the backend logic and
/// provides client-side validation for form fields.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final AuthService _authService = AuthService();

  /// Global Key required to validate the [Form] widget.
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// Tracks whether the user is in "Sign In" mode (true) or "Sign Up" mode (false).
  bool _isSigningIn = true;

  /// Indicates if an auth operation is currently in progress.
  bool _isLoading = false;

  /// Validates the email format using a regular expression.
  ///
  /// Returns null if valid, or an error message string if invalid.
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Simple regex to check for standard email format (text@domain.tld).
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email format';
    }
    return null;
  }

  /// Validates the password strength.
  ///
  /// Currently enforces a minimum length of 6 characters (Firebase default requirement).
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Handles the submission of the email/password form.
  Future<void> _submitForm() async {
    // Step 1: Validate client-side inputs before making network requests.
    // If validation fails, the UI will automatically show error texts under fields.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSigningIn) {
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) {
          UiHelper.showSuccess(context, 'Signed in successfully!');
          // Close the auth page and return to the previous screen (e.g. Cart)
          Navigator.of(context).pop();
        }
      } else {
        await _authService.registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) {
          UiHelper.showSuccess(context, 'Signed up successfully!');
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Use the centralized UI helper to show a user-friendly error message.
      if (mounted) UiHelper.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Initiates the Google Sign-In flow.
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        UiHelper.showSuccess(context, 'Signed in with Google!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) UiHelper.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      appBar: AppBar(title: Text(_isSigningIn ? 'Sign In' : 'Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Form(
            key: _formKey, // Connects the validation key to the widget tree
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _isLoading ? _buildLoadingState() : _buildAuthForm(),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the loading state UI.
  List<Widget> _buildLoadingState() {
    return [
      const CircularProgressIndicator(),
      const SizedBox(height: 20),
    ];
  }

  /// Builds the authentication form.
  List<Widget> _buildAuthForm() {
    return [
      _buildEmailField(),
      const SizedBox(height: defaultPadding),
      _buildPasswordField(),
      const SizedBox(height: 24),
      _buildSubmitButton(),
      const SizedBox(height: defaultPadding),
      _buildToggleModeButton(),
      const SizedBox(height: defaultPadding),
      const Divider(),
      const SizedBox(height: defaultPadding),
      _buildGoogleSignInButton(),
    ];
  }

  /// Builds the email input field.
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.email),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: _validateEmail,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  /// Builds the password input field.
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.lock),
      ),
      obscureText: true,
      validator: _validatePassword,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  /// Builds the submit button (Sign In/Sign Up).
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _submitForm,
        child: Text(
          _isSigningIn ? 'Sign In' : 'Sign Up',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  /// Builds the toggle mode button to switch between Sign In and Sign Up.
  Widget _buildToggleModeButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          _isSigningIn = !_isSigningIn;
          _formKey.currentState?.reset();
          _emailController.clear();
          _passwordController.clear();
        });
      },
      child: Text(
        _isSigningIn
            ? 'Need an account? Sign Up'
            : 'Already have an account? Sign In',
      ),
    );
  }

  /// Builds the Google Sign In button.
  Widget _buildGoogleSignInButton() {
    return ElevatedButton.icon(
      onPressed: _signInWithGoogle,
      icon: Image.network(googleLogoUrl, height: 24.0),
      label: const Text('Sign in with Google'),
      style: ElevatedButton.styleFrom(
        backgroundColor: whiteColor,
        foregroundColor: blackColor,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}
