// lib/services/ai_chatbot.dart
import 'package:webshop/models/product.dart';

/// A service that powers the AI Shopping Assistant.
///
/// This class handles the natural language processing (NLP) logic to understand
/// user queries and generate appropriate responses based on the available [Product] list.
///
/// **Note:** In this demo, the logic is rule-based (keyword matching).
/// In a production environment, this would likely make an API call to a real LLM
/// (like OpenAI, Gemini, or Dialogflow).
class AIChatbotService {
  /// Generates a response to a user's [query].
  ///
  /// * [query]: The raw text input from the chat widget.
  /// * [products]: The list of currently loaded products to search within.
  ///
  /// Returns a [Future<String>] to simulate network latency, making the
  /// chat experience feel more realistic.
  Future<String> respond(String query, List<Product> products) async {
    // UX: Simulate a small network delay ("typing" effect)
    await Future.delayed(const Duration(milliseconds: 800));

    final lowerQuery = query.toLowerCase();

    // --- SCENARIO 1: Availability / Stock Check ---
    // Keywords: available, stock, have
    if (lowerQuery.contains('available') ||
        lowerQuery.contains('stock') ||
        lowerQuery.contains('have')) {
      // Find the first product whose name matches the query
      final foundProduct = products.firstWhere(
        (p) => lowerQuery.contains(p.name.toLowerCase()),
        // Fallback object to avoid exception if not found
        orElse: () => const Product(
            id: '',
            name: '',
            description: '',
            price: 0,
            imageUrl: '',
            stock: -1),
      );

      // If we found a valid product (stock != -1)
      if (foundProduct.stock != -1) {
        if (foundProduct.stock > 0) {
          return 'Yes, we have ${foundProduct.stock} units of ${foundProduct.name} in stock.';
        } else {
          return 'Sorry, ${foundProduct.name} is currently out of stock.';
        }
      }
      return 'We have many products in stock! Which one are you looking for?';
    }

    // --- SCENARIO 2: Price Check ---
    // Keywords: price, cost, much
    if (lowerQuery.contains('price') ||
        lowerQuery.contains('cost') ||
        lowerQuery.contains('much')) {
      final foundProduct = products.firstWhere(
        (p) => lowerQuery.contains(p.name.toLowerCase()),
        orElse: () => const Product(
            id: '',
            name: '',
            description: '',
            price: 0,
            imageUrl: '',
            stock: -1),
      );

      if (foundProduct.stock != -1) {
        return 'The price for ${foundProduct.name} is €${foundProduct.price.toStringAsFixed(2)}.';
      }
    }

    // --- SCENARIO 3: General Product Search ---
    // Filters the list based on name or description match
    final matchingProducts = products
        .where((p) =>
            lowerQuery.contains(p.name.toLowerCase()) ||
            p.description.toLowerCase().contains(lowerQuery))
        .toList();

    if (matchingProducts.isNotEmpty) {
      if (matchingProducts.length == 1) {
        // Exact match found
        return 'I found ${matchingProducts.first.name} for €${matchingProducts.first.price.toStringAsFixed(2)}. Would you like to add it to your cart?';
      } else {
        // Multiple matches found, list the first 3
        final names = matchingProducts.map((p) => p.name).take(3).join(', ');
        return 'I found a few items that match: $names. Can you be more specific?';
      }
    }

    // --- DEFAULT FALLBACK ---
    // Suggest valid queries to guide the user
    return 'I can help you find products, check prices, or view stock availability. Try asking "How much is the iPhone?" or "Do you have laptops?"';
  }
}
