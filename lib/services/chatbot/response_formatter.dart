// lib/services/chatbot/response_formatter.dart
import 'package:webshop/models/product.dart';

/// Utility class for formatting chatbot responses consistently.
///
/// Provides standardized methods for formatting products, lists, and messages
/// to ensure a consistent user experience across all intent handlers.
class ResponseFormatter {
  /// Formats a single product with its details.
  ///
  /// Returns a formatted string with product name, price, stock status, and description.
  static String formatProduct(Product product,
      {bool includeDescription = true}) {
    final stockInfo =
        product.stock > 0 ? '✅ In stock (${product.stock})' : '❌ Out of stock';

    if (includeDescription) {
      return '**${product.name}**: €${product.price.toStringAsFixed(2)}\n'
          '$stockInfo\n'
          '${product.description}';
    } else {
      return '**${product.name}**: €${product.price.toStringAsFixed(2)} - $stockInfo';
    }
  }

  /// Formats a list of products with bullet points.
  ///
  /// Each product is formatted with a bullet point and includes all details.
  static String formatProductList(List<Product> products,
      {bool includeDescription = true}) {
    return products.map((p) {
      final stockInfo =
          p.stock > 0 ? '✅ In stock (${p.stock})' : '❌ Out of stock';

      if (includeDescription) {
        return '• **${p.name}**: €${p.price.toStringAsFixed(2)}\n'
            '  $stockInfo\n'
            '  ${p.description}';
      } else {
        return '• **${p.name}**: €${p.price.toStringAsFixed(2)} - $stockInfo';
      }
    }).join('\n\n');
  }

  /// Formats a price range as human-readable text.
  ///
  /// Examples:
  /// - "under €50"
  /// - "over €100"
  /// - "€50 - €200"
  static String formatPriceRange(double minPrice, double maxPrice) {
    if (minPrice == 0.0 && maxPrice.isFinite) {
      return 'under €${maxPrice.toStringAsFixed(0)}';
    } else if (maxPrice.isInfinite) {
      return 'over €${minPrice.toStringAsFixed(0)}';
    } else {
      return '€${minPrice.toStringAsFixed(0)} - €${maxPrice.toStringAsFixed(0)}';
    }
  }

  /// Formats a list with an optional "and X more" suffix.
  ///
  /// Useful for limiting displayed results while indicating more are available.
  static String formatListWithSuffix(
    String formattedList,
    int totalCount,
    int displayedCount, {
    String itemType = 'items',
  }) {
    if (totalCount > displayedCount) {
      return '$formattedList\n\n(and ${totalCount - displayedCount} more $itemType)';
    }
    return formattedList;
  }

  /// Formats an error message with a friendly tone.
  static String formatError(String message) {
    return '❌ $message';
  }

  /// Formats a success message with a checkmark.
  static String formatSuccess(String message) {
    return '✅ $message';
  }

  /// Formats an info message with an icon.
  static String formatInfo(String message, {String icon = 'ℹ️'}) {
    return '$icon $message';
  }

  /// Formats a category name for display.
  static String formatCategory(String category) {
    return '**$category**';
  }

  /// Formats a simple list of items with bullet points.
  static String formatSimpleList(List<String> items) {
    return items.map((item) => '• $item').join('\n');
  }

  /// Formats a numbered list of items.
  static String formatNumberedList(List<String> items) {
    return items
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
  }
}
