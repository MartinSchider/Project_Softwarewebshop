// lib/checkout_shipping_page.dart
import 'package:flutter/material.dart';
import 'package:webshop/checkout_payment_page.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/models/app_user.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/utils/ui_helper.dart';

/// The second step of the checkout process: Shipping Information.
///
/// This form captures the user's physical address. It attempts to pre-fill
/// data from the existing user profile (if available) to speed up checkout.
class CheckoutShippingPage extends StatefulWidget {
  const CheckoutShippingPage({super.key});

  @override
  State<CheckoutShippingPage> createState() => _CheckoutShippingPageState();
}

class _CheckoutShippingPageState extends State<CheckoutShippingPage> {
  // GlobalKey needed to validate the form fields before saving.
  final _formKey = GlobalKey<FormState>();

  // Controllers to manage the text input for each field.
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _addressController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _cityController = TextEditingController();

  final AuthService _authService = AuthService();

  // Cache the user profile to modify it safely before saving.
  AppUser? _currentUserProfile;

  // Indicates if a save or load operation is in progress.
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Fetch existing data as soon as the screen loads.
    _loadShippingDetails();
  }

  @override
  void dispose() {
    // Dispose all controllers to free up resources.
    _nameController.dispose();
    _surnameController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Fetches the user's profile from Firestore and pre-fills the form fields.
  Future<void> _loadShippingDetails() async {
    setState(() => _isLoading = true);
    try {
      final userProfile = await _authService.getAppUserProfileOnce();
      if (userProfile != null && mounted) {
        setState(() {
          _currentUserProfile = userProfile;
          // Pre-fill fields with fallback to empty string if null
          _nameController.text = userProfile.name ?? '';
          _surnameController.text = userProfile.surname ?? '';
          _addressController.text = userProfile.address ?? '';
          _postcodeController.text = userProfile.postcode ?? '';
          _cityController.text = userProfile.city ?? '';
        });
      }
    } catch (e) {
      // If loading fails, we just leave fields empty.
      // In debug mode, we log the error.
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Persists the entered shipping details to the user's Firestore profile.
  ///
  /// This ensures that the next time the user checks out, they don't have
  /// to re-enter the same address.
  Future<void> _saveShippingDetails() async {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not logged in.');

    // Create a new AppUser object (or copy existing) with updated fields.
    // We trim() inputs to remove accidental whitespace.
    final updatedUserProfile =
        (_currentUserProfile ?? AppUser(id: userId)).copyWith(
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
      address: _addressController.text.trim(),
      postcode: _postcodeController.text.trim(),
      city: _cityController.text.trim(),
    );

    await _authService.saveAppUserProfile(updatedUserProfile);
  }

  /// Validates inputs, saves data, and navigates to the Payment step.
  void _processCheckout() async {
    // 1. Run all validators. If any fail, stop here.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 2. Save data to Firestore
      await _saveShippingDetails();

      // 3. Navigate to Payment Page
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const CheckoutPaymentPage()),
        );
      }
    } catch (e) {
      // Use centralized UI helper for error handling
      if (mounted) {
        UiHelper.showError(context, 'Failed to save shipping details: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping Information'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Form(
                key: _formKey, // Connect validation key
                child: ListView(
                  children: [
                    // --- Name Fields ---
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization:
                          TextCapitalization.words, // Auto-capitalize names
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _surnameController,
                      decoration: const InputDecoration(labelText: 'Surname'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your surname'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Address Fields ---
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      textCapitalization: TextCapitalization
                          .sentences, // Addresses often start with numbers/sentences
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your address'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _postcodeController,
                      decoration: const InputDecoration(labelText: 'Postcode'),
                      keyboardType:
                          TextInputType.number, // Optimize keyboard for digits
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your postcode'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your city'
                          : null,
                    ),
                    const SizedBox(height: 32),

                    // --- Proceed Button ---
                    ElevatedButton(
                      onPressed: _processCheckout,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        'Proceed to Payment',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
