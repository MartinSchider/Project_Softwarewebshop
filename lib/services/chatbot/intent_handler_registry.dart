// lib/services/chatbot/intent_handler_registry.dart
import 'package:webshop/models/product.dart';
import 'chat_intent.dart';
import 'conversation_context.dart';
import 'intent_handlers.dart';

/// Type definition for intent handler functions.
typedef IntentHandler = String Function(
  String query,
  List<Product> products, {
  ConversationContext? context,
});

/// Type definition for simple intent handler functions (no query/products needed).
typedef SimpleIntentHandler = String Function();

/// Registry that maps intents to their handler functions.
///
/// This eliminates the need for a large switch statement and makes
/// it easier to add or modify intent handlers.
class IntentHandlerRegistry {
  /// Maps intents to their handler functions.
  static final Map<ChatIntent, dynamic> _handlers = {
    // Handlers requiring query and products
    ChatIntent.priceInquiry: IntentHandlers.handlePriceInquiry,
    ChatIntent.stockCheck: IntentHandlers.handleStockCheck,
    ChatIntent.productSearch: IntentHandlers.handleProductSearch,
    ChatIntent.categoryFilter: IntentHandlers.handleCategoryFilter,
    ChatIntent.priceRangeSearch: IntentHandlers.handlePriceRangeSearch,

    // Handlers requiring only products
    ChatIntent.cheapestProduct: (String query, List<Product> products,
            {ConversationContext? context}) =>
        IntentHandlers.handleCheapestProduct(products),
    ChatIntent.mostExpensiveProduct: (String query, List<Product> products,
            {ConversationContext? context}) =>
        IntentHandlers.handleMostExpensiveProduct(products),

    // Simple handlers
    ChatIntent.greeting: (String query, List<Product> products,
            {ConversationContext? context}) =>
        IntentHandlers.handleGreeting(),
    ChatIntent.help: (String query, List<Product> products,
            {ConversationContext? context}) =>
        IntentHandlers.handleHelp(),
    ChatIntent.unknown: (String query, List<Product> products,
            {ConversationContext? context}) =>
        IntentHandlers.handleUnknown(),
  };

  /// Executes the handler for the given intent.
  ///
  /// Returns the response string from the handler, or a default
  /// unknown response if no handler is registered.
  static String handle(
    ChatIntent intent,
    String query,
    List<Product> products, {
    ConversationContext? context,
  }) {
    final handler = _handlers[intent];

    if (handler == null) {
      return IntentHandlers.handleUnknown();
    }

    return handler(query, products, context: context);
  }

  /// Checks if a handler is registered for the given intent.
  static bool hasHandler(ChatIntent intent) {
    return _handlers.containsKey(intent);
  }

  /// Gets all registered intents.
  static List<ChatIntent> get registeredIntents => _handlers.keys.toList();
}
