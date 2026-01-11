// lib/services/chatbot/handlers/product_inquiry_handlers.dart
import 'package:webshop/models/product.dart';
import '../product_extractor.dart';
import '../conversation_context.dart';
import '../chat_intent.dart';

/// Handles product inquiry intents (price and stock checks).
class ProductInquiryHandlers {
  /// Handles price inquiry intent.
  ///
  /// Examples:
  /// - "How much is the laptop?"
  /// - "What's the price of the mouse?"
  /// - "Was kostet die Tastatur?"
  static String handlePriceInquiry(String query, List<Product> products,
      {ConversationContext? context}) {
    final product = ProductExtractor.extractProduct(query, products);

    if (product != null) {
      // Store product ID in context for follow-up questions
      context?.setLastIntent(ChatIntent.priceInquiry, productId: product.id);
      return 'The ${product.name} costs €${product.price.toStringAsFixed(2)}.';
    } else {
      // Check if user is asking about last mentioned product
      if (context?.lastProductId != null &&
          (query.toLowerCase().contains('it') ||
              query.toLowerCase().contains('that'))) {
        final lastProduct = products.firstWhere(
          (p) => p.id == context!.lastProductId,
          orElse: () => products.first,
        );
        return 'The ${lastProduct.name} costs €${lastProduct.price.toStringAsFixed(2)}.';
      }

      // Fallback: show all products with prices
      final productList = products
          .map((p) => '• ${p.name}: €${p.price.toStringAsFixed(2)}')
          .join('\n');
      return "I couldn't identify the specific product. Here are all our products with prices:\n\n$productList";
    }
  }

  /// Handles stock availability check intent.
  ///
  /// Examples:
  /// - "Do you have laptops available?"
  /// - "Is the mouse in stock?"
  /// - "Habt ihr Tastaturen verfügbar?"
  static String handleStockCheck(String query, List<Product> products,
      {ConversationContext? context}) {
    final product = ProductExtractor.extractProduct(query, products);

    if (product != null) {
      // Store product ID in context
      context?.setLastIntent(ChatIntent.stockCheck, productId: product.id);

      // Specific product stock check
      if (product.stock > 0) {
        return 'Yes, ${product.name} is available! We have ${product.stock} units in stock.';
      } else {
        return 'Sorry, ${product.name} is currently out of stock.';
      }
    } else {
      // Check if user is asking about last mentioned product
      if (context?.lastProductId != null &&
          (query.toLowerCase().contains('it') ||
              query.toLowerCase().contains('that') ||
              query.toLowerCase().contains('available'))) {
        final lastProduct = products.firstWhere(
          (p) => p.id == context!.lastProductId,
          orElse: () => products.first,
        );
        if (lastProduct.stock > 0) {
          return 'Yes, ${lastProduct.name} is available! We have ${lastProduct.stock} units in stock.';
        } else {
          return 'Sorry, ${lastProduct.name} is currently out of stock.';
        }
      }

      // General availability check - show all available products
      final availableProducts = products.where((p) => p.stock > 0).toList();

      if (availableProducts.isEmpty) {
        return "Sorry, we currently have no products in stock.";
      }

      final productList = availableProducts
          .map((p) => '• ${p.name} (${p.stock} in stock)')
          .join('\n');
      return "Sorry, I don't know which product you mean. We currently have the following products available:\n\n$productList";
    }
  }
}
