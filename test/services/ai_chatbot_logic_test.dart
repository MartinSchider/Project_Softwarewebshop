import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/services/ai_chatbot.dart';

void main() {
  group('AIChatbotService Zusatz-Logik', () {
    late AIChatbotService bot;
    final products = [
      Product(id: '1', name: 'Shirt', description: 'Blue cotton shirt', price: 10, imageUrl: '', stock: 5, category: 'Clothing'),
      Product(id: '2', name: 'Pants', description: 'Black pants', price: 20, imageUrl: '', stock: 3, category: 'Clothing'),
    ];

    setUp(() {
      bot = AIChatbotService();
    });

    test('leere Eingabe gibt sinnvolle Antwort', () async {
      final r = await bot.respond('', products);
      expect(r, isNotEmpty);
    });

    test('clearHistory leert Verlauf', () async {
      await bot.respond('hi', products);
      bot.clearHistory();
      expect(bot.getHistory(), isEmpty);
    });

    test('History Reihenfolge stimmt', () async {
      await bot.respond('eins', products);
      await bot.respond('zwei', products);
      final history = bot.getHistory();
      expect(history.length, 4); // 2 user + 2 bot
      expect(history[0]['sender'], 'user');
      expect(history[1]['sender'], 'bot');
      expect(history[2]['text'], 'zwei');
    });
  });
}
