// lib/widgets/chat_panel.dart
import 'package:flutter/material.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/services/ai_chatbot.dart';
import 'package:webshop/utils/constants.dart';

class PersistentChatPanel extends StatefulWidget {
  final List<Product> products;
  final VoidCallback onClose;

  const PersistentChatPanel({
    super.key,
    required this.products,
    required this.onClose,
  });

  @override
  State<PersistentChatPanel> createState() => _PersistentChatPanelState();
}

class _PersistentChatPanelState extends State<PersistentChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];

  // Use the service instance directly
  final AIChatbotService _aiService = AIChatbotService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'sender': 'bot',
      'text':
          'Hello! I\'m your AI Shopping Assistant. Ask me about products, prices, or availability!'
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      // FIX: We no longer map to _ProductData. We pass the full Product list directly.
      final response = await _aiService.respond(text, widget.products);

      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': response});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'Sorry, I encountered an error. Please try again.'
          });
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildMessagesArea(context),
        _buildInputArea(context),
      ],
    );
  }

  /// Builds the chat header with title and close button.
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(smallPadding),
      color: Theme.of(context).primaryColor,
      child: Row(
        children: [
          const Icon(Icons.smart_toy, color: Colors.white),
          const SizedBox(width: 8),
          const Text(
            'AI Assistant',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: widget.onClose,
          )
        ],
      ),
    );
  }

  /// Builds the messages display area.
  Widget _buildMessagesArea(BuildContext context) {
    return Expanded(
      child: Container(
        color: Colors.grey[100],
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(smallPadding),
          itemCount: _messages.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (_isLoading && index == _messages.length) {
              return _buildLoadingIndicator();
            }
            final msg = _messages[index];
            final isUser = msg['sender'] == 'user';
            return _buildMessageBubble(context, msg['text']!, isUser);
          },
        ),
      ),
    );
  }

  /// Builds a loading indicator for bot responses.
  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// Builds a single message bubble.
  Widget _buildMessageBubble(BuildContext context, String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  /// Builds the message input area at the bottom.
  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Ask about products...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
