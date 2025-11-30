// lib/products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/widgets/chat_panel.dart';
import 'package:webshop/widgets/product_card.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/services/product_service.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/cart_page.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/providers/products_provider.dart';
import 'package:webshop/widgets/error_retry_widget.dart';

/// The main dashboard of the application.
///
/// This screen displays the product catalog using an infinite scroll grid.
/// It also hosts the top navigation bar (search, cart, logout) and the
/// collapsible AI Chatbot panel.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  // --- UI State Variables ---
  String _query = '';
  bool _isChatVisible = false;
  bool _isSearching = false;

  // --- Services & Controllers ---
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // INFINITE SCROLL LISTENER:
    // We listen to scroll events to trigger data fetching when the user nears the bottom.
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Triggered whenever the user scrolls the grid.
  void _onScroll() {
    // If we are 200 pixels away from the bottom of the list...
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // ... ask the provider to load the next page of products.
      ref.read(productsProvider.notifier).loadMoreProducts();
    }
  }

  /// Filters the loaded products based on the user's search query.
  ///
  /// Note: This currently filters only the *loaded* products in memory (Client-Side).
  /// For a full database search, we would need a dedicated search service (e.g. Algolia).
  List<Product> _filterProducts(List<Product> allProducts) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return allProducts;
    return allProducts
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // We watch the cart provider to update the badge count in real-time.
    final cartItemsAsync = ref.watch(cartItemsProvider);

    // We watch the products provider to render the grid (loading/data/error states).
    final productsState = ref.watch(productsProvider);
    final int cartItemCount = _calculateCartItemCount(cartItemsAsync);

    return Scaffold(
      appBar: _buildAppBar(context, cartItemCount),
      floatingActionButton: _buildFloatingActionButton(context),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(smallPadding),
              child: _buildBody(productsState),
            ),
          ),
          _buildChatPanel(context, productsState),
        ],
      ),
    );
  }

  /// Calculates the total number of items in the cart.
  int _calculateCartItemCount(AsyncValue<List<dynamic>> cartItemsAsync) {
    return cartItemsAsync.when(
      data: (items) => items.fold<num>(
          0, (previousValue, element) => previousValue + element.quantity).toInt(),
      loading: () => 0,
      error: (err, stack) => 0,
    );
  }

  /// Builds the app bar with search functionality and action buttons.
  PreferredSizeWidget _buildAppBar(BuildContext context, int cartItemCount) {
    return AppBar(
      title: _buildAppBarTitle(),
      actions: [
        _buildSearchToggleButton(),
        _buildCartButton(context, cartItemCount),
        _buildLogoutButton(),
      ],
    );
  }

  /// Builds the app bar title (either search field or app name).
  Widget _buildAppBarTitle() {
    if (_isSearching) {
      return TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search loaded products...',
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: whiteColor),
            onPressed: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
        ),
        style: const TextStyle(color: whiteColor),
        onChanged: (v) => setState(() => _query = v),
      );
    }
    return const Text(appName);
  }

  /// Builds the search toggle button.
  Widget _buildSearchToggleButton() {
    if (!_isSearching) {
      return IconButton(
        icon: const Icon(Icons.search),
        onPressed: () => setState(() => _isSearching = true),
      );
    }
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        _searchController.clear();
        setState(() {
          _query = '';
          _isSearching = false;
        });
      },
    );
  }

  /// Builds the cart button with notification badge.
  Widget _buildCartButton(BuildContext context, int cartItemCount) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CartPage()),
            );
          },
        ),
        if (cartItemCount > 0)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: errorColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$cartItemCount',
                style: const TextStyle(color: whiteColor, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the logout button.
  Widget _buildLogoutButton() {
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async => await _authService.signOut(),
    );
  }

  /// Builds the floating action button to toggle the chat panel.
  Widget? _buildFloatingActionButton(BuildContext context) {
    if (_isChatVisible) return null;

    return FloatingActionButton.extended(
      icon: const Icon(Icons.support_agent, size: 24),
      label: const Text('Chat'),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      onPressed: () => setState(() => _isChatVisible = true),
    );
  }

  /// Builds the animated chat panel.
  Widget _buildChatPanel(BuildContext context, ProductsState productsState) {
    return AnimatedContainer(
      duration: animationDuration,
      width: _isChatVisible ? chatPanelWidth : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: chatPanelWidth,
          child: _isChatVisible
              ? Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: PersistentChatPanel(
                    products: productsState.products,
                    onClose: () => setState(() => _isChatVisible = false),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// Builds the main grid content based on the current [ProductsState].
  Widget _buildBody(ProductsState state) {
    // Case 1: Initial full-screen loading.
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Case 2: Initial load failed (e.g. no internet). Show Retry widget.
    if (state.errorMessage != null && state.products.isEmpty) {
      return ErrorRetryWidget(
        errorMessage: state.errorMessage!,
        onRetry: () => ref.read(productsProvider.notifier).refresh(),
      );
    }

    // Case 3: Data Loaded. Filter and display list.
    final displayProducts = _filterProducts(state.products);

    if (displayProducts.isEmpty) {
      return const Center(child: Text('No products found.'));
    }

    // Wrap in RefreshIndicator for Pull-to-Refresh functionality.
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(productsProvider.notifier).refresh();
      },
      child: GridView.builder(
        controller: _scrollController, // REQUIRED for infinite scroll to work.
        physics:
            const AlwaysScrollableScrollPhysics(), // Ensures scroll works even if list is short.
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: smallPadding,
          mainAxisSpacing: smallPadding,
        ),
        // If loading more items, add +2 to count to reserve space for the bottom spinner.
        itemCount: displayProducts.length + (state.isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          // If we are rendering past the last product, show the spinner.
          if (index >= displayProducts.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return ProductCard(product: displayProducts[index]);
        },
      ),
    );
  }
}
