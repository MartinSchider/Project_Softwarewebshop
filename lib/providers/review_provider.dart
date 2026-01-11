// lib/providers/review_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/models/review.dart';
import 'package:webshop/repositories/review_repository.dart';

/// Provides a global instance of the [ReviewRepository].
///
/// This provider acts as a **Dependency Injection** point for the review data layer.
/// By reading this provider, other providers (like [productReviewsProvider]) or widgets
/// can access the repository methods without instantiating it directly.
/// This makes testing easier, as you can override this provider with a mock repository.
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

/// A Stream provider that fetches and listens to the list of reviews for a specific product.
///
/// This provider uses the `.family` modifier, allowing it to accept a parameter
/// (in this case, the `productId` [String]) to create a unique stream for each product.
///
/// * **Mechanism:**
/// 1. It watches the [reviewRepositoryProvider] to get the repository instance.
/// 2. It calls [getReviewsStream] with the provided [productId].
/// 3. It returns a [Stream] of [List<Review>].
///
/// * **Usage in UI:**
/// Widgets can watch this provider (e.g., `ref.watch(productReviewsProvider(productId))`)
/// to automatically rebuild whenever a new review is added or updated in Firestore.
final productReviewsProvider = StreamProvider.family<List<Review>, String>((ref, productId) {
  // Retrieve the repository instance.
  final repository = ref.watch(reviewRepositoryProvider);
  
  // Return the live stream of reviews for the requested product.
  return repository.getReviewsStream(productId);
});