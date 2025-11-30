// lib/models/cart_item.dart
import 'package:flutter/foundation.dart';
import 'package:webshop/models/product.dart';

/// Represents a single item within the shopping cart.
///
/// This model links a specific [Product] with a selected [quantity].
/// It is marked as [immutable] to ensure state consistency within providers.
@immutable
class CartItem {
  /// Unique identifier for this cart item (typically matches the [Product.id]).
  final String id;

  /// The full product details associated with this item.
  ///
  /// We store the full object here to allow immediate access to price,
  /// image, and name without needing additional lookups during UI rendering.
  final Product product;

  /// The number of units of this product currently in the cart.
  final int quantity;

  /// Creates a constant [CartItem].
  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
  });

  /// Factory constructor to create a [CartItem] from Firestore data.
  ///
  /// Note: The [product] object must be fetched separately (e.g., from a
  /// ProductRepository) and passed here. The cart collection in Firestore
  /// typically only stores the `quantity` and `productId`, not the full product details.
  ///
  /// * [data]: The map containing cart specific data (e.g., quantity).
  /// * [id]: The document ID of the cart item.
  /// * [product]: The fully resolved product object.
  factory CartItem.fromMap(
      Map<String, dynamic> data, String id, Product product) {
    return CartItem(
      id: id,
      product: product,
      // Safety check: default to 0 if quantity is missing or null to prevent UI crashes.
      quantity: (data['quantity'] as int?) ?? 0,
    );
  }

  /// Converts the [CartItem] to a [Map] for database persistence.
  ///
  /// We intentionally only store the `productId` and `quantity`.
  /// Storing the full product details here would lead to data duplication
  /// and synchronization issues if the product's price or name changes later.
  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'quantity': quantity,
    };
  }

  /// Creates a copy of this [CartItem] with updated fields.
  ///
  /// Useful for updating the quantity without mutating the original instance.
  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
