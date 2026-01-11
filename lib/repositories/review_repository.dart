// lib/repositories/review_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/review.dart';

/// Handles data operations related to product reviews.
///
/// This repository manages the interaction with Firestore for:
/// * Fetching the list of reviews for a specific product.
/// * Adding new reviews while maintaining data consistency.
/// * Verifying if a user is eligible to review a product based on purchase history.
class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Provides a real-time stream of reviews for a given [productId].
  ///
  /// * **Ordering:** Reviews are sorted by `timestamp` in descending order (newest first).
  /// * **Real-time:** The stream emits a new list whenever a review is added or modified.
  Stream<List<Review>> getReviewsStream(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Review.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Adds a new review and atomically updates the product's rating statistics.
  ///
  /// This method uses a **Firestore Transaction** to ensure data integrity.
  /// It performs two operations as a single atomic unit:
  /// 1. Adds the review document to the `reviews` subcollection.
  /// 2. Recalculates and updates the `averageRating` and `reviewCount` fields on the parent product document.
  ///
  /// This prevents race conditions where multiple users reviewing simultaneously
  /// could lead to incorrect averages.
  Future<void> addReview(String productId, Review review) async {
    final productRef = _firestore.collection('products').doc(productId);
    final reviewRef = productRef.collection('reviews').doc(); // Auto-generate ID

    await _firestore.runTransaction((transaction) async {
      // 1. Read: Fetch current product data to get existing stats.
      final productSnapshot = await transaction.get(productRef);
      if (!productSnapshot.exists) {
        throw Exception("Product not found");
      }

      final data = productSnapshot.data() as Map<String, dynamic>;
      
      // Retrieve current values, handling nulls for new products (default to 0).
      final double currentAverage = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
      final int currentCount = (data['reviewCount'] as int?) ?? 0;

      // 2. Calculate: Compute the new aggregate values.
      final int newCount = currentCount + 1;
      
      // Cumulative Moving Average formula:
      // New Average = ((Old Average * Old Count) + New Rating) / New Count
      final double newAverage = ((currentAverage * currentCount) + review.rating) / newCount;

      // 3. Write: Save the new review to the subcollection.
      transaction.set(reviewRef, review.toMap());

      // 4. Update: Write the new stats back to the parent product document.
      transaction.update(productRef, {
        'averageRating': newAverage,
        'reviewCount': newCount,
      });
    });
  }

  /// Verifies if a specific user has purchased a specific product.
  ///
  /// Used to enforce "Verified Purchase" restrictions on reviews.
  /// It queries the `orders` collection for the user's history and checks
  /// if the [productId] exists within the items of any order.
  ///
  /// Returns `true` if a matching order item is found, otherwise `false`.
  Future<bool> hasUserPurchasedProduct(String userId, String productId) async {
    try {
      // Query all orders belonging to the user.
      final querySnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      // Iterate through orders to find the product.
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        
        // Check if the product ID exists in this order's items list.
        if (items.any((item) => item['productId'] == productId)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      // Fail safely by returning false on error.
      return false;
    }
  }
}