// test/models/order_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/order.dart' as model;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/models/cart_item.dart';

void main() {
  group('Order Model Tests', () {
    late List<CartItem> testCartItems;

    setUp(() {
      final product1 = Product(
        id: 'prod-1',
        name: 'Product 1',
        description: 'First product',
        price: 20.00,
        imageUrl: 'https://example.com/1.jpg',
        stock: 10,
        category: 'General',
      );

      final product2 = Product(
        id: 'prod-2',
        name: 'Product 2',
        description: 'Second product',
        price: 30.00,
        imageUrl: 'https://example.com/2.jpg',
        stock: 5,
        category: 'General',
      );

      testCartItems = [
        CartItem(id: 'cart-1', product: product1, quantity: 2),
        CartItem(id: 'cart-2', product: product2, quantity: 1),
      ];
    });

    test('Order should be created with valid data', () {
      final now = DateTime.now();
      final order = model.Order(
        id: 'order-1',
        orderId: 'ORD-12345',
        items: testCartItems,
        totalPrice: 70.00,
        finalAmountPaid: 70.00,
        giftCardAppliedAmount: 0.00,
        status: 'pending',
        timestamp: now,
      );

      expect(order.id, 'order-1',
          reason: 'Order ID should match the provided value');
      expect(order.orderId, 'ORD-12345',
          reason: 'Order should have the correct user-facing order ID');
      expect(order.items.length, 2,
          reason: 'Order should contain 2 cart items');
      expect(order.totalPrice, 70.00, reason: 'Total price should be 70.00');
      expect(order.finalAmountPaid, 70.00,
          reason:
              'Final amount paid should equal total price when no discount applied');
      expect(order.status, 'pending',
          reason: 'New order should have pending status');
    });

    // More meaningful tests that verify parsing and defaults from Firestore data
    test('fromMap reconstructs items and fields correctly', () {
      final ts = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final data = {
        'orderId': 'ORD-123',
        'items': [
          {
            'productId': 'p1',
            'productName': 'Blue Shirt',
            'productPrice': 19.99,
            'quantity': 2,
            'imageUrl': 'https://example.com/blue.jpg',
            'category': 'Clothing',
          }
        ],
        'totalPrice': 39.98,
        'finalAmountPaid': 39.98,
        'giftCardAppliedAmount': 0.0,
        'appliedGiftCardCode': 'NONE',
        'shippingAddress': {'line1': 'Street 1'},
        'status': 'processing',
        'timestamp': Timestamp.fromDate(ts),
      };

      final order = model.Order.fromMap(data, 'doc-1');

      expect(order.id, 'doc-1');
      expect(order.orderId, 'ORD-123');
      expect(order.totalPrice, 39.98);
      expect(order.finalAmountPaid, 39.98);
      expect(order.giftCardAppliedAmount, 0.0);
      expect(order.appliedGiftCardCode, 'NONE');
      expect(order.shippingAddress, isA<Map<String, dynamic>>());
      expect(order.status, 'processing');
      expect(order.timestamp.millisecondsSinceEpoch, ts.millisecondsSinceEpoch);

      expect(order.items.length, 1);
      final item = order.items.first;
      expect(item.id, 'p1');
      expect(item.product.id, 'p1');
      expect(item.product.name, 'Blue Shirt');
      expect(item.product.price, 19.99);
      expect(item.quantity, 2);

      // Historical product snapshot should have stock 0
      expect(item.product.stock, 0);
      expect(item.product.category, 'Clothing');
    });

    test('fromMap handles missing optional fields and types safely', () {
      final data = <String, dynamic>{};
      final order = model.Order.fromMap(data, 'doc-empty');

      expect(order.id, 'doc-empty');
      expect(order.orderId, 'doc-empty');
      expect(order.items, isEmpty);
      expect(order.totalPrice, 0.0);
      expect(order.finalAmountPaid, 0.0);
      expect(order.giftCardAppliedAmount, 0.0);
      expect(order.appliedGiftCardCode, isNull);
      expect(order.shippingAddress, isNull);
      expect(order.status, 'pending');
      expect(order.timestamp, isA<DateTime>());
    });

    test('item fields default correctly when parts are missing', () {
      final data = {
        'items': [
          {
            'productId': 'p2',
            // name missing -> should default to 'Unknown'
            'productPrice': 5,
            // quantity missing -> default to 0
          }
        ]
      };

      final order = model.Order.fromMap(data, 'doc-2');
      expect(order.items.length, 1);
      final p = order.items.first.product;
      expect(p.id, 'p2');
      expect(p.name, 'Unknown');
      expect(p.price, 5.0);
      expect(order.items.first.quantity, 0);
      // category default
      expect(p.category, 'General');
    });
  });

  group('Order Edge Cases & toString', () {
    test('Order.fromMap mit fehlenden Feldern', () {
      final now = DateTime.now();
      final map = {
        // absichtlich Felder weggelassen
        'orderId': 'ORD-999',
        'items': [],
        'totalPrice': 0.0,
        'finalAmountPaid': 0.0,
        'giftCardAppliedAmount': 0.0,
        'status': 'pending',
        'timestamp': Timestamp.fromDate(now),
      };
      // Sollte nicht crashen, sondern sinnvolle Defaults setzen oder Fehler werfen
      expect(() => model.Order.fromMap(map, 'order-999'), returnsNormally);
    });

    test('Order.toString gibt sinnvolle Infos', () {
      final order = model.Order(
        id: 'order-2',
        orderId: 'ORD-2',
        items: [],
        totalPrice: 0.0,
        finalAmountPaid: 0.0,
        giftCardAppliedAmount: 0.0,
        status: 'pending',
        timestamp: DateTime.now(),
      );
      final str = order.toString();
      expect(str, contains('ORD-2'));
      expect(str, contains('pending'));
    });
  });
}

