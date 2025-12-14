// lib/models/product.dart
import 'package:flutter/foundation.dart';
import 'package:webshop/utils/constants.dart';

/// Represents a sellable item within the application.
///
/// This model acts as the bridge between the Firestore database structure
/// and the Flutter UI. It is marked as [immutable] to ensure that product
/// data cannot be modified unexpectedly once loaded into memory, which is
/// crucial for reliable state management (e.g., in Riverpod providers).
@immutable
class Product {
  /// The unique document ID from Firestore.
  final String id;

  /// The display name of the product.
  final String name;

  /// A detailed description of the product features.
  final String description;

  /// The unit price of the product.
  final double price;

  /// The URL of the product image (remote storage).
  final String imageUrl;

  /// The quantity currently available in the inventory.
  ///
  /// This field is critical for the [CartService] to validate availability
  /// before adding items to the cart.
  final int stock;

  /// The category of the product (e.g., 'Electronics', 'Food', 'General').
  /// Used for filtering the product list in the UI.
  final String category;

  /// Creates a constant [Product] instance.
  ///
  /// All fields are required to ensure the UI never has to handle partially
  /// initialized product objects.
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.stock,
    required this.category,
  });

  /// Factory constructor to transform Firestore data into a [Product] object.
  ///
  /// This method implements the **Adapter Pattern**, converting the specific
  /// database field names (e.g., `productName`) into the clean internal names
  /// used by the app (e.g., `name`).
  ///
  /// * [data]: The raw map from `document.data()`.
  /// * [id]: The document ID, passed separately as it's outside the data map.
  factory Product.fromMap(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      // MAPPING EXPLANATION:
      // The database uses 'productName' but the app uses 'name'.
      // We map them here to decouple the database schema from the UI code.
      // We use 'as String?' cast and '??' default value to prevent crashes
      // if the database has missing fields or null values.
      name: data['productName'] as String? ?? 'Unknown Product',

      description: data['productDescription'] as String? ?? '',

      // Firestore might return price as int (e.g., 10) or double (e.g., 10.5).
      // Casting to 'num?' covers both cases, then we convert to double.
      price: (data['productPrice'] as num?)?.toDouble() ?? 0.0,

      // Use the new constant name (defaultNoImageUrl)
      imageUrl: data['imageUrl'] as String? ?? defaultNoImageUrl,

      // STOCK HANDLING LOGIC:
      // If the 'stock' field is missing in the DB (legacy data), we default to 999.
      // Why? Defaulting to 0 would prevent users from adding the product to the cart.
      stock: (data['stock'] as int?) ?? 999,

      // CATEGORY HANDLING:
      // If the category is missing, we assign 'General' to ensure it appears in lists.
      category: data['category'] as String? ?? 'General',
    );
  }

  /// Converts the [Product] instance back to a [Map] for database operations.
  ///
  /// This ensures that when we save or update a product (e.g., via an Admin panel),
  /// we write back to the correct database field names (`productName`, etc.).
  Map<String, dynamic> toMap() {
    return {
      'productName': name,
      'productDescription': description,
      'productPrice': price,
      'imageUrl': imageUrl,
      'stock': stock,
      'category': category,
    };
  }
}