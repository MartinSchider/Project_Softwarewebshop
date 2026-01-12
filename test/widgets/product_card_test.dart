// test/widgets/product_card_test.dart

/// NOTE: These widget tests currently fail due to Firebase dependency issues.
///
/// PROBLEM: The ProductCard widget depends on CartService via Riverpod providers.
/// CartService requires Firebase Firestore to be initialized, but the test
/// environment does not have Firebase configured.
///
/// SOLUTIONS TO MAKE THESE TESTS WORK:
/// 1. Mock Firebase using fake_cloud_firestore package
/// 2. Mock CartService and override the Riverpod provider in tests
/// 3. Use integration tests with Firebase Test Lab instead
/// 4. Refactor ProductCard to accept CartService as parameter for easier testing
///
/// CURRENT STATUS: These tests are kept for documentation purposes but will
/// fail until proper mocking infrastructure is added.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/widgets/product_card.dart';
import 'package:webshop/widgets/custom_image.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/providers/wishlist_provider.dart';
import 'package:webshop/services/cart_service.dart';
import 'package:webshop/models/cart_item.dart';

// Lightweight fakes to prevent Firebase access during widget tests.
class FakeCartService implements CartService {
  @override
  Stream<List<CartItem>> getCartStream() => Stream.value([]);

  @override
  Stream<Map<String, dynamic>> getCartDetailsStream() => Stream.value({});

  @override
  Future<void> addProductToCart(Product product, int quantityToAdd) async {}

  @override
  Future<void> removeCartItem(String cartItemId) async {}

  @override
  Future<void> updateCartItemQuantity(String cartItemId, int newQuantity) async {}

  @override
  Future<void> clearCart() async {}

  @override
  Future<List<CartItem>> getCartOnce() async => [];

  @override
  Future<Map<String, dynamic>> applyGiftCard(String giftCardCode) async => <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> removeGiftCard() async => <String, dynamic>{};
}

class FakeWishlistController implements WishlistController {
  @override
  Future<void> add(String productId) async {}

  @override
  Future<void> remove(String productId) async {}

  @override
  Future<void> toggleWishlist(String productId) async {}
}

void main() { 
  group('ProductCard Widget Tests', () {
    late Product testProduct;

    setUp(() {
      testProduct = Product(
        id: 'test-product-1',
        name: 'Test Widget Product',
        description: 'A product for testing widgets',
        price: 49.99,
        imageUrl: 'https://via.placeholder.com/150',
        stock: 15,
        category: 'General',
      );
    });

    // FAILING TEST: Requires Firebase initialization
    // Expected behavior: ProductCard should render product name, price, and category
    // Current issue: Widget fails to build due to Firebase dependency in CartService
    testWidgets('ProductCard should display product information',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(FakeCartService()),
            wishlistControllerProvider.overrideWithValue(FakeWishlistController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductCard(product: testProduct),
            ),
          ),
        ),
      );

      // Verify product name is displayed
      expect(find.text('Test Widget Product'), findsOneWidget);

      // Verify price is displayed
      expect(find.textContaining('€49.99'), findsOneWidget);
    });

    // FAILING TEST: Requires Firebase initialization
    // Expected behavior: ProductCard should show "In Stock" or similar stock status
    // Current issue: Widget fails to build before stock info can be verified
    testWidgets('ProductCard should display stock information',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(FakeCartService()),
            wishlistControllerProvider.overrideWithValue(FakeWishlistController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductCard(product: testProduct),
            ),
          ),
        ),
      );

      // Verify stock badges are correct: for ample stock there should be no 'SOLD OUT' or 'LOW STOCK' badges
      expect(find.text('SOLD OUT'), findsNothing);
      expect(find.text('LOW STOCK'), findsNothing);
    });

    // FAILING TEST: Requires Firebase initialization
    // Expected behavior: ProductCard should display "Out of Stock" message when stock = 0
    // Current issue: Firebase exception prevents widget from rendering
    testWidgets('ProductCard should handle out-of-stock products',
        (WidgetTester tester) async {
      final outOfStockProduct = Product(
        id: 'out-of-stock',
        name: 'Unavailable Product',
        description: 'This product is out of stock',
        price: 29.99,
        imageUrl: 'https://via.placeholder.com/150',
        stock: 0,
        category: 'General',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(FakeCartService()),
            wishlistControllerProvider.overrideWithValue(FakeWishlistController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductCard(product: outOfStockProduct),
            ),
          ),
        ),
      );

      // Verify out of stock badge is shown (SOLD OUT)
      expect(find.text('SOLD OUT'), findsOneWidget);
    });

    // FAILING TEST: Requires Firebase initialization
    // Expected behavior: ProductCard should be wrapped in InkWell or GestureDetector
    // Actual error: Cannot find Card widget because ProductCard fails to build
    // Root cause: Firebase not initialized for CartService dependency
    testWidgets('ProductCard should be tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(FakeCartService()),
            wishlistControllerProvider.overrideWithValue(FakeWishlistController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductCard(product: testProduct),
            ),
          ),
        ),
      );

      // Find the card widget
      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);

      // Verify it has an InkWell or GestureDetector for tap handling
      final inkWellFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsWidgets);
    });

    // FAILING TEST: Requires Firebase initialization
    // Expected behavior: ProductCard should contain an Image widget with product imageUrl
    // Actual error: Cannot find Image widget because ProductCard fails to build
    // Root cause: FirebaseException thrown during widget construction
    testWidgets('ProductCard should display an image',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(FakeCartService()),
            wishlistControllerProvider.overrideWithValue(FakeWishlistController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductCard(product: testProduct),
            ),
          ),
        ),
      );

      // Verify CustomImage widget is present
      expect(find.byType(CustomImage), findsOneWidget);
    });

    // FAILING TEST: Requires Firebase initialization
    // Expected behavior: ProductCard should contain an IconButton for adding items to cart
    // Actual error: Cannot find IconButton because widget tree fails to render
    // Root cause: CartService provider requires FirebaseFirestore.instance which is not initialized
    testWidgets('ProductCard should display add to cart button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(FakeCartService()),
            wishlistControllerProvider.overrideWithValue(FakeWishlistController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductCard(product: testProduct),
            ),
          ),
        ),
      );

      // Look for the add-to-cart Icon
      expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
    });
  });
}
