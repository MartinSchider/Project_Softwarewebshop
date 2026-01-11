// lib/pages/fidelity_card_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/models/app_user.dart';
import 'package:webshop/repositories/user_repository.dart';
import 'package:webshop/providers/user_provider.dart'; 
import 'package:webshop/utils/constants.dart';
import 'package:webshop/utils/ui_helper.dart';

/// A screen that manages and displays the user's Loyalty Program status.
///
/// This widget uses [ConsumerStatefulWidget] to interact with Riverpod providers.
/// It observes the [userProfileProvider] to reactively update the UI based on
/// changes in the user's profile data (e.g., points balance or activation status).
///
/// * If the user has an active fidelity card, it displays the card and points.
/// * If not, it provides a call-to-action to join the program.
class FidelityCardPage extends ConsumerStatefulWidget {
  const FidelityCardPage({super.key});

  @override
  ConsumerState<FidelityCardPage> createState() => _FidelityCardPageState();
}

class _FidelityCardPageState extends ConsumerState<FidelityCardPage> {
  final UserRepository _userRepo = UserRepository();
  
  // Retrieve the current authenticated user ID directly from Firebase Auth.
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    // 1. Safety check: Ensure the user is logged in before rendering.
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text("Login required")),
      );
    }

    // 2. Watch the user profile provider.
    // This establishes a listener that rebuilds this widget whenever the
    // user's data (stream) emits a new value (e.g., points update).
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Fidelity Card")),
      // 3. Handle the AsyncValue states (Loading, Error, Data).
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (user) {
          if (user == null) return const Center(child: Text("User not found"));

          // 4. Conditional Rendering based on Fidelity Status.
          if (user.isFidelityActive) {
            return _buildActiveCardView(context, user);
          }
          return _buildJoinView(context);
        },
      ),
    );
  }

  /// Builds the view for users who are already members of the loyalty program.
  ///
  /// Displays a digital card with the user's name, points balance, and a visual gradient.
  Widget _buildActiveCardView(BuildContext context, AppUser user) {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        children: [
          // --- Digital Card Container ---
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              // Create a premium look using the primary theme color.
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
              ],
            ),
            child: Stack(
              children: [
                // Card Header
                Positioned(
                  top: 20, left: 20,
                  child: Text(
                    "Fidelity Member", 
                    style: TextStyle(color: whiteColor.withOpacity(0.8), fontSize: 16)
                  ),
                ),
                // Card Holder Name & Dummy Number
                Positioned(
                  bottom: 20, left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name?.toUpperCase() ?? "CUSTOMER", 
                        style: const TextStyle(color: whiteColor, fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                      const Text("**** **** **** 1234", style: TextStyle(color: whiteColor, fontSize: 14)),
                    ],
                  ),
                ),
                // Decorative Icon
                const Positioned(
                  right: 20, top: 20,
                  child: Icon(Icons.stars, color: Colors.amber, size: 40),
                ),
                // Points Balance Display
                Positioned(
                  right: 20, bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Points Balance", style: TextStyle(color: whiteColor, fontSize: 12)),
                      Text(
                        "${user.fidelityPoints}", 
                        style: const TextStyle(color: whiteColor, fontSize: 32, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Informational Text
          const Text(
            "Earn 1 point for every euro spent!",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Builds the view for users who have not yet activated the fidelity card.
  ///
  /// Provides a call-to-action button to activate the service via the [UserRepository].
  Widget _buildJoinView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.card_giftcard, size: 100, color: Colors.indigo),
          const SizedBox(height: 24),
          Text(
            "Join our Fidelity Program!", 
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 16),
          const Text(
            "Get rewarded for your shopping. Join now and earn 1 point for every €1 you spend.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          
          // --- Activation Button ---
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                // Show loading indicator to prevent double clicks
                UiHelper.showLoading(context);
                try {
                  // Perform the activation on the backend via Repository
                  await _userRepo.activateFidelity(userId!);
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Dismiss loading dialog
                    UiHelper.showSuccess(context, "Welcome to the club!");
                    // Note: The UI will automatically update because the Provider watches the database stream.
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Dismiss loading dialog
                    UiHelper.showError(context, e);
                  }
                }
              },
              child: const Text("Activate Card Free"),
            ),
          ),
        ],
      ),
    );
  }
}