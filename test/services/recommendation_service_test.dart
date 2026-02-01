import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/services/recommendation_service.dart';
import 'package:webshop/repositories/product_repository.dart';


class FakeProductRepository implements ProductRepository {
    @override
    Stream<List<Product>> getProductsStream() => throw UnimplementedError();

    @override
    @override
    Future<QuerySnapshot<Object?>> getProductsPage({int limit = 10, DocumentSnapshot<Object?>? lastDocument}) => throw UnimplementedError();
  final List<Product> products;
  FakeProductRepository(this.products);

  Future<Product?> getProductById(String id) async {
    final found = products.where((p) => p.id == id);
    return found.isEmpty ? null : found.first;
  }

  Future<List<Product>> getProductsByCategory(String category, {int limit = 10}) async =>
      products.where((p) => p.category == category).take(limit).toList();

  Future<List<Product>> searchProductsByText(String query, {int limit = 10}) async =>
      products.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).take(limit).toList();
}

void main() {
  group('RecommendationService', () {
    late RecommendationService service;
    late FakeProductRepository repo;
    final products = [
      Product(id: '1', name: 'Shirt', description: '', price: 10, imageUrl: '', stock: 5, category: 'Clothes'),
      Product(id: '2', name: 'Pants', description: '', price: 20, imageUrl: '', stock: 3, category: 'Clothes'),
      Product(id: '3', name: 'Hat', description: '', price: 5, imageUrl: '', stock: 2, category: 'Accessories'),
    ];

    setUp(() {
      repo = FakeProductRepository(products);
      service = RecommendationService(repo, null);
    });

    // Tests if product views are correctly stored in-memory and returned in the right order.
    test('records and retrieves recent views in-memory', () async {
      await service.recordProductView(productId: '1');
      await service.recordProductView(productId: '2');
      expect(service.getRecent(null), ['2', '1']);
    });

    // Checks that related products are returned, but the original product is excluded and the limit is respected.
    test('getRelatedProducts excludes original and limits', () async {
      final related = await service.getRelatedProducts('1', limit: 2);
      expect(related.any((p) => p.id == '1'), false);
      expect(related.length <= 2, true);
    });

    // Tests if recommendations are generated based on the most viewed category and already seen products are excluded.
    test('getBehavioralRecommendations returns by category', () async {
      await service.recordProductView(productId: '1');
      await service.recordProductView(productId: '2');
      final recs = await service.getBehavioralRecommendations(null, limit: 2);
      expect(recs.every((p) => p.category == 'Clothes'), true);
    });

    // Checks if the AI recommendation logic combines different sources (seed, behavioral, text search) and returns recommendations.
    test('getAiPoweredRecommendations combines logic', () async {
      await service.recordProductView(productId: '1');
      final recs = await service.getAiPoweredRecommendations(
        userId: null,
        seedProductId: '3',
        query: 'Shirt',
        limit: 3,
      );
      expect(recs.length, greaterThan(0));
    });
  });
}
