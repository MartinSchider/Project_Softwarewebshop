// lib/services/chatbot/handlers/price_comparison_handlers.dart
import 'package:webshop/models/product.dart';

/// Handles price comparison intents (cheapest/most expensive products).
class PriceComparisonHandlers {
  /// Handles cheapest product intent.
  ///
  /// Examples:
  /// - "What are the cheapest products?"
  /// - "Show me affordable items"
  /// - "Was sind die billigsten Produkte?"
  static String handleCheapestProduct(List<Product> products) {
    if (products.isEmpty) {
      return 'Sorry, no products are currently available.';
    }

    // Sort products by price (ascending)
    final sortedProducts = List<Product>.from(products)
      ..sort((a, b) => a.price.compareTo(b.price));

    // Take the 3 cheapest products
    final cheapestProducts = sortedProducts.take(3).toList();

    final productList = cheapestProducts.map((p) {
      final stockInfo =
          p.stock > 0 ? '✅ In stock (${p.stock})' : '❌ Out of stock';
      return '• **${p.name}**: €${p.price.toStringAsFixed(2)}\n'
          '  $stockInfo\n'
          '  ${p.description}';
    }).join('\n\n');

    return '💰 Here are our cheapest products:\n\n$productList';
  }

  /// Handles most expensive product intent.
  ///
  /// Examples:
  /// - "What are the most expensive products?"
  /// - "Show me premium items"
  /// - "Was sind die teuersten Produkte?"
  static String handleMostExpensiveProduct(List<Product> products) {
    if (products.isEmpty) {
      return 'Sorry, no products are currently available.';
    }

    // Sort products by price (descending)
    final sortedProducts = List<Product>.from(products)
      ..sort((a, b) => b.price.compareTo(a.price));

    // Take the 3 most expensive products
    final expensiveProducts = sortedProducts.take(3).toList();

    final productList = expensiveProducts.map((p) {
      final stockInfo =
          p.stock > 0 ? '✅ In stock (${p.stock})' : '❌ Out of stock';
      return '• **${p.name}**: €${p.price.toStringAsFixed(2)}\n'
          '  $stockInfo\n'
          '  ${p.description}';
    }).join('\n\n');

    return '💎 Here are our most expensive products:\n\n$productList';
  }
}
