// lib/services/product_service.dart
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/product_repository.dart';

/// Provides access to product data and business logic.
///
/// This service acts as an intermediary (Facade) between the UI (or Providers)
/// and the Data Layer ([ProductRepository]).
///
/// **Why have this layer?**
/// Even if it currently looks like a simple pass-through, placing this service here
/// allows us to inject future business rules (e.g., "Hide out-of-stock products",
/// "Apply seasonal discounts", "Sort by popularity") without modifying the UI code
/// or the raw database fetching logic in the repository.
class ProductService {
  final ProductRepository _productRepository = ProductRepository();

  /// Returns a real-time stream of all available products.
  ///
  /// This stream automatically emits new values whenever the product collection
  /// in the database changes (additions, deletions, or updates).
  Stream<List<Product>> getProductsStream() {
    // Currently delegates directly to the repository.
    // Future expansion: We could apply a `.map()` here to filter out inactive products
    // before they reach the UI.
    return _productRepository.getProductsStream();
  }

  /// Retrieves the details of a specific product by its [id].
  ///
  /// Returns `null` if the product is not found or an error occurs.
  /// This is typically used by the Cart logic to validate item details.
  Future<Product?> getProductById(String id) {
    return _productRepository.getProductById(id);
  }
}
