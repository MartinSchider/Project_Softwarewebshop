// lib/services/chatbot/chat_message.dart

/// Represents a single message in the conversation.
class ChatMessage {
  final String sender;
  final String text;
  final DateTime timestamp;

  /// Optional metadata for future extensions (e.g., product references, categories)
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.sender,
    required this.text,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a user message.
  factory ChatMessage.user(String text, {Map<String, dynamic>? metadata}) {
    return ChatMessage(
      sender: 'user',
      text: text,
      metadata: metadata,
    );
  }

  /// Creates a bot message.
  factory ChatMessage.bot(String text, {Map<String, dynamic>? metadata}) {
    return ChatMessage(
      sender: 'bot',
      text: text,
      metadata: metadata,
    );
  }

  /// Checks if this is a user message.
  bool get isUser => sender == 'user';

  /// Checks if this is a bot message.
  bool get isBot => sender == 'bot';

  /// Converts to JSON for storage/persistence.
  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Creates from JSON.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
