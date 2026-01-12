// lib/services/cart_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:webshop/models/cart_item.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/cart_repository.dart';
import 'package:webshop/repositories/product_repository.dart';

/// Service responsible for the business logic of the shopping cart.
///
/// This class acts as a coordinator between the data layer ([CartRepository]),
/// the product catalog ([ProductRepository]), and server-side logic ([FirebaseFunctions]).
/// It enforces rules like stock validation and ensures data consistency between
/// the client and the server.
class CartService {
  final CartRepository _cartRepository;
  final ProductRepository _productRepository;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  /// Allows injecting repositories/auth/functions for testing purposes.
  CartService({CartRepository? cartRepository, ProductRepository? productRepository, FirebaseAuth? auth, FirebaseFunctions? functions})
      : _cartRepository = cartRepository ?? CartRepository(),
        _productRepository = productRepository ?? ProductRepository(),
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Helper to get the authenticated user's ID safely.
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Returns a stream of cart items for the current user.
  ///
  /// This stream is used by the UI to display the list of products in the cart.
  /// It automatically handles joining product details with cart quantities.
  Stream<List<CartItem>> getCartStream() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);
    return _cartRepository.getCartStream(
        userId, _productRepository.getProductById);
  }

  /// Returns a stream of cart metadata (totals, applied codes).
  ///
  /// Separated from [getCartStream] to allow the UI to listen to price changes
  /// without re-rendering the entire list of items.
  Stream<Map<String, dynamic>> getCartDetailsStream() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value({});
    return _cartRepository.getCartDetailsStream(userId);
  }

  /// Recalculates the cart total locally and updates Firestore.
  ///
  /// **Reasoning:**
  /// While Cloud Functions also calculate totals, updating them from the client
  /// provides immediate UI feedback (optimistic UI) and ensures that even if
  /// the Cloud Function is slow, the user sees a reasonably accurate total.
  Future<void> _syncCartTotals(String userId) async {
    final items = await _cartRepository.getCartOnce(
        userId, _productRepository.getProductById);

    double total = 0.0;
    for (var item in items) {
      total += item.product.price * item.quantity;
    }

    await _cartRepository.updateCartTotals(userId, total, items.length);
  }

  /// Adds a specific quantity of a [product] to the cart.
  ///
  /// This method performs a read-before-write operation to:
  /// 1. Check if the product is already in the cart.
  /// 2. Validate that the *total* projected quantity does not exceed available stock.
  Future<void> addProductToCart(Product product, int quantityToAdd) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in.');

    // We need the current state to determine if this is a new item or an increment to an existing one.
    final currentCart = await _cartRepository.getCartOnce(
        userId, _productRepository.getProductById);

    // Calculate existing quantity safely.
    int currentQuantityInCart = 0;
    try {
      final existingItem = currentCart.firstWhere(
        (item) => item.product.id == product.id,
      );
      currentQuantityInCart = existingItem.quantity;
    } catch (_) {
      // Item not found in cart, so we treat it as a new addition (0 initial quantity).
    }

    final int newTotalQuantity = currentQuantityInCart + quantityToAdd;

    // Stock Validation: Prevent adding more items than physically available.
    if (newTotalQuantity > product.stock) {
      throw Exception(
          'Cannot add $quantityToAdd items. You already have $currentQuantityInCart in cart and stock is only ${product.stock}.');
    }

    // Persist the change.
    // We pass the full [product] object to ensure that the denormalized data
    // in the cart (name, price, image) is updated to the latest version from the catalog.
    await _cartRepository.addOrUpdateCartItem(
        userId, product, newTotalQuantity);

    await _syncCartTotals(userId);
  }

  /// Removes a single item type from the cart entirely.
  Future<void> removeCartItem(String cartItemId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in.');
    await _cartRepository.removeCartItem(userId, cartItemId);
    await _syncCartTotals(userId);
  }

  /// Updates the quantity of an existing cart item.
  ///
  /// If [newQuantity] is zero or less, the item is removed.
  /// Otherwise, it verifies stock before updating.
  Future<void> updateCartItemQuantity(
      String cartItemId, int newQuantity) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in.');

    // Handle removal logic explicitly here to simplify the UI code.
    if (newQuantity <= 0) {
      await removeCartItem(cartItemId);
      return;
    }

    // We must fetch the fresh product data to check the current stock level,
    // as the cached version in the cart might be stale.
    final product = await _productRepository.getProductById(cartItemId);
    if (product == null) {
      throw Exception('Product not found for cart item $cartItemId');
    }

    if (product.stock < newQuantity) {
      throw Exception(
          'Not enough stock for ${product.name}. Available: ${product.stock}. Requested: $newQuantity');
    }

    // Update with full product details to keep cart snapshots fresh.
    await _cartRepository.addOrUpdateCartItem(userId, product, newQuantity);
    await _syncCartTotals(userId);
  }

  /// Clears all items from the cart.
  ///
  /// Typically called after a successful order or when the user manually empties the cart.
  Future<void> clearCart() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in.');
    await _cartRepository.clearCart(userId);
  }

  /// Fetches a one-time snapshot of the cart.
  ///
  /// Useful for internal logic where a stream is overkill (e.g., calculating totals
  /// before checkout).
  Future<List<CartItem>> getCartOnce() async {
    final userId = _currentUserId;
    if (userId == null) return [];
    return _cartRepository.getCartOnce(
        userId, _productRepository.getProductById);
  }

  /// Applies a gift card code to the cart.
  ///
  /// This operation is delegated to a Cloud Function (`applyGiftCard`) because
  /// it involves sensitive validation (balance checks, expiry) that cannot be
  /// securely handled on the client side.
  Future<Map<String, dynamic>> applyGiftCard(String giftCardCode) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in.');

    // Sync totals first to ensure the Cloud Function has the most up-to-date
    // cart value to calculate the discount against.
    await _syncCartTotals(userId);

    try {
      final callable = _functions.httpsCallable('applyGiftCard');
      final result = await callable.call<Map<String, dynamic>>({
        'giftCardCode': giftCardCode,
        'cartId': userId,
      });
      return Map<String, dynamic>.from(result.data as Map<String, dynamic>);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Gift Card Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to apply gift card: $e');
    }
  }

  /// Removes the currently applied gift card.
  ///
  /// Delegates to a Cloud Function (`removeGiftCard`) to ensure the balance is
  /// correctly refunded to the gift card document in the database.
  Future<Map<String, dynamic>> removeGiftCard() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in.');

    try {
      final callable = _functions.httpsCallable('removeGiftCard');
      final result = await callable.call<Map<String, dynamic>>({
        'cartId': userId,
      });
      return Map<String, dynamic>.from(result.data as Map<String, dynamic>);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Gift Card Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to remove gift card: $e');
    }
  }
}
