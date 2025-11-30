// lib/widgets/error_retry_widget.dart
import 'package:flutter/material.dart';
import 'package:webshop/utils/constants.dart';

/// A reusable widget to display error states with a retry mechanism.
///
/// This widget is designed to be used within [FutureBuilder], [StreamBuilder],
/// or Riverpod's `.when(error: ...)` blocks. It solves the "Silent Failure"
/// and "No Error Recovery" issues by providing a clear visual cue and an
/// actionable button to attempt the operation again.
class ErrorRetryWidget extends StatelessWidget {
  /// The technical or user-facing error message to display.
  final String errorMessage;

  /// The callback function to trigger when the user clicks "Try Again".
  /// Typically, this triggers a `ref.refresh(provider)` or a `setState` rebuild.
  final VoidCallback onRetry;

  /// Creates an [ErrorRetryWidget].
  const ErrorRetryWidget({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Visual cue for connectivity/data issues (Gray cloud icon)
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),

            // Generic friendly title to reassure the user
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Specific error details (Red text to indicate alert state)
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),

            // Actionable button to recover from the error
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
