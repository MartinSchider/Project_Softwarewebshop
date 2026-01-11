// lib/repositories/product_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/product.dart';

/// Manages data operations for the product catalog.
///
/// This repository acts as an abstraction layer between the Firestore database
/// and the application's business logic (Providers/UI). It handles:
/// * Real-time data streaming.
/// * Paginated data fetching for performance.
/// * Caching strategies to reduce network costs and latency.
class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // A simple in-memory cache to store fetched products by their ID.
  // This prevents redundant network calls when viewing details of the same product multiple times.
  final Map<String, Product> _memoryCache = {};

  /// Provides a real-time stream of all available products.
  ///
  /// This method sets up a listener on the 'products' collection.
  /// Any change in the database (add, update, delete) will immediately
  /// trigger a new event in this stream, allowing the UI to react instantly.
  Stream<List<Product>> getProductsStream() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      // Map the Firestore QuerySnapshot to a List of Product objects.
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Fetches a specific page of products to support infinite scrolling.
  ///
  /// This method implements **Cursor-based Pagination**:
  /// * [limit]: Defines how many items to fetch in one request (default: 10).
  /// * [lastDocument]: The cursor pointing to the last item of the previous page. 
  ///   If null, it fetches the first page.
  Future<QuerySnapshot> getProductsPage(
      {int limit = 10, DocumentSnapshot? lastDocument}) async {
    
    // NOTE: We order by 'productName' to ensure a consistent list order.
    // This matches the index configuration in Firestore.
    Query query =
        _firestore.collection('products').orderBy('productName').limit(limit);

    // If a cursor is provided, start the query strictly after that document.
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.get();
  }

  /// Retrieves the full details of a specific product by its unique [id].
  ///
  /// **Optimization Strategy:**
  /// 1. **Cache Check:** First, it checks if the product is already in `_memoryCache`.
  /// 2. **Network Request:** If not found, it fetches the document from Firestore.
  /// 3. **Cache Update:** On success, it stores the result in the cache for future use.
  ///
  /// Returns `null` if the product does not exist or an error occurs.
  Future<Product?> getProductById(String id) async {
    // 1. Check Cache
    if (_memoryCache.containsKey(id)) {
      return _memoryCache[id];
    }

    try {
      // 2. Fetch from Database
      final doc = await _firestore.collection('products').doc(id).get();

      if (doc.exists && doc.data() != null) {
        // Convert to Model
        final product = Product.fromMap(doc.data()!, doc.id);
        
        // 3. Update Cache
        _memoryCache[id] = product;
        
        return product;
      }
      return null;
    } catch (e) {
      // Log errors for debugging (consider using a logging service in production)
      print("Error fetching product $id: $e");
      return null;
    }
  }
}