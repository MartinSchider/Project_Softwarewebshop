// test/integration/firestore_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:webshop/repositories/product_repository.dart';
import 'package:webshop/repositories/cart_repository.dart';
import 'package:webshop/services/cart_service.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/models/cart_item.dart';

// Optional mocks
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// These integration-style tests require a running Firestore emulator. To run,
/// start the emulator and run the tests with:
///   flutter test --dart-define=USE_FIRESTORE_EMULATOR=true test/integration/firestore_integration_test.dart

void main() {
  const useEmulator = bool.fromEnvironment('USE_FIRESTORE_EMULATOR', defaultValue: false);

  late FirebaseFirestore firestore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    if (useEmulator) {
      // Connect to a running Firestore emulator at localhost:8080
      await Firebase.initializeApp();
      FirebaseFirestore.instance.settings = const Settings(
        host: 'localhost:8080',
        sslEnabled: false,
        persistenceEnabled: false,
      );
      firestore = FirebaseFirestore.instance;
    }
  });

  // Skip these tests if the emulator isn't enabled to avoid brittle local failures.
  group('Firestore integration tests', () {
    test('Product deletion is reflected in product stream', () async {
      final productId = 'int-prod-delete';

      // Insert product
      await firestore.collection('products').doc(productId).set({
        'productName': 'DeleteMe',
        'productDescription': 'To be deleted',
        'productPrice': 1.0,
        'imageUrl': 'https://via.placeholder.com/1',
        'stock': 5,
        'category': 'General',
      });

      final repo = ProductRepository(firestore: firestore);

      // Wait until the product appears in the stream
      await repo.getProductsStream().firstWhere(
        (list) => list.any((p) => p.id == productId),
      );

      // Delete the product
      await firestore.collection('products').doc(productId).delete();

      // Then the stream should eventually not include it
      await repo.getProductsStream().firstWhere(
        (list) => list.every((p) => p.id != productId),
      );
    });

    test('Deleting product removes it from cart stream', () async {
      final userId = 'test-user';
      final productId = 'int-prod-cart-remove';

      // Create product
      await firestore.collection('products').doc(productId).set({
        'productName': 'CartRemove',
        'productDescription': 'Remove from cart when deleted',
        'productPrice': 10.0,
        'imageUrl': 'https://via.placeholder.com/1',
        'stock': 2,
        'category': 'General',
      });

      // Add cart item referencing product
      await firestore
          .collection('carts')
          .doc(userId)
          .collection('items')
          .doc(productId)
          .set({'productId': productId, 'quantity': 1});

      final productRepo = ProductRepository(firestore: firestore);
      final cartRepo = CartRepository(firestore: firestore);

      // First emission should include the cart item
      final first = await cartRepo
          .getCartStream(userId, productRepo.getProductById)
          .firstWhere((list) => list.isNotEmpty);
      expect(first.length, 1);
      expect(first.first.product.id, productId);

      // Delete product
      await firestore.collection('products').doc(productId).delete();

      // Now the cart stream should emit an empty list because product details cannot be resolved
      await cartRepo
          .getCartStream(userId, productRepo.getProductById)
          .firstWhere((list) => list.isEmpty);
    });

    test('Cannot add out-of-stock product via CartService', () async {
      final productId = 'int-prod-oos';
      final userId = 'oos-user';

      // Create out-of-stock product
      await firestore.collection('products').doc(productId).set({
        'productName': 'OutOfStock',
        'productDescription': 'No stock',
        'productPrice': 5.0,
        'imageUrl': 'https://via.placeholder.com/1',
        'stock': 0,
        'category': 'General',
      });

      final productRepo = ProductRepository(firestore: firestore);
      final cartRepo = CartRepository(firestore: firestore);

      // Mock auth with a signed-in user
      final mockUser = MockUser(uid: userId);
      final mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      final cartService = CartService(
        cartRepository: cartRepo,
        productRepository: productRepo,
        auth: mockAuth,
      );

      final product = await productRepo.getProductById(productId);
      expect(product, isNotNull);

      // Attempt to add to cart should throw due to stock validation
      expect(() async => await cartService.addProductToCart(product!, 1), throwsA(isA<Exception>()));
    });
  }, skip: !useEmulator);
}
