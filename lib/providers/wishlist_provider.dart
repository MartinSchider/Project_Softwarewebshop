// lib/providers/wishlist_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/repositories/wishlist_repository.dart';

/// Provides a singleton instance of the [WishlistRepository].
///
/// This ensures consistent access to the data layer across the application.
final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository();
});

/// Provides a real-time stream of product IDs in the current user's wishlist.
///
/// **Why a Stream?**
/// This allows the UI (like heart icons on product cards) to update immediately
/// if the wishlist changes from another device or a different part of the app.
///
/// Returns an empty list if the user is not authenticated.
final wishlistIdsProvider = StreamProvider<List<String>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  
  // Security/Logic Check: We cannot fetch a wishlist without a User ID.
  // Returning an empty stream is safer than throwing an error here.
  if (user == null) return Stream.value([]);
  
  final repo = ref.watch(wishlistRepositoryProvider);
  return repo.getWishlistIdsStream(user.uid);
});

/// A controller class to handle write operations (Add/Remove) for the wishlist.
///
/// It separates the business logic of modifying data from the UI code.
class WishlistController {
  final WishlistRepository _repo;
  
  WishlistController(this._repo);

  /// Placeholder for a server-side toggle (currently unused).
  ///
  /// **Architectural Note:**
  /// We usually handle the "toggle" logic in the UI (e.g., `product_card.dart`)
  /// because the UI already knows the current state (isFavorite).
  /// Passing that state to `add` or `remove` directly is more efficient than
  /// reading the database again here just to decide which action to take.
  Future<void> toggleWishlist(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    // Implementation deferred in favor of explicit add/remove calls from UI.
  }

  /// Adds a specific product to the authenticated user's wishlist.
  Future<void> add(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    await _repo.addToWishlist(user.uid, productId);
  }

  /// Removes a specific product from the authenticated user's wishlist.
  Future<void> remove(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    await _repo.removeFromWishlist(user.uid, productId);
  }
}

/// Provides the [WishlistController] to the widget tree.
final wishlistControllerProvider = Provider<WishlistController>((ref) {
  return WishlistController(ref.watch(wishlistRepositoryProvider));
});