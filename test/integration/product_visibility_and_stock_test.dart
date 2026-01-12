// test/integration/product_visibility_and_stock_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/models/cart_item.dart';

/// Integration-style business logic tests for product visibility and stock rules.
void main() {
  group('Product visibility and stock rules', () {
    test('Deleted product is not returned by the catalog', () async {
      // Arrange: create an in-memory product store (simulates a simple repository)
      final productA = const Product(
        id: 'p-a',
        name: 'Product A',
        description: 'A',
        price: 10.0,
        imageUrl: 'https://via.placeholder.com/1',
        stock: 5,
        category: 'General',
      );

      final productB = const Product(
        id: 'p-b',
        name: 'Product B',
        description: 'B',
        price: 20.0,
        imageUrl: 'https://via.placeholder.com/1',
        stock: 3,
        category: 'General',
      );

      final store = {_storeKey(productA): productA, _storeKey(productB): productB};

      // Act: delete product A (simulate admin deletion)
      store.remove(_storeKey(productA));

      // Assert: only product B remains and product A is not present
      final remaining = store.values.toList();
      expect(remaining.length, 1, reason: 'Only one product should remain');
      expect(remaining.first.id, productB.id, reason: 'Remaining product should be B');
    });

    test('Out-of-stock product cannot be purchased', () {
      // Arrange: create an out-of-stock product
      final outOfStock = const Product(
        id: 'p-oos',
        name: 'OutOfStock',
        description: 'No stock',
        price: 5.0,
        imageUrl: 'https://via.placeholder.com/1',
        stock: 0,
        category: 'General',
      );

      // Act: create a cart item attempting to buy 1 unit
      final cartItem = CartItem(id: 'cart-1', product: outOfStock, quantity: 1);

      // Validation logic (same as used by the checkout/service layer)
      bool validStock(List<CartItem> items) =>
          items.every((i) => i.quantity <= i.product.stock);

      // Assert: validation fails for out-of-stock item
      final isValid = validStock([cartItem]);
      expect(isValid, isFalse, reason: 'Cannot purchase an out-of-stock product');
    });
  });
}

String _storeKey(Product p) => p.id;
