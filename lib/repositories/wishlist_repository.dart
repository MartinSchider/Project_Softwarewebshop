// lib/repositories/wishlist_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles data operations for the user's wishlist in Firestore.
///
/// This repository manages the `wishlist` sub-collection under the user's document.
/// It focuses on managing references (IDs) to products rather than duplicating
/// product data, ensuring the wishlist stays lightweight.
class WishlistRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns a real-time stream of product IDs from the user's wishlist.
  ///
  /// **Performance Optimization:**
  /// We intentionally fetch only the document IDs (which correspond to Product IDs)
  /// rather than full documents. This reduces bandwidth usage since the full
  /// product details are likely already cached or available in the main product list.
  Stream<List<String>> getWishlistIdsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Adds a specific product to the user's wishlist.
  ///
  /// We store the `addedAt` timestamp to potentially allow sorting by "Recently Added"
  /// in the future UI.
  Future<void> addToWishlist(String userId, String productId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .doc(productId)
        .set({
      'productId': productId,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a product from the user's wishlist.
  Future<void> removeFromWishlist(String userId, String productId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .doc(productId)
        .delete();
  }
}
