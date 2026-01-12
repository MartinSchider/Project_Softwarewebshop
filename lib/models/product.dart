// lib/models/product.dart
/// Represents a product available in the webshop.
///
/// This model holds all the essential information about an item, including its
/// display details (name, image, description), pricing logic (current price,
/// original price, discounts), inventory status (stock), and shipping estimates.
///
/// It provides methods to serialize/deserialize data for Cloud Firestore.
class Product {
  /// The unique identifier of the product document in Firestore.
  final String id;

  /// The display name of the product.
  final String name;

  /// A detailed description of the product's features.
  final String description;

  /// The current selling price of the product (after any discounts).
  final double price;

  /// The URL of the product image (hosted on Firebase Storage or external).
  final String imageUrl;

  /// The category this product belongs to (e.g., 'Electronics', 'Clothing').
  final String category;

  /// The current quantity available in the inventory.
  final int stock;

  /// The average rating derived from user reviews (0.0 to 5.0).
  final double averageRating;

  /// The total number of reviews submitted for this product.
  final int reviewCount;

  /// The percentage discount applied to the original price (0-100).
  final int discountPercentage;

  /// The original listing price before discount.
  ///
  /// Used to calculate savings and display "strike-through" prices.
  final double originalPrice;

  /// The estimated number of business days required for delivery.
  ///
  /// * Value <= 2 triggers the "EXPRESS" badge in the UI.
  /// * Used to calculate the estimated delivery date in the detail view.
  final int deliveryDays;

  /// Creates a [Product] instance.
  ///
  /// If [originalPrice] is not provided, it defaults to [price], implying
  /// no discount is currently active.
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.stock,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.discountPercentage = 0,
    double? originalPrice,
    this.deliveryDays = 3, // Default standard delivery
  }) : originalPrice = originalPrice ?? price;

  /// Converts the [Product] instance to a JSON-compatible [Map].
  ///
  /// This method is used when creating or updating a product document
  /// in Cloud Firestore.
  Map<String, dynamic> toMap() {
    return {
      // Note: Keys match the legacy schema used in the database.
      'productName': name,
      'productDescription': description,
      'productPrice': price,
      'imageUrl': imageUrl,
      'category': category,
      'stock': stock,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'discountPercentage': discountPercentage,
      'originalPrice': originalPrice,
      'deliveryDays': deliveryDays,
    };
  }

  /// Factory constructor to create a [Product] from a Firestore [Map].
  ///
  /// This method includes robust error handling for data types to prevent
  /// app crashes if the database contains unexpected formats (e.g., String instead of double).
  ///
  /// * [map]: The raw key-value pairs from the database snapshot.
  /// * [id]: The document ID from Firestore.
  factory Product.fromMap(Map<String, dynamic> map, String id) {
    
    // --- Helper Functions for Type Safety ---

    /// Safely parses a dynamic value into a [double].
    /// Handles nulls, integers, doubles, and parsable strings.
    double safeParseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    /// Safely parses a dynamic value into an [int].
    int safeParseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // --- Data Extraction ---

    final double currentPrice = safeParseDouble(map['productPrice']);
    
    // Fallback logic: if originalPrice is missing, assume it equals the current price.
    final double original = map['originalPrice'] != null 
        ? safeParseDouble(map['originalPrice']) 
        : currentPrice;

    return Product(
      id: id,
      name: map['productName'] ?? '',
      description: map['productDescription'] ?? '',
      price: currentPrice,
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? 'General',
      stock: safeParseInt(map['stock']),
      averageRating: safeParseDouble(map['averageRating']),
      reviewCount: safeParseInt(map['reviewCount']),
      discountPercentage: safeParseInt(map['discountPercentage']),
      originalPrice: original,
      // Delivery Logic: Ensure at least a fallback value if field is missing or invalid.
      deliveryDays: safeParseInt(map['deliveryDays']) > 0 
          ? safeParseInt(map['deliveryDays']) 
          : 3,
    );
  }
}