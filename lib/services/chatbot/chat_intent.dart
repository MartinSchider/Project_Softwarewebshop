// lib/services/chatbot/chat_intent.dart

/// Represents the user's intent behind their message.
///
/// This enum is used for Intent Classification to understand what the user
/// wants to achieve, rather than just matching keywords.
enum ChatIntent {
  /// User wants to know the price of a product
  priceInquiry,

  /// User wants to check stock availability
  stockCheck,

  /// User is searching for products
  productSearch,

  /// User wants to see the cheapest products
  cheapestProduct,

  /// User wants to see the most expensive products
  mostExpensiveProduct,

  /// User is greeting the bot
  greeting,

  /// User is asking for help
  help,

  /// User wants to filter products by category
  categoryFilter,

  /// User wants to search products by price range
  priceRangeSearch,

  /// Intent could not be determined
  unknown,
}
