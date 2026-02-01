import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/services/ai_chatbot.dart';
void main() {
  group('AIChatbotService', () {
    late AIChatbotService bot;
    final products = [
      Product(id: '1', name: 'Shirt', description: 'Blue cotton shirt', price: 10, imageUrl: '', stock: 5, category: 'Clothing'),
      Product(id: '2', name: 'Pants', description: 'Black pants', price: 20, imageUrl: '', stock: 3, category: 'Clothing'),
    ];

    setUp(() {
      bot = AIChatbotService();
    });

    // Tests if the chatbot responds to greeting intent
    test('responds to greeting intent', () async {
      final r = await bot.respond('hello', products);
      expect(r.toLowerCase(), contains('hello'));
      expect(bot.hasHistory, true);
    });

    // Checks if the chatbot recognizes a product search and returns relevant product information.
    test('responds to product search intent', () async {
      final r = await bot.respond('show me shirt', products);
      expect(r.toLowerCase(), contains('shirt'));
    });

    // Tests if the chatbot correctly answers a price follow-up question in context after a product search.
    test('context follow-up: price inquiry', () async {
      await bot.respond('show me shirt', products);
      final r = await bot.respond('how much is it?', products);
      expect(r.toLowerCase(), anyOf(contains('costs'), contains('€')));
    });

    // Checks if the chatbot history grows correctly and can be cleared with clearHistory.
    test('history and clearHistory', () async {
      await bot.respond('hi', products);
      expect(bot.getHistory().length, 2);
      bot.clearHistory();
      expect(bot.hasHistory, false);
    });

    // Tests if the chatbot responds to unknown/smalltalk input with a fallback answer.
    test('responds to unknown/smalltalk intent', () async {
      final r = await bot.respond('How are you?', products);
      expect(r.toLowerCase(), anyOf(contains('sorry'), contains('not sure'), contains('help')));
    });

    // Checks if the chatbot can handle a category search intent.
    test('responds to category search intent', () async {
      final r = await bot.respond('Show me clothing', products);
      expect(r.toLowerCase(), anyOf(contains('shirt'), contains('pants')));
    });

    // Tests if the chatbot can answer a cheapest product inquiry.
    test('responds to cheapest product intent', () async {
      final r = await bot.respond('What is the cheapest product?', products);
      expect(r.toLowerCase(), anyOf(contains('cheapest')));
    });

    // Tests if the chatbot responds to a help intent.
    test('responds to help intent', () async {
      final r = await bot.respond('help', products);
      expect(r.toLowerCase(), contains('help'));
    });

    // Checks if the conversation history grows with multiple messages.
    test('conversation history grows with multiple messages', () async {
      await bot.respond('hi', products);
      await bot.respond('show me shirt', products);
      await bot.respond('how much is it?', products);
      expect(bot.getHistory().length, 6); // 3 user + 3 bot
    });
  });
}
