// lib/services/chatbot/intent_classifier.dart
import 'chat_intent.dart';
import 'intent_pattern.dart';
import 'intent_patterns_config.dart';
import 'conversation_context.dart';

/// Classifies user queries into specific intents.
///
/// Uses a three-step approach:
/// 1. Pattern matching (precise, higher priority)
/// 2. Keyword scoring (broader, fallback)
/// 3. Context-aware classification (for follow-up questions)
class IntentClassifier {
  /// Classifies the user's intent based on their query and conversation context.
  ///
  /// Uses a combination of pattern matching, keyword scoring, and conversation
  /// history to determine what the user wants to achieve.
  ///
  /// Returns the most likely [ChatIntent], or [ChatIntent.unknown] if no
  /// clear intent can be determined.
  static ChatIntent classifyIntent(String query,
      {ConversationContext? context}) {
    final lowerQuery = query.toLowerCase().trim();

    // Empty query handling
    if (lowerQuery.isEmpty) {
      return ChatIntent.unknown;
    }

    // Step 0: Check for context-aware follow-up questions
    if (context != null && _isFollowUpQuestion(lowerQuery)) {
      // If user says "yes" or "more" after product search, maintain context
      if (context.lastIntent == ChatIntent.productSearch ||
          context.lastIntent == ChatIntent.priceInquiry ||
          context.lastIntent == ChatIntent.stockCheck) {
        // Check if it's a price or stock follow-up
        if (_isPriceFollowUp(lowerQuery)) {
          return ChatIntent.priceInquiry;
        } else if (_isStockFollowUp(lowerQuery)) {
          return ChatIntent.stockCheck;
        }
      }
    }

    // Step 1: Check regex patterns (more precise)
    // Sort by priority first
    final sortedPatterns =
        List<IntentPattern>.from(IntentPatternsConfig.patterns)
          ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final pattern in sortedPatterns) {
      if (pattern.patterns != null) {
        for (final regex in pattern.patterns!) {
          if (regex.hasMatch(lowerQuery)) {
            return pattern.intent;
          }
        }
      }
    }

    // Step 2: Keyword scoring (broader matching)
    Map<ChatIntent, int> scores = {};

    for (final pattern in IntentPatternsConfig.patterns) {
      int score = 0;
      for (final keyword in pattern.keywords) {
        if (lowerQuery.contains(keyword)) {
          score += pattern.priority;
        }
      }
      if (score > 0) {
        scores[pattern.intent] = (scores[pattern.intent] ?? 0) + score;
      }
    }

    // Return intent with highest score (only if score is meaningful)
    if (scores.isNotEmpty) {
      return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    // Step 3: Check if query might be about a product (mentions product names)
    // If not, return unknown
    return ChatIntent.unknown;
  }

  /// Checks if the query is a follow-up question (refers to previous context).
  static bool _isFollowUpQuestion(String query) {
    final followUpIndicators = [
      'it',
      'that',
      'this',
      'them',
      'those',
      'yes',
      'yeah',
      'yep',
      'sure',
      'ok',
      'okay',
      'tell me more',
      'more info',
      'more details',
      'about it',
      'about that',
      'what about',
    ];

    return followUpIndicators.any((indicator) => query.contains(indicator));
  }

  /// Checks if it's a price-related follow-up.
  static bool _isPriceFollowUp(String query) {
    final priceIndicators = [
      'price',
      'cost',
      'how much',
      'expensive',
      'cheap',
      '\$',
      '€',
      'euro',
      'dollar',
    ];

    return priceIndicators.any((indicator) => query.contains(indicator));
  }

  /// Checks if it's a stock-related follow-up.
  static bool _isStockFollowUp(String query) {
    final stockIndicators = [
      'stock',
      'available',
      'in stock',
      'availability',
      'have',
      'get',
      'buy',
      'order',
    ];

    return stockIndicators.any((indicator) => query.contains(indicator));
  }
}
