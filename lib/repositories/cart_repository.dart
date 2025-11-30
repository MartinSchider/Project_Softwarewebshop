// lib/repositories/cart_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/cart_item.dart';
import 'package:webshop/models/product.dart';

/// Handles data operations for the shopping cart in Firestore.
///
/// This repository acts as the Data Layer, communicating directly with the
/// `carts` collection. It abstracts the complexity of NoSQL data joining
/// (merging cart items with product details) away from the UI and Service layers.
class CartRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns a real-time stream of items in the user's cart.
  ///
  /// This method performs a client-side join:
  /// 1. Listens to the `items` sub-collection for changes (IDs and quantities).
  /// 2. For each item, fetches the full [Product] details using [getProductById].
  ///
  /// * [userId]: The current user's UID.
  /// * [getProductById]: A callback function to fetch product details (avoids circular dependency).
  Stream<List<CartItem>> getCartStream(String userId,
      Future<Product?> Function(String productId) getProductById) {
    return _firestore
        .collection('carts')
        .doc(userId)
        .collection('items')
        .snapshots()
        .asyncMap((snapshot) async {
      // asyncMap is crucial here. Since Firestore is NoSQL, the cart items
      // only store the 'productId', not the name or image.
      // We must asynchronously fetch the full Product object for every item
      // in the cart to display it correctly in the UI.

      final List<CartItem> cartItems = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final productId = data['productId'] as String?;
        final quantity = data['quantity'] as int?;

        if (productId != null && quantity != null) {
          // Fetch fresh product details.
          // This ensures that if a product price changes in the catalog,
          // the user sees the new price in the cart immediately.
          final product = await getProductById(productId);

          if (product != null) {
            cartItems.add(CartItem(
              id: doc.id,
              product: product,
              quantity: quantity,
            ));
          }
        }
      }
      return cartItems;
    });
  }

  /// Adds a new item or updates an existing one in the cart.
  ///
  /// * [userId]: The owner of the cart.
  /// * [productId]: The item to add.
  /// * [quantity]: The new total quantity.
  Future<void> addOrUpdateCartItem(
      String userId, String productId, int quantity) async {
    final cartRef = _firestore.collection('carts').doc(userId);
    final itemRef = cartRef.collection('items').doc(productId);

    // We ensure the parent document exists by setting the ownerUID.
    // Using merge: true prevents overwriting other fields (like appliedGiftCardCode)
    // if the document already exists.
    await cartRef.set({'ownerUID': userId}, SetOptions(merge: true));

    await itemRef.set({
      'productId': productId,
      'quantity': quantity,
      // Storing a timestamp helps with sorting or debugging order history later.
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes a single item from the cart.
  Future<void> removeCartItem(String userId, String cartItemId) async {
    await _firestore
        .collection('carts')
        .doc(userId)
        .collection('items')
        .doc(cartItemId)
        .delete();
  }

  /// Updates the total price and item count in the parent cart document.
  ///
  /// **Why is this needed?**
  /// While the app calculates totals locally for UI speed, we MUST sync these
  /// totals to the database so that Cloud Functions (like Gift Card validation)
  /// can read the correct amount server-side.
  Future<void> updateCartTotals(
      String userId, double totalPrice, int itemCount) async {
    await _firestore.collection('carts').doc(userId).set({
      'totalPrice': totalPrice,
      // We reset finalAmountToPay to totalPrice initially.
      // If a gift card is applied, the Cloud Function will recalculate this later.
      'finalAmountToPay': totalPrice,
      'itemCount': itemCount,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Deletes all items from the cart (e.g., after a successful purchase).
  ///
  /// This uses a [WriteBatch] to ensure atomicity: either all items are deleted,
  /// or none are (in case of network failure). It also resets the totals.
  Future<void> clearCart(String userId) async {
    final batch = _firestore.batch();
    final itemsSnapshot = await _firestore
        .collection('carts')
        .doc(userId)
        .collection('items')
        .get();

    // Queue up deletes for every item
    for (final doc in itemsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Reset the parent document totals
    final cartRef = _firestore.collection('carts').doc(userId);
    batch.set(
        cartRef,
        {
          'totalPrice': 0.0,
          'itemCount': 0,
          'finalAmountToPay': 0.0,
          'giftCardAppliedAmount': 0.0,
          'ownerUID': userId
        },
        SetOptions(merge: true));

    // Commit all changes at once
    await batch.commit();
  }

  /// Fetches the cart items once without setting up a listener.
  ///
  /// Useful for internal logic (like calculating totals before a sync) where
  /// a continuous stream is not required.
  Future<List<CartItem>> getCartOnce(String userId,
      Future<Product?> Function(String productId) getProductById) async {
    final snapshot = await _firestore
        .collection('carts')
        .doc(userId)
        .collection('items')
        .get();
    final List<CartItem> cartItems = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final productId = data['productId'] as String?;
      final quantity = data['quantity'] as int?;

      if (productId != null && quantity != null) {
        final product = await getProductById(productId);
        if (product != null) {
          cartItems.add(CartItem(
            id: doc.id,
            product: product,
            quantity: quantity,
          ));
        }
      }
    }
    return cartItems;
  }

  /// Streams the raw metadata of the cart (totals, gift card codes).
  ///
  /// This listens to the parent `carts/{userId}` document, separate from the items.
  Stream<Map<String, dynamic>> getCartDetailsStream(String userId) {
    return _firestore.collection('carts').doc(userId).snapshots().map((doc) {
      return doc.data() ?? {};
    });
  }
}
