// lib/services/chatbot/handlers/search_handlers.dart
import 'package:webshop/models/product.dart';
import '../conversation_context.dart';
import '../chat_intent.dart';
import 'extraction_helpers.dart';
import 'utility_handlers.dart';

/// Handles search and filter intents.
class SearchHandlers {
  /// Handles general product search intent.
  ///
  /// Examples:
  /// - "Show me laptops"
  /// - "I'm looking for a mouse"
  /// - "Zeig mir Tastaturen"
  static String handleProductSearch(String query, List<Product> products,
      {ConversationContext? context}) {
    final lowerQuery = query.toLowerCase();

    // Try to find products matching the query
    final matchingProducts = products.where((p) {
      final nameLower = p.name.toLowerCase();
      final descLower = p.description.toLowerCase();
      return nameLower.contains(lowerQuery) ||
          descLower.contains(lowerQuery) ||
          lowerQuery.contains(nameLower);
    }).toList();

    if (matchingProducts.isEmpty) {
      // No products found - return to unknown handler
      return UtilityHandlers.handleUnknown();
    }

    if (matchingProducts.length == 1) {
      // Single product found
      final p = matchingProducts.first;
      // Store in context for follow-up questions
      context?.setLastIntent(ChatIntent.productSearch, productId: p.id);

      final stockInfo =
          p.stock > 0 ? '✅ In stock (${p.stock})' : '❌ Out of stock';
      return 'I found **${p.name}** for €${p.price.toStringAsFixed(2)}.\n'
          '$stockInfo\n\n'
          '${p.description}\n\n'
          'Would you like to know more about it?';
    } else {
      // Multiple products found - store first one in context
      context?.setLastIntent(ChatIntent.productSearch,
          productId: matchingProducts.first.id);

      final productDescriptions = matchingProducts.map((p) {
        final stockInfo =
            p.stock > 0 ? '✅ In stock (${p.stock})' : '❌ Out of stock';
        return '• **${p.name}**: €${p.price.toStringAsFixed(2)}\n'
            '  $stockInfo\n'
            '  ${p.description}';
      }).join('\n\n');

      return 'Here are the products I found:\n\n$productDescriptions';
    }
  }

  /// Handles category filter intent.
  ///
  /// Examples:
  /// - "Show electronics"
  /// - "List food items"
  /// - "What's in the clothing category?"
  /// - "Show electronics under 100 euros"
  /// - "Electronics between 50 and 200 euros"
  static String handleCategoryFilter(String query, List<Product> products,
      {ConversationContext? context}) {
    // Extract category from query
    final category = ExtractionHelpers.extractCategory(query, products);

    if (category == null) {
      // Show available categories
      final categories = products.map((p) => p.category).toSet().toList()
        ..sort();
      return 'I couldn\'t identify the category, or there are no products in this category. Available categories are:\n\n'
          '${categories.map((c) => '• $c').join('\n')}\n\n'
          'Try asking like: "Show electronics" or "List food items"';
    }

    // Store active category in context
    context?.setMetadata('activeCategory', category);
    context?.setLastIntent(ChatIntent.categoryFilter);

    // Filter products by category
    var categoryProducts = products
        .where((p) => p.category.toLowerCase() == category.toLowerCase())
        .toList();

    if (categoryProducts.isEmpty) {
      return 'Sorry, there are no products in the $category category.';
    }

    // Check if user also specified a price range
    final priceRange = ExtractionHelpers.extractPriceRange(query);
    String priceRangeText = '';

    if (priceRange != null) {
      final minPrice = priceRange['min'] ?? 0.0;
      final maxPrice = priceRange['max'] ?? double.infinity;

      // Store price range in context
      context?.setMetadata('priceRangeMin', minPrice);
      context?.setMetadata('priceRangeMax', maxPrice);

      // Apply price filter
      categoryProducts = categoryProducts.where((p) {
        return p.price >= minPrice && p.price <= maxPrice;
      }).toList();

      // Generate price range text
      if (minPrice == 0.0 && maxPrice.isFinite) {
        priceRangeText = ' under €${maxPrice.toStringAsFixed(0)}';
      } else if (maxPrice.isInfinite) {
        priceRangeText = ' over €${minPrice.toStringAsFixed(0)}';
      } else {
        priceRangeText =
            ' between €${minPrice.toStringAsFixed(0)} and €${maxPrice.toStringAsFixed(0)}';
      }

      if (categoryProducts.isEmpty) {
        return 'Sorry, there are no products in the $category category$priceRangeText.';
      }
    }

    // Limit to first 5 products
    final limitedProducts = categoryProducts.take(5).toList();
    final totalCount = categoryProducts.length;

    // Store first product ID for follow-up questions
    if (limitedProducts.isNotEmpty) {
      context?.setLastIntent(ChatIntent.categoryFilter,
          productId: limitedProducts.first.id);
    }

    final productList = limitedProducts.map((p) {
      final stockInfo =
          p.stock > 0 ? '✅ In stock (${p.stock})' : '❌ Out of stock';
      return '• **${p.name}**: €${p.price.toStringAsFixed(2)}\n'
          '  $stockInfo\n'
          '  ${p.description}';
    }).join('\n\n');

    final suffix = totalCount > 5
        ? '\n\n(and ${totalCount - 5} more products in this category)'
        : '';

    return '🏷️ Products in **$category** category$priceRangeText:\n\n$productList$suffix';
  }

  /// Handles price range search intent.
  ///
  /// Examples:
  /// - "Show products under 50 euros"
  /// - "What's between 20 and 100 euros?"
  /// - "Products cheaper than 30"
  /// - "Items from 10 to 50 euros"
  /// - "Show food items under 20 euros"
  /// - "Electronics between 50 and 100 euros"
  static String handlePriceRangeSearch(String query, List<Product> products,
      {ConversationContext? context}) {
    final priceRange = ExtractionHelpers.extractPriceRange(query);

    if (priceRange == null) {
      return 'I couldn\'t understand the price range. Try asking like:\n\n'
          '• "Show products under 50 euros"\n'
          '• "What\'s between 20 and 100 euros?"\n'
          '• "Products cheaper than 30"';
    }

    final minPrice = priceRange['min'] ?? 0.0;
    final maxPrice = priceRange['max'] ?? double.infinity;

    // Store price range in context for follow-up questions
    context?.setMetadata('priceRangeMin', minPrice);
    context?.setMetadata('priceRangeMax', maxPrice);
    context?.setLastIntent(ChatIntent.priceRangeSearch);

    // Filter products by price range
    var filteredProducts = products.where((p) {
      return p.price >= minPrice && p.price <= maxPrice;
    }).toList();

    if (filteredProducts.isEmpty) {
      return 'Sorry, no products found in the price range €${minPrice.toStringAsFixed(0)} - €${maxPrice.isFinite ? maxPrice.toStringAsFixed(0) : "∞"}.';
    }

    // Check if user also specified a category
    final category = ExtractionHelpers.extractCategory(query, products);
    String categoryText = '';

    if (category != null) {
      // Store active category in context
      context?.setMetadata('activeCategory', category);

      // Apply category filter
      filteredProducts = filteredProducts
          .where((p) => p.category.toLowerCase() == category.toLowerCase())
          .toList();

      categoryText = ' in **$category**';

      if (filteredProducts.isEmpty) {
        String rangeText;
        if (minPrice == 0.0 && maxPrice.isFinite) {
          rangeText = 'under €${maxPrice.toStringAsFixed(0)}';
        } else if (maxPrice.isInfinite) {
          rangeText = 'over €${minPrice.toStringAsFixed(0)}';
        } else {
          rangeText =
              '€${minPrice.toStringAsFixed(0)} - €${maxPrice.toStringAsFixed(0)}';
        }
        return 'Sorry, there are no products in the $category category in the price range $rangeText.';
      }
    }

    // Sort by price
    filteredProducts.sort((a, b) => a.price.compareTo(b.price));

    // Limit to first 5 products
    final limitedProducts = filteredProducts.take(5).toList();
    final totalCount = filteredProducts.length;

    final productList = limitedProducts.map((p) {
      final stockInfo =
          p.stock > 0 ? '✅ In stock (${p.stock})' : '❌ Out of stock';
      return '• **${p.name}**: €${p.price.toStringAsFixed(2)}\n'
          '  $stockInfo\n'
          '  ${p.description}';
    }).join('\n\n');

    // Determine the appropriate range text based on min/max values
    String rangeText;
    if (minPrice == 0.0 && maxPrice.isFinite) {
      // "under X" or "below X"
      rangeText = 'under €${maxPrice.toStringAsFixed(0)}';
    } else if (maxPrice.isInfinite) {
      // "over X" or "above X"
      rangeText = 'over €${minPrice.toStringAsFixed(0)}';
    } else {
      // "between X and Y"
      rangeText =
          '€${minPrice.toStringAsFixed(0)} - €${maxPrice.toStringAsFixed(0)}';
    }

    final suffix = totalCount > 5
        ? '\n\n(and ${totalCount - 5} more products in this range)'
        : '';

    return '💶 Products$categoryText in price range $rangeText:\n\n$productList$suffix';
  }
}
