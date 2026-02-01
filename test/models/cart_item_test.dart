// test/models/cart_item_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/cart_item.dart';
import 'package:webshop/models/product.dart';

void main() {
  group('CartItem Model Tests', () {
    late Product testProduct;

    setUp(() {
      testProduct = Product(
        id: 'prod-1',
        name: 'Test Product',
        description: 'A test product',
        price: 25.00,
        imageUrl: 'https://example.com/test.jpg',
        stock: 10,
        category: 'General',
      );
    });

    test('CartItem should be created with valid data', () {
      final cartItem = CartItem(
        id: 'cart-1',
        product: testProduct,
        quantity: 2,
      );

      expect(cartItem.id, 'cart-1',
          reason: 'CartItem ID should match the provided value');
      expect(cartItem.product.id, 'prod-1',
          reason: 'CartItem should contain the correct product');
      expect(cartItem.quantity, 2, reason: 'CartItem quantity should be 2');
    });

    test('CartItem.fromMap should correctly deserialize data', () {
      final cartItemMap = {
        'productId': 'prod-test',
        'quantity': 4,
      };

      // Note: fromMap requires a Product instance
      final cartItem = CartItem.fromMap(cartItemMap, 'cart-3', testProduct);

      expect(cartItem.id, 'cart-3',
          reason: 'Deserialized CartItem should have correct ID');
      expect(cartItem.quantity, 4,
          reason: 'Quantity should be correctly deserialized from map');
      expect(cartItem.product.id, 'prod-1',
          reason: 'Product should be correctly linked to CartItem');
    });

    test('CartItem.toMap should correctly serialize data', () {
      final cartItem = CartItem(
        id: 'cart-4',
        product: testProduct,
        quantity: 2,
      );

      final map = cartItem.toMap();

      expect(map['quantity'], 2,
          reason: 'Serialized map should contain correct quantity');
      expect(map['productId'], 'prod-1',
          reason:
              'Serialized map should contain product ID, not full product object');
    });

    test('CartItem.copyWith should create a new instance with updated values',
        () {
      final cartItem = CartItem(
        id: 'cart-5',
        product: testProduct,
        quantity: 2,
      );

      final updated = cartItem.copyWith(quantity: 5);

      expect(updated.quantity, 5,
          reason: 'copyWith should update quantity to new value');
      expect(updated.id, 'cart-5',
          reason: 'copyWith should preserve ID when not changed');
      expect(updated.product, testProduct,
          reason: 'copyWith should preserve product when not changed');
      expect(cartItem.quantity, 2,
          reason: 'Original CartItem should remain unchanged (immutability)');
    });

    test('CartItem should handle quantity of 1', () {
      final cartItem = CartItem(
        id: 'cart-6',
        product: testProduct,
        quantity: 1,
      );

      expect(cartItem.quantity, 1);
      final totalPrice = cartItem.product.price * cartItem.quantity;
      expect(totalPrice, 25.00);
    });

    test('CartItem should handle large quantities', () {
      final cartItem = CartItem(
        id: 'cart-7',
        product: testProduct,
        quantity: 100,
      );

      expect(cartItem.quantity, 100);
      final totalPrice = cartItem.product.price * cartItem.quantity;
      expect(totalPrice, 2500.00);
    });
  });
}
