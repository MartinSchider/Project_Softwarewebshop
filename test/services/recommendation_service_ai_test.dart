import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/product_repository.dart';
import 'package:webshop/services/recommendation_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class _FakeRepo implements ProductRepository {
  final Map<String, Product> _products;
  _FakeRepo(this._products);

  @override
  Future<Product?> getProductById(String id) async {
    return _products[id];
  }

  @override
  Future<List<Product>> getProductsByCategory(String category, {int limit = 10}) async {
    return _products.values.where((p) => p.category == category).take(limit).toList();
  }

  @override
  Stream<List<Product>> getProductsStream() => Stream.empty();

  @override
  Future<QuerySnapshot<Object?>> getProductsPage({int limit = 10, DocumentSnapshot<Object?>? lastDocument}) async => throw UnimplementedError();

  @override
  Future<List<Product>> searchProductsByText(String queryText, {int limit = 50}) async {
    return _products.values.where((p) => p.name.toLowerCase().contains(queryText.toLowerCase())).take(limit).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Recommendations', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns behavioral category items and excludes recently viewed', () async {
      final products = {
        'p1': Product(id: 'p1', name: 'Alpha Shoe', description: '', price: 10.0, imageUrl: '', stock: 10, category: 'shoes'),
        'p2': Product(id: 'p2', name: 'Beta Shoe', description: '', price: 20.0, imageUrl: '', stock: 5, category: 'shoes'),
        'p3': Product(id: 'p3', name: 'Gamma Hat', description: '', price: 5.0, imageUrl: '', stock: 3, category: 'hats'),
        'p4': Product(id: 'p4', name: 'Delta Shirt', description: '', price: 15.0, imageUrl: '', stock: 8, category: 'shirts'),
        'p5': Product(id: 'p5', name: 'Epsilon Shoe', description: '', price: 12.0, imageUrl: '', stock: 7, category: 'shoes'),
      };

      final repo = _FakeRepo(products);
      final prefs = await SharedPreferences.getInstance();
      final service = RecommendationService(repo, prefs);

      // Record recent views for user u1: mostly shoes
      await service.recordProductView(userId: 'u1', productId: 'p1');
      await service.recordProductView(userId: 'u1', productId: 'p2');

      // Ensure the AI recommendations exclude p1/p2 and favor shoes category
      final ai = await service.getAiPoweredRecommendations(userId: 'u1', limit: 3);
      expect(ai.length, greaterThan(0));
      // Ensure recommended items are not the ones we already viewed
      expect(ai.where((p) => p.id == 'p1' || p.id == 'p2'), isEmpty);
    });

    test('seed product yields related items', () async {
      final products = {
        'p1': Product(id: 'p1', name: 'Alpha Shoe', description: '', price: 10.0, imageUrl: '', stock: 10, category: 'shoes'),
        'p2': Product(id: 'p2', name: 'Beta Shoe', description: '', price: 20.0, imageUrl: '', stock: 5, category: 'shoes'),
        'p3': Product(id: 'p3', name: 'Gamma Hat', description: '', price: 5.0, imageUrl: '', stock: 3, category: 'hats'),
      };

      final repo = _FakeRepo(products);
      final prefs = await SharedPreferences.getInstance();
      final service = RecommendationService(repo, prefs);

      final ai = await service.getAiPoweredRecommendations(seedProductId: 'p1', limit: 2);
      expect(ai.length, greaterThan(0));
      expect(ai.any((p) => p.category == 'shoes' && p.id != 'p1'), isTrue);
    });
  });
}
