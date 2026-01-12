import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webshop/providers/recommendations_provider.dart';
import 'package:webshop/repositories/product_repository.dart';
import 'package:webshop/models/product.dart';
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
  Future<QuerySnapshot<Object?>> getProductsPage({int limit = 10, DocumentSnapshot<Object?>? lastDocument}) async => throw UnimplementedError();

  @override
  Stream<List<Product>> getProductsStream() => Stream.empty();

  @override
  Future<List<Product>> searchProductsByText(String category, {int limit = 50}) async => _products.values.toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recordView increments notifier state', () async {
    SharedPreferences.setMockInitialValues({});
    final service = RecommendationService(_FakeRepo({}), null);
    final notifier = RecommendationsNotifier(service);

    expect(notifier.debugState, 0);
    await notifier.recordView(userId: 'u1', productId: 'p1');
    expect(notifier.debugState, 1);
    await notifier.recordView(userId: 'u1', productId: 'p2');
    expect(notifier.debugState, 2);
  });
}
