// lib/services/cart_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:webshop/models/cart_item.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/cart_repository.dart';
import 'package:webshop/repositories/product_repository.dart';

/// Manages the business logic for the shopping cart.
///
/// This service acts as the orchestrator between the UI, the Firestore Database
/// (via Repositories), and Cloud Functions (for complex logic like Gift Cards).
///
/// It handles:
/// - Stock validation before adding items.
/// - Synchronization of totals between Client and Server.
/// - Secure execution of Cloud Functions.
class CartService {
  final CartRepository _cartRepository = CartRepository();
  final ProductRepository _productRepository = ProductRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Helper getter to retrieve the current authenticated user ID.
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Provides a real-time stream of the cart items.
  ///
  /// Used by the UI to display the product list.
  Stream<List<CartItem>> getCartStream() {
    final userId = _currentUserId;
    // Graceful fallback: If no user is logged in, return an empty stream
    // instead of throwing an error, preventing UI crashes on logout.
    if (userId == null) {
      return Stream.value([]);
    }
    // Dependency Injection: We pass the product fetcher to the cart repository
    // to allow it to "join" cart data with product data efficiently.
    return _cartRepository.getCartStream(
        userId, _productRepository.getProductById);
  }

  /// Provides a stream of raw cart metadata (e.g., total price, applied codes).
  Stream<Map<String, dynamic>> getCartDetailsStream() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value({});
    }
    return _cartRepository.getCartDetailsStream(userId);
  }

  /// INTERNAL HELPER: Calculates totals locally and saves them to Firestore.
  ///
  /// **Why is this necessary?**
  /// While the Flutter app calculates totals in real-time for the UI (speed),
  /// the server-side Cloud Functions (which verify Gift Cards) need to read
  /// the *current* cart total from the database to ensure the discount is valid.
  /// This function bridges that gap by syncing the client's calculation to the DB.
  Future<void> _syncCartTotals(String userId) async {
    // 1. Fetch the latest state of items
    final items = await _cartRepository.getCartOnce(
        userId, _productRepository.getProductById);

    // 2. Calculate mathematical total
    double total = 0.0;
    for (var item in items) {
      total += item.product.price * item.quantity;
    }

    // 3. Persist to DB so Cloud Functions can read it
    await _cartRepository.updateCartTotals(userId, total, items.length);
  }

  /// Adds a [product] to the cart or updates its quantity if it already exists.
  ///
  /// * [quantity]: The number of items to add (usually 1).
  Future<void> addProductToCart(Product product, int quantity) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    // We use an "Upsert" strategy in the repository: if the item exists,
    // it merges the data; if not, it creates it.
    await _cartRepository.addOrUpdateCartItem(userId, product.id, quantity);

    // Sync triggers immediately to ensure DB totals are correct for checkout
    await _syncCartTotals(userId);
  }

  /// Completely removes a specific item type from the cart.
  Future<void> removeCartItem(String cartItemId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not logged in.');
    }
    await _cartRepository.removeCartItem(userId, cartItemId);
    await _syncCartTotals(userId); // Re-calculate totals after removal
  }

  /// Updates the quantity of a specific cart item.
  ///
  /// Includes business logic validation:
  /// 1. If [newQuantity] is <= 0, the item is removed.
  /// 2. Checks current stock availability before updating.
  Future<void> updateCartItemQuantity(
      String cartItemId, int newQuantity) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    // Business Logic: Zero quantity means deletion
    if (newQuantity <= 0) {
      await removeCartItem(cartItemId);
      return;
    }

    // Fetch product to check stock
    final product = await _productRepository.getProductById(cartItemId);
    if (product == null) {
      throw Exception('Product not found for cart item $cartItemId');
    }

    // Business Logic: Stock Validation
    if (product.stock < newQuantity) {
      throw Exception(
          'Not enough stock for ${product.name}. Available: ${product.stock}. Requested: $newQuantity');
    }

    await _cartRepository.addOrUpdateCartItem(userId, cartItemId, newQuantity);
    await _syncCartTotals(userId); // Keep DB in sync
  }

  /// Clears the entire cart (e.g., after logout or emptying cart).
  Future<void> clearCart() async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not logged in.');
    }
    await _cartRepository.clearCart(userId);
  }

  /// Fetches the cart items once (non-stream).
  Future<List<CartItem>> getCartOnce() async {
    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }
    return _cartRepository.getCartOnce(
        userId, _productRepository.getProductById);
  }

  /// Calls a Firebase Cloud Function to validate and apply a Gift Card.
  ///
  /// * [giftCardCode]: The alphanumeric code entered by the user.
  ///
  /// Returns a Map containing the result (success status, new totals).
  Future<Map<String, dynamic>> applyGiftCard(String giftCardCode) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    // CRITICAL: Force a sync before calling the Cloud Function.
    // This ensures the server sees the most up-to-date cart total before
    // attempting to apply a discount.
    await _syncCartTotals(userId);

    try {
      final callable = _functions.httpsCallable('applyGiftCard');
      final result = await callable.call<Map<String, dynamic>>({
        'giftCardCode': giftCardCode,
        'cartId': userId,
      });

      // We use Map.from() to safely convert the result.
      // Direct casting or using '?? {}' can fail if the returned map type
      // doesn't strictly match <String, dynamic>.
      return Map<String, dynamic>.from(result.data ?? {});
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Gift Card Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to apply gift card: $e');
    }
  }

  /// Calls a Firebase Cloud Function to remove an applied Gift Card.
  Future<Map<String, dynamic>> removeGiftCard() async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    try {
      final callable = _functions.httpsCallable('removeGiftCard');
      final result = await callable.call<Map<String, dynamic>>({
        'cartId': userId,
      });

      // Safely cast the response
      return Map<String, dynamic>.from(result.data ?? {});
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Gift Card Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to remove gift card: $e');
    }
  }
}
