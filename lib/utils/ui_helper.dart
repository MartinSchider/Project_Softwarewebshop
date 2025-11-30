// lib/utils/ui_helper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/utils/constants.dart';

/// A utility class for centralized UI feedback logic.
///
/// This class ensures a consistent look and feel for alerts, errors, and loading
/// indicators across the entire application. By centralizing this logic,
/// we avoid code duplication and make global style changes easier.
class UiHelper {
  /// Displays a standardized error message using a [SnackBar].
  ///
  /// This method automatically parses the [error] object to provide
  /// the most human-readable message possible.
  ///
  /// * [context]: The BuildContext, required to find the ScaffoldMessenger.
  /// * [error]: The exception object or string to display.
  static void showError(BuildContext context, dynamic error) {
    // SECURITY CHECK:
    // If the widget is no longer in the tree (e.g., user navigated away),
    // calling ScaffoldMessenger would throw an error. We exit early to prevent this.
    if (!context.mounted) return;

    String message = 'An unknown error occurred.';

    // ERROR PARSING LOGIC:
    // Instead of showing raw stack traces or generic "Error", we try to extract
    // user-friendly messages, especially from Firebase Authentication.
    if (error is FirebaseAuthException) {
      // Firebase provides specific messages (e.g., "Password is too weak").
      message = error.message ?? message;
    } else if (error is Exception) {
      // Standard exceptions often start with "Exception: ...".
      // We strip this prefix to make the UI look cleaner.
      message = error.toString().replaceAll('Exception: ', '');
    } else {
      // Fallback for strings or other types.
      message = error.toString();
    }

    // Hide any previous snackbars to ensure the new error is seen immediately
    // without waiting for the queue to clear.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            // Expanded ensures the text wraps correctly if it's too long.
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior
            .floating, // Floating looks more modern than fixed at bottom
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration:
            const Duration(seconds: 4), // Give users enough time to read errors
      ),
    );
  }

  /// Displays a standardized success message using a [SnackBar].
  ///
  /// Use this for feedback like "Added to cart" or "Profile updated".
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(
            seconds: 2), // Shorter duration for success is less intrusive
      ),
    );
  }

  /// Shows a blocking loading dialog.
  ///
  /// This prevents user interaction while a critical async operation is in progress
  /// (like signing in or placing an order).
  ///
  /// **Note:** You must manually call `Navigator.of(context).pop()` to dismiss this dialog.
  static void showLoading(BuildContext context) {
    showDialog(
      context: context,
      // Prevents the user from dismissing the dialog by tapping outside.
      // This forces them to wait for the operation to complete.
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }
}
