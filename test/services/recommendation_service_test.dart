import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Minimal stubs to satisfy the interface without touching Firebase.
  @override
  Future<QuerySnapshot<Object?>> getProductsPage({int limit = 10, DocumentSnapshot<Object?>? lastDocument}) async {
    throw UnimplementedError('getProductsPage is not used in this test');
  }

  @override
  Stream<List<Product>> getProductsStream() {
    return Stream.empty();
  }

  @override
  Future<List<Product>> searchProductsByText(String queryText, {int limit = 50}) async {
    return _products.values.where((p) => p.name.toLowerCase().contains(queryText.toLowerCase())).take(limit).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecommendationService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('records and returns recent views', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeRepo({
        'p1': Product(id: 'p1', name: 'A', description: '', price: 1.0, imageUrl: '', stock: 10, category: 'cat1'),
      });

      final service = RecommendationService(repo, prefs);

      await service.recordProductView(userId: 'u1', productId: 'p1');
      final recent = service.getRecent('u1');
      expect(recent, ['p1']);
    });

    test('getRelatedProducts returns items in same category', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeRepo({
        'p1': Product(id: 'p1', name: 'A', description: '', price: 1.0, imageUrl: '', stock: 10, category: 'cat1'),
        'p2': Product(id: 'p2', name: 'B', description: '', price: 2.0, imageUrl: '', stock: 5, category: 'cat1'),
      });

      final service = RecommendationService(repo, prefs);
      final related = await service.getRelatedProducts('p1', limit: 5);
      expect(related.any((p) => p.id == 'p2'), true);
    });

    test('migrates in-memory history to SharedPreferences', () async {
      final repo = _FakeRepo({
        'p1': Product(id: 'p1', name: 'A', description: '', price: 1.0, imageUrl: '', stock: 10, category: 'cat1'),
      });

      final service = RecommendationService(repo, null);

      // Record some in-memory views for user u1
      await service.recordProductView(userId: 'u1', productId: 'p1');
      await service.recordProductView(userId: 'u1', productId: 'p2');

      // Ensure they're in-memory (prefs not set)
      expect(service.getRecent('u1'), ['p2', 'p1']);

      // Now create prefs and migrate
      SharedPreferences.setMockInitialValues({'recently_viewed_u1': ['p1']});
      final prefs = await SharedPreferences.getInstance();

      await service.migrateToPrefs(prefs);

      // After migration, prefs should contain merged list with in-memory items first
      final stored = prefs.getStringList('recently_viewed_u1');
      expect(stored, isNotNull);
      expect(stored, containsAll(['p2', 'p1']));

      // getRecent should now read from prefs
      expect(service.getRecent('u1'), stored);
    });
  });
}
