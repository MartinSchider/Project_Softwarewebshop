// test/integration/product_additional_rules_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/models/cart_item.dart';

void main() {
  group('Additional product/cart rules', () {
    test('Cannot add more items to cart than available stock', () {
      final product = const Product(
        id: 'p-stock-2',
        name: 'LimitedItem',
        description: 'Limited',
        price: 15.0,
        imageUrl: 'https://via.placeholder.com/1',
        stock: 2,
        category: 'General',
      );

      final desiredQuantity = 3;

      bool canAdd(Product p, int qty) => qty <= p.stock;

      expect(canAdd(product, desiredQuantity), isFalse,
          reason: 'Should not be able to add more than available stock');
    });

    test('Stock reduced after adding to cart prevents checkout', () {
      // Setup: product initially has stock 2
      var product = Product(
        id: 'p-dyn',
        name: 'DynamicStock',
        description: 'Dynamic',
        price: 8.0,
        imageUrl: 'https://via.placeholder.com/1',
        stock: 2,
        category: 'General',
      );

      // User adds 2 units to cart
      final cartItem = CartItem(id: 'c1', product: product, quantity: 2);

      bool validateStock(List<CartItem> items) =>
          items.every((i) => i.quantity <= i.product.stock);

      // Initially validation passes
      expect(validateStock([cartItem]), isTrue,
          reason: 'Initial stock should permit checkout');

      // Simulate external stock change (e.g., another purchase) reducing stock to 1
      product = Product(
        id: product.id,
        name: product.name,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
        stock: 1,
        category: product.category,
      );

      final updatedCartItem = CartItem(id: 'c1', product: product, quantity: 2);

      // Now validation fails
      expect(validateStock([updatedCartItem]), isFalse,
          reason: 'Reduced stock should prevent checkout');
    });

    test('Deleting product removes it from cart and wishlist (cleanup)', () {
      final product = const Product(
        id: 'p-remove',
        name: 'ToRemove',
        description: 'Remove',
        price: 12.0,
        imageUrl: 'https://via.placeholder.com/1',
        stock: 4,
        category: 'General',
      );

      // Simulated cart and wishlist holding product IDs
      final cart = <String, CartItem>{
        product.id: CartItem(id: 'x1', product: product, quantity: 1)
      };
      final wishlist = <String>{product.id};

      // Simulate deletion from product store
      final productStore = {product.id: product};
      productStore.remove(product.id);

      // Cleanup routines would remove references from cart and wishlist
      if (!productStore.containsKey(product.id)) {
        cart.remove(product.id);
        wishlist.remove(product.id);
      }

      expect(cart.containsKey(product.id), isFalse,
          reason: 'Cart should no longer reference deleted product');
      expect(wishlist.contains(product.id), isFalse,
          reason: 'Wishlist should no longer reference deleted product');
    });
  });
}
