import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/product.dart';

import 'package:webshop/services/recommendation_service.dart';
import 'package:webshop/repositories/product_repository.dart';

void main() {
  group('RecommendationService Zusatz-Logik', () {
    late RecommendationService service;
    final products = [
      Product(id: '1', name: 'A', description: '', price: 1, imageUrl: '', stock: 1, category: 'X'),
      Product(id: '2', name: 'B', description: '', price: 2, imageUrl: '', stock: 1, category: 'Y'),
      Product(id: '3', name: 'C', description: '', price: 3, imageUrl: '', stock: 1, category: 'X'),
    ];

    setUp(() {
      service = RecommendationService(FakeProductRepository(products), null);
    });

    test('Recent Views überschreitet Limit', () async {
      for (int i = 0; i < 25; i++) {
        await service.recordProductView(productId: i.toString());
      }
      final recent = service.getRecent(null);
      expect(recent.length <= 20, true);
      expect(recent.first, '24');
      expect(recent.last, '5');
    });

    test('getRelatedProducts gibt leere Liste bei leerem Katalog', () async {
      final emptyService = RecommendationService(FakeProductRepository([]), null);
      final related = await emptyService.getRelatedProducts('1');
      expect(related, isEmpty);
    });
  });
}

class FakeProductRepository implements ProductRepository {
  final List<Product> products;
  FakeProductRepository(this.products);
  @override
  Stream<List<Product>> getProductsStream() => throw UnimplementedError();
  @override
  Future<Product?> getProductById(String id) async {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }
  @override
  Future<List<Product>> getProductsByCategory(String category, {int limit = 10}) async =>
      this.products.where((p) => p.category == category).take(limit).toList();
  @override
  Future<List<Product>> searchProductsByText(String query, {int limit = 10}) async =>
      this.products.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).take(limit).toList();
  @override
  Future<QuerySnapshot<Object?>> getProductsPage({int limit = 10, DocumentSnapshot<Object?>? lastDocument}) => throw UnimplementedError();
}
