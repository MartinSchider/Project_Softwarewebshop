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
        category: 'General',
      );

      expect(product.id, 'test-1');
      expect(product.name, 'Test Product');
      expect(product.description, 'A test product');
      expect(product.price, 29.99);
      expect(product.stock, 10);
    });

    // Test Product.fromMap deserialization from Firestore-like data structure
    test('Product.fromMap should correctly deserialize data', () {
      final map = {
        'productName': 'Sample Product',
        'productDescription': 'Sample description',
        'productPrice': 49.99,
        'imageUrl': 'https://example.com/sample.jpg',
        'stock': 5,
        'category': 'Electronics',
      };

      final product = Product.fromMap(map, 'prod-123');

      expect(product.id, 'prod-123',
          reason: 'Product ID should match the provided document ID');
      expect(product.name, 'Sample Product',
          reason: 'Product name should be deserialized from map');
      expect(product.price, 49.99,
          reason: 'Product price should be correctly parsed from map');
      expect(product.stock, 5,
          reason: 'Product stock should be correctly parsed from map');
      expect(product.category, 'Electronics',
          reason: 'Product category should be correctly parsed from map');
    });

    test('Product.toMap should correctly serialize data', () {
      final product = Product(
        id: 'test-2',
        name: 'Widget',
        description: 'A widget product',
        price: 15.50,
        imageUrl: 'https://example.com/widget.jpg',
        stock: 20,
        category: 'General',
      );

      final map = product.toMap();

      // Verify that toMap returns Firestore field names (not internal field names)
      expect(map['productName'], 'Widget',
          reason: 'Serialized map should contain correct product name');
      expect(map['productPrice'], 15.50,
          reason: 'Serialized map should contain correct product price');
      expect(map['stock'], 20,
          reason: 'Serialized map should contain correct stock value');
      expect(map['category'], 'General',
          reason: 'Serialized map should contain correct category');
      expect(map['productDescription'], 'A widget product',
          reason: 'Serialized map should contain correct description');
      expect(map['imageUrl'], 'https://example.com/widget.jpg',
          reason: 'Serialized map should contain correct image URL');
    });

    test('Product should handle zero stock', () {
      final product = Product(
        id: 'out-of-stock',
        name: 'Unavailable Product',
        description: 'Currently unavailable',
        price: 99.99,
        imageUrl: 'https://example.com/unavailable.jpg',
        stock: 0,
        category: 'General',
      );

      expect(product.stock, 0,
          reason: 'Out of stock product should have stock value of 0');
      expect(product.stock == 0, true,
          reason: 'Stock validation should correctly identify zero stock');
    });

    test('Product should handle decimal prices', () {
      final product = Product(
        id: 'decimal-price',
        name: 'Precise Product',
        description: 'Product with precise pricing',
        price: 19.99,
        imageUrl: 'https://example.com/precise.jpg',
        stock: 5,
        category: 'General',
      );

      expect(product.price, 19.99,
          reason: 'Product should handle decimal prices correctly');
      expect(product.price.toStringAsFixed(2), '19.99',
          reason:
              'Price formatting should produce correct string representation');
    });
  });
}
