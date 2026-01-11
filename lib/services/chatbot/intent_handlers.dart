// lib/services/chatbot/intent_handlers.dart
import 'package:webshop/models/product.dart';
import 'conversation_context.dart';
import 'handlers/product_inquiry_handlers.dart';
import 'handlers/search_handlers.dart';
import 'handlers/utility_handlers.dart';
import 'handlers/price_comparison_handlers.dart';

/// Main facade for handling different user intents.
///
/// This class delegates to specialized handler classes for better organization:
/// - ProductInquiryHandlers: Price and stock inquiries
/// - SearchHandlers: Product search, category filter, price range search
/// - UtilityHandlers: Greeting, help, unknown
/// - PriceComparisonHandlers: Cheapest/most expensive products
class IntentHandlers {
  // Price and stock inquiries
  static String handlePriceInquiry(String query, List<Product> products,
          {ConversationContext? context}) =>
      ProductInquiryHandlers.handlePriceInquiry(query, products,
          context: context);

  static String handleStockCheck(String query, List<Product> products,
          {ConversationContext? context}) =>
      ProductInquiryHandlers.handleStockCheck(query, products,
          context: context);

  // Search and filters
  static String handleProductSearch(String query, List<Product> products,
          {ConversationContext? context}) =>
      SearchHandlers.handleProductSearch(query, products, context: context);

  static String handleCategoryFilter(String query, List<Product> products,
          {ConversationContext? context}) =>
      SearchHandlers.handleCategoryFilter(query, products, context: context);

  static String handlePriceRangeSearch(String query, List<Product> products,
          {ConversationContext? context}) =>
      SearchHandlers.handlePriceRangeSearch(query, products, context: context);

  // Price comparisons
  static String handleCheapestProduct(List<Product> products) =>
      PriceComparisonHandlers.handleCheapestProduct(products);

  static String handleMostExpensiveProduct(List<Product> products) =>
      PriceComparisonHandlers.handleMostExpensiveProduct(products);

  // Utility
  static String handleGreeting() => UtilityHandlers.handleGreeting();

  static String handleHelp() => UtilityHandlers.handleHelp();

  static String handleUnknown() => UtilityHandlers.handleUnknown();
}
