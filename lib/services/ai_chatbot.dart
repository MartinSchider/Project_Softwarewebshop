// lib/services/ai_chatbot.dart
import 'package:webshop/models/product.dart';

/// A service that powers the AI Shopping Assistant.
///
/// This class handles the natural language processing (NLP) logic to understand
/// user queries and generate appropriate responses based on the available [Product] list.
class AIChatbotService {
  
  /// Generates a response to a user's [query].
  Future<String> respond(String query, List<Product> products) async {
    // UX: Simulate a small network delay ("typing" effect)
    await Future.delayed(const Duration(milliseconds: 800));

    final lowerQuery = query.toLowerCase();

    // --- SCENARIO 1: Availability / Stock Check ---
    if (lowerQuery.contains('available') || lowerQuery.contains('stock') || lowerQuery.contains('have')) {
      // Find the first product whose name matches the query
      final foundProduct = products.firstWhere(
        (p) => lowerQuery.contains(p.name.toLowerCase()),
        // Fallback object to avoid exception if not found
        // FIX: Added required 'category' parameter
        orElse: () => const Product(
          id: '', 
          name: '', 
          description: '', 
          price: 0, 
          imageUrl: '', 
          stock: -1,
          category: 'General', // <--- FIX HERE
        ),
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
    if (lowerQuery.contains('price') || lowerQuery.contains('cost') || lowerQuery.contains('much')) {
      final foundProduct = products.firstWhere(
        (p) => lowerQuery.contains(p.name.toLowerCase()),
        // FIX: Added required 'category' parameter
        orElse: () => const Product(
          id: '', 
          name: '', 
          description: '', 
          price: 0, 
          imageUrl: '', 
          stock: -1,
          category: 'General', // <--- FIX HERE
        ),
      );

      if (foundProduct.stock != -1) {
        return 'The price for ${foundProduct.name} is €${foundProduct.price.toStringAsFixed(2)}.';
      }
    }

    // --- SCENARIO 3: General Product Search ---
    final matchingProducts = products.where((p) => 
      lowerQuery.contains(p.name.toLowerCase()) || 
      p.description.toLowerCase().contains(lowerQuery)
    ).toList();

    if (matchingProducts.isNotEmpty) {
      if (matchingProducts.length == 1) {
        return 'I found ${matchingProducts.first.name} for €${matchingProducts.first.price.toStringAsFixed(2)}. Would you like to add it to your cart?';
      } else {
        final names = matchingProducts.map((p) => p.name).take(3).join(', ');
        return 'I found a few items that match: $names. Can you be more specific?';
      }
    }

    // --- DEFAULT FALLBACK ---
    return 'I can help you find products, check prices, or view stock availability. Try asking "How much is the iPhone?" or "Do you have laptops?"';
  }
}