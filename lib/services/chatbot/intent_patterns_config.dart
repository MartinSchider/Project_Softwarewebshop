// lib/services/chatbot/intent_patterns_config.dart
import 'chat_intent.dart';
import 'intent_pattern.dart';

/// Configuration of all intent patterns for classification.
///
/// Patterns are checked in order of priority (higher first).
class IntentPatternsConfig {
  static final List<IntentPattern> patterns = [
    // Price Inquiry Intent
    IntentPattern(
      intent: ChatIntent.priceInquiry,
      keywords: [
        'price',
        'cost',
        'kostet',
        'teuer',
        'much',
        'preis',
        'expensive',
        'cheap',
        'euro'
      ],
      patterns: [
        RegExp(r'how much (is|are|does|do|cost)'),
        RegExp(r'what.*price'),
        RegExp(r'was kostet'),
        RegExp(r'wie teuer'),
        RegExp(r'(is|are) .* (expensive|cheap)'),
      ],
      priority: 1,
    ),

    // Stock Check Intent
    IntentPattern(
      intent: ChatIntent.stockCheck,
      keywords: [
        'available',
        'stock',
        'have',
        'verfügbar',
        'lager',
        'vorrätig',
        'in stock'
      ],
      patterns: [
        RegExp(r'(do you|habt ihr|have you) have'),
        RegExp(r'is .* (available|in stock|verfügbar)'),
        RegExp(r'(any|some) .* (available|in stock)'),
      ],
      priority: 2,
    ),

    // Greeting Intent
    IntentPattern(
      intent: ChatIntent.greeting,
      keywords: [
        'hello',
        'hey',
        'hallo',
        'guten tag',
        'moin',
        'servus',
        'greetings',
        'good morning',
        'good evening'
      ],
      patterns: [
        RegExp(r'^(hi|hello|hey|hallo)\b'),
        RegExp(r'\b(hi|hello|hey|hallo)$'),
        RegExp(r'^guten (tag|morgen|abend)'),
        RegExp(r'^(good (morning|evening|afternoon)|greetings)'),
      ],
      priority: 3,
    ),

    // Cheapest Product Intent
    IntentPattern(
      intent: ChatIntent.cheapestProduct,
      keywords: [
        'cheap',
        'cheapest',
        'affordable',
        'budget',
        'billig',
        'billigste',
        'günstig',
        'günstigste',
        'low price',
        'lowest price'
      ],
      patterns: [
        RegExp(r'\b(cheapest|most affordable|lowest price)'),
        RegExp(r'\b(billigste|günstigste)'),
        RegExp(r'what.*cheapest'),
        RegExp(r'show.*(cheap|affordable|budget)'),
      ],
      priority: 2,
    ),

    // Most Expensive Product Intent
    IntentPattern(
      intent: ChatIntent.mostExpensiveProduct,
      keywords: [
        'expensive',
        'most expensive',
        'pricey',
        'costly',
        'teuer',
        'teuerste',
        'high price',
        'highest price',
        'premium'
      ],
      patterns: [
        RegExp(r'\b(most expensive|highest price|priciest)'),
        RegExp(r'\b(teuerste)'),
        RegExp(r'what.*most expensive'),
        RegExp(r'show.*(expensive|premium|luxury)'),
      ],
      priority: 2,
    ),

    // Help Intent
    IntentPattern(
      intent: ChatIntent.help,
      keywords: [
        'help',
        'hilfe',
        'can you',
        'kannst du',
        'what can',
        'wie kann'
      ],
      patterns: [
        RegExp(r'(help|hilfe)'),
        RegExp(r'what can (you|i)'),
        RegExp(r'kannst du'),
      ],
      priority: 1,
    ),

    // Price Range Search Intent
    IntentPattern(
      intent: ChatIntent.priceRangeSearch,
      keywords: [
        'under',
        'below',
        'over',
        'above',
        'between',
        'from',
        'to',
        'cheaper',
        'expensive',
        'euro',
        'euros',
        'price range',
        'unter',
        'über',
        'zwischen',
        'von',
        'bis',
        'günstiger',
        'teurer',
      ],
      patterns: [
        RegExp(
            r'(under|below|cheaper than|less than|unter|maximum|max)\s*(€|euro|euros)?\s*\d+'),
        RegExp(
            r'(over|above|more than|greater than|über|minimum|min)\s*(€|euro|euros)?\s*\d+'),
        RegExp(
            r'(between|from|von)\s*(€|euro|euros)?\s*\d+\s*(and|to|bis|-)?\s*(€|euro|euros)?\s*\d+'),
        RegExp(r'(€|euro|euros)?\s*\d+\s*(-|to|bis)\s*(€|euro|euros)?\s*\d+'),
        RegExp(r'price range'),
      ],
      priority: 2,
    ),

    // Category Filter Intent
    IntentPattern(
      intent: ChatIntent.categoryFilter,
      keywords: [
        'category',
        'categories',
        'kategorie',
        'kategorien',
        'electronics',
        'elektronik',
        'food',
        'lebensmittel',
        'essen',
        'clothing',
        'kleidung',
        'clothes',
        'general',
        'allgemein',
        'accessories',
        'zubehör'
      ],
      patterns: [
        // Direct category mentions with action words
        RegExp(
            r'(show|list|zeig|liste|display).*(electronics|food|clothing|general|elektronik|lebensmittel|kleidung|allgemein)'),
        RegExp(
            r'(electronics|food|clothing|general|elektronik|lebensmittel|kleidung|allgemein).*(items|products|produkte|artikel)'),
        // Category questions
        RegExp(
            r'(what|was|which|welche).*(in|im|in der).*(category|kategorie)'),
        RegExp(
            r'(whats|was ist).*(in|im).*(electronics|food|clothing|general)'),
        // Specific category keywords
        RegExp(r'\b(electronics|elektronik)\b'),
        RegExp(r'\b(food|lebensmittel|essen)\b'),
        RegExp(r'\b(clothing|kleidung)\b'),
        RegExp(r'\b(general|allgemein)\b'),
      ],
      priority: 2,
    ),

    // Product Search Intent (lower priority, catches general queries)
    IntentPattern(
      intent: ChatIntent.productSearch,
      keywords: [
        'show',
        'find',
        'search',
        'looking for',
        'zeig',
        'suche',
        'finde'
      ],
      patterns: [
        RegExp(r'(show|zeig) (me|mir)'),
        RegExp(r'(looking|searching) for'),
        RegExp(r'ich suche'),
      ],
      priority: 1,
    ),
  ];
}
