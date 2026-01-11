// lib/services/chatbot/intent_pattern.dart
import 'chat_intent.dart';

/// Defines patterns for recognizing specific intents.
///
/// Each pattern contains:
/// - The target intent
/// - Keywords for simple matching
/// - Regex patterns for more precise matching
/// - Priority for conflict resolution (higher = checked first)
class IntentPattern {
  final ChatIntent intent;
  final List<String> keywords;
  final List<RegExp>? patterns;
  final int priority;

  const IntentPattern({
    required this.intent,
    required this.keywords,
    this.patterns,
    this.priority = 0,
  });
}
