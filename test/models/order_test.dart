// test/models/order_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/order.dart';
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
      final order = Order(
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

    test('Order should handle gift card discounts', () {
      final now = DateTime.now();
      final order = Order(
        id: 'order-2',
        orderId: 'ORD-67890',
        items: testCartItems,
        totalPrice: 70.00,
        finalAmountPaid: 50.00,
        giftCardAppliedAmount: 20.00,
        appliedGiftCardCode: 'SAVE20',
        status: 'pending',
        timestamp: now,
      );

      expect(order.totalPrice, 70.00,
          reason: 'Total price should be 70.00 before discount');
      expect(order.giftCardAppliedAmount, 20.00,
          reason: 'Gift card discount should be 20.00');
      expect(order.finalAmountPaid, 50.00,
          reason: 'Final amount should be 70.00 - 20.00 = 50.00');
      expect(order.appliedGiftCardCode, 'SAVE20',
          reason: 'Gift card code should be stored in order');
      expect(
          order.totalPrice - order.giftCardAppliedAmount, order.finalAmountPaid,
          reason:
              'Mathematical relationship: totalPrice - discount = finalAmount should hold');
    });

    test('Order should calculate total from items correctly', () {
      final now = DateTime.now();
      final order = Order(
        id: 'order-3',
        orderId: 'ORD-11111',
        items: testCartItems,
        totalPrice: 70.00,
        finalAmountPaid: 70.00,
        giftCardAppliedAmount: 0.00,
        status: 'pending',
        timestamp: now,
      );

      // Product 1: 20.00 * 2 = 40.00
      // Product 2: 30.00 * 1 = 30.00
      // Total: 70.00
      double calculatedTotal = 0;
      for (var item in order.items) {
        calculatedTotal += item.product.price * item.quantity;
      }

      expect(calculatedTotal, order.totalPrice,
          reason:
              'Sum of (item.price × quantity) for all items should equal order total price');
    });

    test('Order should handle different statuses', () {
      final now = DateTime.now();
      final statuses = [
        'pending',
        'processing',
        'shipped',
        'delivered',
        'cancelled'
      ];

      for (var status in statuses) {
        final order = Order(
          id: 'order-$status',
          orderId: 'ORD-$status',
          items: testCartItems,
          totalPrice: 70.00,
          finalAmountPaid: 70.00,
          giftCardAppliedAmount: 0.00,
          status: status,
          timestamp: now,
        );

        expect(order.status, status,
            reason: 'Order should correctly store status: $status');
      }
    });

    test('Order should handle empty items list', () {
      final now = DateTime.now();
      final order = Order(
        id: 'order-empty',
        orderId: 'ORD-EMPTY',
        items: [],
        totalPrice: 0.00,
        finalAmountPaid: 0.00,
        giftCardAppliedAmount: 0.00,
        status: 'pending',
        timestamp: now,
      );

      expect(order.items.isEmpty, true,
          reason: 'Order with no items should have empty items list');
      expect(order.totalPrice, 0.00,
          reason: 'Order with no items should have total price of 0.00');
      expect(order.finalAmountPaid, 0.00,
          reason: 'Order with no items should have final amount of 0.00');
    });

    test('Order should handle nullable fields', () {
      final now = DateTime.now();
      final order = Order(
        id: 'order-minimal',
        orderId: 'ORD-MIN',
        items: testCartItems,
        totalPrice: 70.00,
        finalAmountPaid: 70.00,
        giftCardAppliedAmount: 0.00,
        status: 'pending',
        timestamp: now,
        // No gift card code or shipping address
      );

      expect(order.appliedGiftCardCode, isNull,
          reason: 'Order without gift card should have null gift card code');
      expect(order.shippingAddress, isNull,
          reason: 'Order without shipping address should have null address');
    });
  });
}
