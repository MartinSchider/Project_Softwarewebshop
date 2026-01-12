// lib/services/chatbot/handlers/utility_handlers.dart

/// Handles utility intents (greeting, help, unknown).
class UtilityHandlers {
  /// Handles greeting intent.
  ///
  /// Examples:
  /// - "Hello"
  /// - "Hi there"
  /// - "Guten Tag"
  static String handleGreeting() {
    return "Hello! 👋 Welcome to our shop! I'm your AI Shopping Assistant.\n\n"
        "I can help you with:\n"
        "• Finding products\n"
        "• Checking prices\n"
        "• Checking availability\n\n"
        "What can I help you with today?";
  }

  /// Handles help intent.
  ///
  /// Examples:
  /// - "Can you help me?"
  /// - "What can you do?"
  /// - "Hilfe"
  static String handleHelp() {
    return "I'm here to help! 🤖\n\n"
        "You can ask me:\n\n"
        "📋 **Product Search:**\n"
        "• \"Show me laptops\"\n"
        "• \"Do you have keyboards?\"\n\n"
        "🏷️ **Category Filter:**\n"
        "• \"Show electronics\"\n"
        "• \"List food items\"\n"
        "• \"What's in clothing category?\"\n\n"
        "💰 **Prices:**\n"
        "• \"How much is the laptop?\"\n"
        "• \"What's the price of the mouse?\"\n"
        "• \"What are the cheapest products?\"\n"
        "• \"Show me the most expensive items\"\n\n"
        "💶 **Price Range:**\n"
        "• \"Show products under 50 euros\"\n"
        "• \"What's between 20 and 100 euros?\"\n"
        "• \"Products cheaper than 30\"\n\n"
        "📦 **Availability:**\n"
        "• \"Is the keyboard in stock?\"\n"
        "• \"What products are available?\"\n\n"
        "Just type your question naturally!";
  }

  /// Handles unknown intent (fallback).
  static String handleUnknown() {
    return "I'm not sure I understood that. 🤔\n\n"
        "Try asking me about:\n"
        "• Product prices\n"
        "• Product availability\n"
        "• Searching for products\n"
        "• Filtering by category\n"
        "• Price ranges (e.g., 'under 50 euros')\n"
        "• Cheapest or most expensive items\n\n"
        "Or type 'help' to see what I can do!";
  }
}
