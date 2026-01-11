// lib/services/chatbot/conversation_context.dart
import 'chat_message.dart';
import 'chat_intent.dart';

/// Manages conversation history and context for context-aware responses.
///
/// This class enables:
/// - Conversation history tracking
/// - Context-aware intent classification
/// - Follow-up question handling
/// - Easy extensibility for future features (categories, recommendations, etc.)
class ConversationContext {
  /// Complete conversation history.
  final List<ChatMessage> _history = [];

  /// Maximum number of messages to keep in history.
  /// Prevents memory issues with very long conversations.
  final int maxHistoryLength;

  /// Optional: Track the last detected intent for follow-up questions.
  ChatIntent? _lastIntent;

  /// Optional: Track the last mentioned product for context.
  String? _lastProductId;

  /// Optional: Track conversation metadata (e.g., active category filter).
  final Map<String, dynamic> _sessionMetadata = {};

  ConversationContext({this.maxHistoryLength = 50});

  /// Adds a user message to the conversation history.
  void addUserMessage(String text, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage.user(text, metadata: metadata));
  }

  /// Adds a bot message to the conversation history.
  void addBotMessage(String text, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage.bot(text, metadata: metadata));
  }

  /// Internal method to add a message and manage history size.
  void _addMessage(ChatMessage message) {
    _history.add(message);

    // Maintain max history length
    if (_history.length > maxHistoryLength) {
      _history.removeAt(0);
    }
  }

  /// Gets the complete conversation history.
  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Gets only user messages.
  List<ChatMessage> get userMessages =>
      _history.where((m) => m.isUser).toList();

  /// Gets only bot messages.
  List<ChatMessage> get botMessages => _history.where((m) => m.isBot).toList();

  /// Gets the last N messages.
  List<ChatMessage> getRecentMessages(int count) {
    if (_history.length <= count) return history;
    return _history.sublist(_history.length - count);
  }

  /// Gets the last user message, or null if none exists.
  ChatMessage? get lastUserMessage {
    try {
      return userMessages.last;
    } catch (_) {
      return null;
    }
  }

  /// Gets the last bot message, or null if none exists.
  ChatMessage? get lastBotMessage {
    try {
      return botMessages.last;
    } catch (_) {
      return null;
    }
  }

  /// Sets the last detected intent (for context-aware follow-ups).
  void setLastIntent(ChatIntent intent, {String? productId}) {
    _lastIntent = intent;
    if (productId != null) {
      _lastProductId = productId;
    }
  }

  /// Gets the last detected intent.
  ChatIntent? get lastIntent => _lastIntent;

  /// Gets the last mentioned product ID.
  String? get lastProductId => _lastProductId;

  /// Sets session metadata (e.g., active category filter, price range).
  ///
  /// Example for future category feature:
  /// ```dart
  /// context.setMetadata('activeCategory', 'electronics');
  /// ```
  void setMetadata(String key, dynamic value) {
    _sessionMetadata[key] = value;
  }

  /// Gets session metadata.
  dynamic getMetadata(String key) {
    return _sessionMetadata[key];
  }

  /// Checks if a metadata key exists.
  bool hasMetadata(String key) {
    return _sessionMetadata.containsKey(key);
  }

  /// Clears a specific metadata key.
  void clearMetadata(String key) {
    _sessionMetadata.remove(key);
  }

  /// Clears all conversation history and context.
  void clear() {
    _history.clear();
    _lastIntent = null;
    _lastProductId = null;
    _sessionMetadata.clear();
  }

  /// Checks if the conversation is empty.
  bool get isEmpty => _history.isEmpty;

  /// Gets the number of messages in the conversation.
  int get messageCount => _history.length;

  /// Exports conversation history to JSON for persistence.
  Map<String, dynamic> toJson() {
    return {
      'history': _history.map((m) => m.toJson()).toList(),
      'lastIntent': _lastIntent?.name,
      'lastProductId': _lastProductId,
      'sessionMetadata': _sessionMetadata,
    };
  }

  /// Imports conversation history from JSON.
  void fromJson(Map<String, dynamic> json) {
    clear();

    final historyList = json['history'] as List?;
    if (historyList != null) {
      for (final messageJson in historyList) {
        _history.add(ChatMessage.fromJson(messageJson as Map<String, dynamic>));
      }
    }

    final intentName = json['lastIntent'] as String?;
    if (intentName != null) {
      _lastIntent = ChatIntent.values.firstWhere(
        (e) => e.name == intentName,
        orElse: () => ChatIntent.unknown,
      );
    }

    _lastProductId = json['lastProductId'] as String?;

    final metadata = json['sessionMetadata'] as Map<String, dynamic>?;
    if (metadata != null) {
      _sessionMetadata.addAll(metadata);
    }
  }
}
