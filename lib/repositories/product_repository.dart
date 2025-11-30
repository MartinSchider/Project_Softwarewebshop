// lib/repositories/product_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/product.dart';

/// Handles data retrieval and management for products in Firestore.
///
/// This repository acts as the single source of truth for product data,
/// abstracting the database implementation details from the UI and Providers.
/// It implements performance optimizations like **pagination** and **in-memory caching**.
class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// A local in-memory cache to store products that have already been fetched.
  ///
  /// **Why?**
  /// Firestore charges for every document read. If a user views the cart,
  /// goes to home, and comes back to the cart, standard logic would re-fetch
  /// the product details (costing $$). This cache serves the data instantly
  /// for free if we've seen the product during this session.
  final Map<String, Product> _memoryCache = {};

  /// [Deprecated] Returns a real-time stream of ALL products in the collection.
  ///
  /// **Warning:** This method downloads the entire collection.
  /// It is kept for reference or for use in admin panels with few items,
  /// but should be avoided in the main user-facing app to prevent high data usage.
  Stream<List<Product>> getProductsStream() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Fetches a specific "page" or batch of products from Firestore.
  ///
  /// Used for Infinite Scroll. Returns a raw [QuerySnapshot] because the
  /// StateNotifier needs access to the `DocumentSnapshot` of the last item
  /// to use as a cursor for the next page request.
  ///
  /// * [limit]: The number of products to fetch (default 10).
  /// * [lastDocument]: The cursor from the previous page. If null, fetches the first page.
  Future<QuerySnapshot> getProductsPage(
      {int limit = 10, DocumentSnapshot? lastDocument}) async {
    // We MUST order by a stable field (like 'productName') for pagination to work consistently.
    // If we didn't order, Firestore wouldn't know which documents come "after" the cursor.
    Query query =
        _firestore.collection('products').orderBy('productName').limit(limit);

    // If we have a cursor, we tell Firestore: "Start fetching AFTER this document".
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.get();
  }

  /// Retrieves a single product by its unique [id].
  ///
  /// This method implements a "Cache-First" strategy:
  /// 1. Checks internal memory.
  /// 2. If missing, fetches from Firestore.
  /// 3. Saves result to memory for future calls.
  Future<Product?> getProductById(String id) async {
    // 1. OPTIMIZATION: Check cache (Cost: 0 reads, Speed: Instant)
    if (_memoryCache.containsKey(id)) {
      return _memoryCache[id];
    }

    try {
      // 2. Fetch from Network (Cost: 1 read)
      final doc = await _firestore.collection('products').doc(id).get();

      if (doc.exists && doc.data() != null) {
        final product = Product.fromMap(doc.data()!, doc.id);

        // 3. Update Cache: Store the fresh data so subsequent calls are free.
        _memoryCache[id] = product;

        return product;
      }
      return null;
    } catch (e) {
      // Log the error locally. In a real app, send this to Crashlytics.
      print("Error fetching product $id: $e");
      return null;
    }
  }

  // NOTE: If you implement an 'Edit Product' feature in the future,
  // remember to create a method `clearCache()` or `updateCache(id)`
  // to ensure the user doesn't see stale data after editing.
}
