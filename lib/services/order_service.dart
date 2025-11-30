// lib/services/order_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages the order placement process.
///
/// This service handles the critical "checkout" action. Unlike other data operations
/// (like adding to cart) which happen directly on Firestore from the client,
/// order completion is delegated to a server-side Cloud Function.
class OrderService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Finalizes the user's current cart into a permanent order.
  ///
  /// This method triggers the `completeOrder` Cloud Function which securely:
  /// 1. Verifies stock availability one last time.
  /// 2. Calculates the final total (preventing client-side price tampering).
  /// 3. Moves items from 'cart' to 'orders' collection.
  /// 4. Sends a confirmation email to [customerEmail].
  ///
  /// Returns a [Map] containing the `orderId` and `finalAmountPaid` on success.
  /// Throws an [Exception] if the user is not logged in or the function fails.
  Future<Map<String, dynamic>> completeOrder(String customerEmail) async {
    final userId = _auth.currentUser?.uid;

    // Security check: We need the UID to ensure the function operates on the correct cart.
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    try {
      // Call the server-side function.
      // We pass the email explicitly to ensure the confirmation goes to the
      // currently desired address (which might differ from the auth email).
      final callable = _functions.httpsCallable('completeOrder');
      final result = await callable.call<Map<String, dynamic>>({
        'email': customerEmail,
      });

      // The result.data is guaranteed to be a Map by the Cloud Function response structure,
      // but we let Dart infer the type or cast it if strictly necessary downstream.
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // Handle specific Cloud Function errors (e.g., "Out of Stock", "Payment Failed").
      throw Exception('Cloud Function Error: ${e.message}');
    } catch (e) {
      // Handle generic network or parsing errors.
      throw Exception('Failed to complete order: $e');
    }
  }
}
