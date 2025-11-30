// lib/providers/products_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/product_repository.dart';

/// Represents the UI state for the product list screen.
///
/// This immutable class holds the data required to render the infinite scroll list,
/// including the actual items, loading indicators for different stages, and error messages.
class ProductsState {
  /// The list of products currently loaded and displayed to the user.
  final List<Product> products;

  /// Indicates if the *initial* batch of products is being fetched.
  /// Used to show a full-screen loading spinner.
  final bool isLoading;

  /// Indicates if *additional* products are being fetched (pagination).
  /// Used to show a small spinner at the bottom of the list.
  final bool isLoadingMore;

  /// True if there are potentially more products in the database to load.
  /// Used to stop infinite scroll requests when the end of the collection is reached.
  final bool hasMore;

  /// Contains an error message if the fetch operation fails.
  final String? errorMessage;

  /// Creates a [ProductsState] with default initial values.
  ProductsState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  /// Creates a copy of the current state with updated fields.
  ///
  /// Standard pattern for immutable state management.
  ProductsState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
  }) {
    return ProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }
}

/// Manages the logic for fetching products with pagination.
///
/// It communicates with the [ProductRepository] to fetch data in chunks (pages)
/// and updates the [ProductsState] accordingly.
class ProductsNotifier extends StateNotifier<ProductsState> {
  final ProductRepository _repository = ProductRepository();

  /// The Firestore cursor tracking the last document fetched.
  /// This is required by Firestore to know where to start the next query.
  DocumentSnapshot? _lastDocument;

  /// The number of items to fetch per page.
  static const int _limit = 10;

  /// Initializes the notifier and immediately triggers the first load.
  ProductsNotifier() : super(ProductsState()) {
    loadInitialProducts();
  }

  /// Fetches the first page of products.
  ///
  /// This resets the list and the cursor. Use this for the initial load
  /// or when the user manually refreshes the list.
  Future<void> loadInitialProducts() async {
    // Set loading state to show full-screen spinner
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Fetch the first batch (no cursor provided)
      final snapshot = await _repository.getProductsPage(limit: _limit);

      // Convert Firestore documents to Product models
      final newProducts = snapshot.docs
          .map((doc) =>
              Product.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Update the cursor to the last document of this batch
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      state = state.copyWith(
        products: newProducts,
        isLoading: false,
        // If we received fewer items than requested, we've reached the end.
        hasMore: newProducts.length == _limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Fetches the next page of products and appends them to the current list.
  ///
  /// This should be called by the UI when the user scrolls near the bottom.
  Future<void> loadMoreProducts() async {
    // GUARD CLAUSES:
    // 1. isLoading: Don't fetch if initial load is still running.
    // 2. isLoadingMore: Don't fetch if a pagination request is already in progress (prevents double calls).
    // 3. !hasMore: Don't fetch if we already know we reached the end of the DB.
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    // Show bottom spinner
    state = state.copyWith(isLoadingMore: true);

    try {
      // Fetch next batch starting after _lastDocument
      final snapshot = await _repository.getProductsPage(
          limit: _limit, lastDocument: _lastDocument);

      final newProducts = snapshot.docs
          .map((doc) =>
              Product.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      state = state.copyWith(
        // Append new items to the existing list
        products: [...state.products, ...newProducts],
        isLoadingMore: false,
        // Check if we reached the end
        hasMore: newProducts.length == _limit,
      );
    } catch (e) {
      // On pagination error, we just stop the spinner.
      // In a real app, you might want to show a Toast/SnackBar here.
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Resets the pagination state and reloads the list from scratch.
  ///
  /// Typically called by a [RefreshIndicator] in the UI.
  Future<void> refresh() async {
    _lastDocument = null; // Clear cursor
    state = ProductsState(); // Reset state to initial empty values
    await loadInitialProducts();
  }
}

/// The global provider for the product list state.
///
/// Use `ref.watch(productsProvider)` in the UI to listen to state changes.
/// Use `ref.read(productsProvider.notifier)` to call methods like `loadMoreProducts()`.
final productsProvider =
    StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  return ProductsNotifier();
});
