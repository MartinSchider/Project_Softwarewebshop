// lib/models/order.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/cart_item.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/utils/constants.dart';

/// Represents a completed customer order.
///
/// This model stores the snapshot of the transaction, including the state of
/// the products *at the time of purchase*. It is immutable to ensure that
/// order history data remains consistent throughout the application lifecycle.
@immutable
class Order {
  /// The unique document ID from Firestore.
  final String id;

  /// The user-facing order identifier (e.g., "#12345").
  final String orderId;

  /// The list of items purchased in this order.
  ///
  /// These contain product snapshots (price/name at purchase time) rather than
  /// references to the live product data.
  final List<CartItem> items;

  /// The subtotal of the order before discounts.
  final double totalPrice;

  /// The actual amount paid by the user after discounts.
  final double finalAmountPaid;

  /// The amount deducted via a gift card.
  final double giftCardAppliedAmount;

  /// The specific gift card code used (nullable if none).
  final String? appliedGiftCardCode;

  /// The shipping address snapshot stored as a Map.
  final Map<String, dynamic>? shippingAddress;

  /// The current status of the order (e.g., 'pending', 'shipped', 'delivered').
  final String status;

  /// The date and time when the order was placed.
  final DateTime timestamp;

  /// Creates a constant [Order] instance.
  const Order({
    required this.id,
    required this.orderId,
    required this.items,
    required this.totalPrice,
    required this.finalAmountPaid,
    required this.giftCardAppliedAmount,
    this.appliedGiftCardCode,
    this.shippingAddress,
    required this.status,
    required this.timestamp,
  });

  /// Factory constructor to create an [Order] instance from Firestore data.
  ///
  /// This method handles the complex task of reconstructing the [CartItem] list
  /// from the raw map data, ensuring that the historical data (like price at the
  /// time of purchase) is preserved even if the original product changes.
  factory Order.fromMap(Map<String, dynamic> data, String id) {
    // We recreate the list of items from the 'items' array in Firestore.
    //
    // CRITICAL: We reconstruct Product objects here using the data *saved in the order*
    // (productName, productPrice) rather than fetching them from the ProductRepository.
    // This ensures that the order history accurately reflects what the user bought and paid for,
    // even if the product name or price has changed in the store since then.
    final List<CartItem> items = (data['items'] as List? ?? []).map((itemData) {
      return CartItem(
        id: itemData['productId'] ?? '',
        product: Product(
          id: itemData['productId'] ?? 'unknown',
          name: itemData['productName'] ?? 'Unknown',
          description:
              '', // Description is omitted in order history to save DB space.
          price: (itemData['productPrice'] as num?)?.toDouble() ?? 0.0,
          imageUrl: itemData['imageUrl'] ?? defaultNoImageUrl,

          // We explicitly set stock to 0 because this is a historical record.
          stock: 0,

          // FIX: Added 'category' parameter which is now required by the Product model.
          // We try to read it from history, otherwise default to 'General'.
          category: itemData['category'] ?? 'General',
        ),
        quantity: itemData['quantity'] as int? ?? 0,
      );
    }).toList();

    return Order(
      id: id,
      orderId: data['orderId']?.toString() ?? id,
      items: items,
      // Firestore numbers can be returned as int or double, so we cast to num first
      // to avoid type casting exceptions.
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      finalAmountPaid: (data['finalAmountPaid'] as num?)?.toDouble() ?? 0.0,
      giftCardAppliedAmount:
          (data['giftCardAppliedAmount'] as num?)?.toDouble() ?? 0.0,
      appliedGiftCardCode: data['appliedGiftCardCode'] as String?,
      shippingAddress: data['shippingAddress'] as Map<String, dynamic>?,
      status: data['status'] ?? 'pending',
      // Convert the Firestore Timestamp to a standard Dart DateTime for UI usage.
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
