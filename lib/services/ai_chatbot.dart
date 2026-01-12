// lib/services/ai_chatbot.dart
import 'package:webshop/models/product.dart';
import 'chatbot/intent_classifier.dart';
import 'chatbot/intent_handler_registry.dart';
import 'chatbot/conversation_context.dart';

/// A service that powers the AI Shopping Assistant.
///
/// This class handles the natural language processing (NLP) logic to understand
/// user queries and generate appropriate responses based on the available [Product] list.
///
/// **Implementation:** Uses Intent Classification with Registry Pattern.
/// Each user query is first classified into an intent, then routed to the
/// appropriate handler via the IntentHandlerRegistry.
///
/// **Architecture:**
/// - Intent Classification: Determines what the user wants
/// - Intent Handler Registry: Routes intents to handlers (replaces switch statement)
/// - Intent Handlers: Generate appropriate responses
/// - Product Extraction: Finds relevant products in queries
/// - Conversation Context: Tracks history for context-aware responses
/// - Response Formatter: Standardizes response formatting
///
/// **Note:** In a production environment, this would likely use a real NLP service
/// (like OpenAI, Gemini, or Dialogflow) for more sophisticated understanding.
class AIChatbotService {
  /// Conversation context for tracking history and state.
  final ConversationContext context;

  /// Creates a new chatbot service instance.
  ///
  /// [context] can be provided to continue an existing conversation,
  /// or a new context will be created automatically.
  AIChatbotService({ConversationContext? context})
      : context = context ?? ConversationContext();

  /// Generates a response to the user's query using Intent Classification.
  ///
  /// This is the main public method of the service. It processes the user's [query]
  /// in four steps:
  /// 1. **Add to History**: Stores the user's message in conversation context
  /// 2. **Intent Classification**: Determines what the user wants to achieve
  /// 3. **Intent Handling**: Routes to handler via registry (no switch statement)
  /// 4. **Store Response**: Adds bot response to conversation history
  ///
  /// * [query]: The raw text input from the chat widget.
  /// * [products]: The list of currently loaded products to search within.
  ///
  /// Returns a [Future<String>] to simulate network latency, making the
  /// chat experience feel more realistic.
  Future<String> respond(String query, List<Product> products) async {
    // Step 1: Add user message to conversation history
    context.addUserMessage(query);

    // UX: Simulate a small network delay ("typing" effect)
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 2: Classify the user's intent with context awareness
    final intent = IntentClassifier.classifyIntent(query, context: context);

    // Store intent in context for future reference
    context.setLastIntent(intent);

    // Step 3: Route to appropriate handler via registry
    final response = IntentHandlerRegistry.handle(
      intent,
      query,
      products,
      context: context,
    );

    // Step 4: Add bot response to conversation history
    context.addBotMessage(response);

    return response;
  }

  /// Clears the conversation history.
  void clearHistory() {
    context.clear();
  }

  /// Gets the conversation history.
  List<Map<String, String>> getHistory() {
    return context.history
        .map((msg) => {'sender': msg.sender, 'text': msg.text})
        .toList();
  }

  /// Gets the number of messages in the conversation.
  int get messageCount => context.messageCount;

  /// Checks if there's any conversation history.
  bool get hasHistory => !context.isEmpty;
}
