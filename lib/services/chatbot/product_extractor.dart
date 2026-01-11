// lib/services/chatbot/product_extractor.dart
import 'package:webshop/models/product.dart';

/// Utility for extracting specific products from user queries.
class ProductExtractor {
  /// Attempts to extract a specific product from the query.
  ///
  /// Returns the [Product] if found, or null if no clear match exists.
  ///
  /// Uses flexible matching:
  /// - Exact match (query contains full product name)
  /// - Partial match (product name contains query words)
  /// - Word-by-word match (any significant word from product name in query)
  /// - Handles hyphens and special characters (e.g., "T-Shirt", "Teddy-Bear")
  static Product? extractProduct(String query, List<Product> products) {
    final lowerQuery = query.toLowerCase();

    // Step 1: Try exact match (query contains full product name)
    for (final product in products) {
      final lowerName = product.name.toLowerCase();
      if (lowerQuery.contains(lowerName)) {
        return product;
      }
    }

    // Step 2: Try partial match (product name contains significant query words)
    // Extract significant words from query (ignore common words)
    final commonWords = {
      'the',
      'a',
      'an',
      'is',
      'of',
      'for',
      'what',
      'how',
      'much',
      'price',
      'cost',
      'available',
      'in',
      'stock',
      'one',
      'first',
      'second',
      'third',
      'fourth',
      'fifth',
      'last',
      'next',
      'it',
      'that',
      'this',
      'show',
      'me',
      'get',
    };

    // Split by whitespace, hyphens, and other common separators
    final queryWords = lowerQuery
        .split(RegExp(r'[\s\-_,;]+'))
        .where((word) => word.length > 2 && !commonWords.contains(word))
        .toList();

    for (final product in products) {
      final lowerName = product.name.toLowerCase();
      // Split product name by whitespace, hyphens, etc.
      final productWords = lowerName
          .split(RegExp(r'[\s\-_,;]+'))
          .where((word) => word.isNotEmpty)
          .toList();

      // Check if any significant query word matches any product word
      for (final queryWord in queryWords) {
        for (final productWord in productWords) {
          // Bidirectional matching: check both directions
          if (queryWord == productWord ||
              queryWord.contains(productWord) && productWord.length >= 3 ||
              productWord.contains(queryWord) && queryWord.length >= 3) {
            return product;
          }
        }
      }
    }

    return null;
  }
}
