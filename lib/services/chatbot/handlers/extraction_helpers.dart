// lib/services/chatbot/handlers/extraction_helpers.dart
import 'package:webshop/models/product.dart';

/// Helper functions for extracting information from user queries.
class ExtractionHelpers {
  /// Extracts category from user query by matching with existing product categories.
  static String? extractCategory(String query, List<Product> products) {
    final lowerQuery = query.toLowerCase();
    final categories = products.map((p) => p.category).toSet();

    // Try to find a category mentioned in the query
    for (final category in categories) {
      if (lowerQuery.contains(category.toLowerCase())) {
        return category;
      }
    }

    return null;
  }

  /// Extracts price range from user query.
  /// Returns a map with 'min' and/or 'max' keys, or null if no price found.
  static Map<String, double>? extractPriceRange(String query) {
    final lowerQuery = query.toLowerCase();

    // Pattern 1: "under X" or "below X" or "cheaper than X" or "less than X"
    final underPattern = RegExp(
        r'(under|below|cheaper than|less than|bis|maximum|max|unter)\s*(€|euro|euros)?\s*(\d+)');
    final underMatch = underPattern.firstMatch(lowerQuery);
    if (underMatch != null) {
      final maxPrice = double.tryParse(underMatch.group(3) ?? '');
      if (maxPrice != null) {
        return {'min': 0.0, 'max': maxPrice};
      }
    }

    // Pattern 2: "over X" or "above X" or "more than X"
    final overPattern = RegExp(
        r'(over|above|more than|greater than|ab|minimum|min|über)\s*(€|euro|euros)?\s*(\d+)');
    final overMatch = overPattern.firstMatch(lowerQuery);
    if (overMatch != null) {
      final minPrice = double.tryParse(overMatch.group(3) ?? '');
      if (minPrice != null) {
        return {'min': minPrice};
      }
    }

    // Pattern 3: "between X and Y" or "from X to Y" - with optional euro/euros between numbers
    final betweenPattern = RegExp(
        r'(between|from|von)\s*(€|euro|euros)?\s*(\d+)\s*(€|euro|euros)?\s*(and|to|bis)\s*(€|euro|euros)?\s*(\d+)');
    final betweenMatch = betweenPattern.firstMatch(lowerQuery);
    if (betweenMatch != null) {
      final minPrice = double.tryParse(betweenMatch.group(3) ?? '');
      final maxPrice = double.tryParse(betweenMatch.group(7) ?? '');
      if (minPrice != null && maxPrice != null) {
        return {'min': minPrice, 'max': maxPrice};
      }
    }

    // Pattern 4: Simple "X to Y" or "X - Y" - with optional euro/euros between numbers
    final simpleRangePattern = RegExp(
        r'(€|euro|euros)?\s*(\d+)\s*(€|euro|euros)?\s*(-|to|bis)\s*(€|euro|euros)?\s*(\d+)');
    final simpleMatch = simpleRangePattern.firstMatch(lowerQuery);
    if (simpleMatch != null) {
      final minPrice = double.tryParse(simpleMatch.group(2) ?? '');
      final maxPrice = double.tryParse(simpleMatch.group(6) ?? '');
      if (minPrice != null && maxPrice != null) {
        return {'min': minPrice, 'max': maxPrice};
      }
    }

    return null;
  }
}
