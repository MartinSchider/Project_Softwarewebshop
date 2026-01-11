// lib/services/order_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/repositories/user_repository.dart';

/// Service responsible for handling the checkout and order completion process.
///
/// This class acts as a bridge between the client-side application and the
/// server-side business logic (Cloud Functions). It handles:
/// 1. Triggering the secure transaction on the server.
/// 2. Managing post-transaction client-side updates (like Fidelity Points).
class OrderService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();

  /// Finalizes the order process.
  ///
  /// This method performs two main actions:
  /// 1. **Server-Side:** Calls the `completeOrder` Cloud Function to handle inventory deduction,
  ///    order document creation, and email confirmation securely.
  /// 2. **Client-Side:** Calculates and assigns loyalty points based on the [cartTotal]
  ///    if the transaction is successful.
  ///
  /// * [customerEmail]: The email address where the confirmation will be sent.
  /// * [cartTotal]: The total value of the cart, used to calculate fidelity points (1 EUR = 1 Point).
  ///
  /// Returns a [Map] containing the result data from the Cloud Function (e.g., success status, order ID).
  /// Throws an [Exception] if the user is not logged in or if the backend process fails.
  Future<Map<String, dynamic>> completeOrder(String customerEmail, double cartTotal) async {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      throw Exception('User not logged in.');
    }

    try {
      // 1. EXECUTE SERVER-SIDE TRANSACTION
      // Call the Firebase Cloud Function 'completeOrder'.
      // This ensures that critical logic (stock management, order creation) happens in a secure, ACID-compliant environment.
      final callable = _functions.httpsCallable('completeOrder');
      final result = await callable.call<Map<String, dynamic>>({
        'email': customerEmail,
        // Note: We pass the email to the server, but the server calculates the total from the DB items for security.
        // The 'cartTotal' passed to this method is primarily for client-side point calculation.
      });

      final data = result.data;

      // 2. LOYALTY PROGRAM UPDATE (Post-Transaction)
      // Once the order is successfully confirmed by the server, we process the rewards.
      try {
        if (cartTotal > 0) {
          // Fetch current profile to check eligibility
          final userProfile = await _userRepository.getUserProfile(userId);
          
          if (userProfile != null && userProfile.isFidelityActive) {
            // Rule: Earn 1 Point for every full Euro spent (floor rounding).
            int pointsEarned = cartTotal.floor();
            
            if (pointsEarned > 0) {
              // Atomically increment points in the user's profile
              await _userRepository.addFidelityPoints(userId, pointsEarned);
              print("SUCCESS: Assigned $pointsEarned points to user (Total: €$cartTotal)");
            }
          }
        }
      } catch (e) {
        // Log fidelity errors silently so they don't block the main order success flow.
        print("ERROR Fidelity: $e");
      }
      
      return data;

    } on FirebaseFunctionsException catch (e) {
      // Handle specific errors returned by the Cloud Function (e.g., 'resource-exhausted').
      throw Exception('Cloud Function Error: ${e.message}');
    } catch (e) {
      // Handle generic errors (network issues, etc.).
      throw Exception('Failed to complete order: $e');
    }
  }
}