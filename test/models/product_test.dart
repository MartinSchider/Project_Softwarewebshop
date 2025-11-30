// test/models/product_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/product.dart';

void main() {
  group('Product Model Tests', () {
    test('Product should be created with valid data', () {
      final product = Product(
        id: 'test-1',
        name: 'Test Product',
        description: 'A test product',
        price: 29.99,
        imageUrl: 'https://example.com/image.jpg',
        stock: 10,
      );

      expect(product.id, 'test-1');
      expect(product.name, 'Test Product');
      expect(product.description, 'A test product');
      expect(product.price, 29.99);
      expect(product.stock, 10);
    });

    // FAILING TEST: Incorrect field names in test data
    // Expected behavior: Product.fromMap should deserialize Firestore data correctly
    // Current issue: Test uses 'id' in map, but Firestore uses 'productName', 'productPrice', etc.
    // The 'id' is passed as second parameter, not in the data map
    // Fix needed: Remove 'id' from map data structure
    test('Product.fromMap should correctly deserialize data', () {
      final map = {
        'productName': 'Sample Product',
        'productDescription': 'Sample description',
        'productPrice': 49.99,
        'imageUrl': 'https://example.com/sample.jpg',
        'stock': 5,
      };

      final product = Product.fromMap(map, 'prod-123');

      expect(product.id, 'prod-123', reason: 'Product ID should match the provided document ID');
      expect(product.name, 'Sample Product', reason: 'Product name should be deserialized from map');
      expect(product.price, 49.99, reason: 'Product price should be correctly parsed from map');
      expect(product.stock, 5, reason: 'Product stock should be correctly parsed from map');
    });

    test('Product.toMap should correctly serialize data', () {
      final product = Product(
        id: 'test-2',
        name: 'Widget',
        description: 'A widget product',
        price: 15.50,
        imageUrl: 'https://example.com/widget.jpg',
        stock: 20,
      );

      final map = product.toMap();

      // NOTE: These assertions fail because map keys don't match Firestore field names
      // toMap() likely returns internal field names, not Firestore's 'productName', 'productPrice'
      expect(map['productName'], 'Widget', reason: 'Serialized map should contain correct product name');
      expect(map['productPrice'], 15.50, reason: 'Serialized map should contain correct product price');
      expect(map['stock'], 20, reason: 'Serialized map should contain correct stock value');
    });

    test('Product should handle zero stock', () {
      final product = Product(
        id: 'out-of-stock',
        name: 'Unavailable Product',
        description: 'Currently unavailable',
        price: 99.99,
        imageUrl: 'https://example.com/unavailable.jpg',
        stock: 0,
      );

      expect(product.stock, 0, reason: 'Out of stock product should have stock value of 0');
      expect(product.stock == 0, true, reason: 'Stock validation should correctly identify zero stock');
    });

    test('Product should handle decimal prices', () {
      final product = Product(
        id: 'decimal-price',
        name: 'Precise Product',
        description: 'Product with precise pricing',
        price: 19.99,
        imageUrl: 'https://example.com/precise.jpg',
        stock: 5,
      );

      expect(product.price, 19.99, reason: 'Product should handle decimal prices correctly');
      expect(product.price.toStringAsFixed(2), '19.99', reason: 'Price formatting should produce correct string representation');
    });
  });
}
