// lib/products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/widgets/chat_panel.dart';
import 'package:webshop/widgets/product_card.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/cart_page.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/pages/customer_area_page.dart'; 
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/providers/products_provider.dart';
import 'package:webshop/widgets/error_retry_widget.dart';

/// The main catalog screen of the application.
///
/// This widget displays the grid of products and serves as the primary navigation hub.
/// It features:
/// * Infinite scrolling for product pagination.
/// * Local filtering by category and search query.
/// * Real-time cart badge updates.
/// * A collapsible AI Chat panel.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  // Local state for UI filters.
  String _query = '';
  String _selectedCategory = 'All';
  bool _isChatVisible = false;
  bool _isSearching = false;

  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Attach listener to detect when the user scrolls to the bottom.
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Triggered by the ScrollController to handle infinite scrolling.
  ///
  /// We check if the user is within 200 pixels of the bottom of the list.
  /// If so, we request the provider to fetch the next page of data.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(productsProvider.notifier).loadMoreProducts();
    }
  }

  /// Filters the currently loaded products based on search text and category.
  ///
  /// **Note:** This performs client-side filtering on the *loaded* data.
  /// In a production scenario with millions of items, this should ideally
  /// be replaced by a server-side query.
  List<Product> _filterProducts(List<Product> allProducts) {
    return allProducts.where((p) {
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the cart stream to update the badge count in real-time.
    final cartItemsAsync = ref.watch(cartItemsProvider);
    // Watch the product state to render the grid.
    final productsState = ref.watch(productsProvider);
    
    final int cartItemCount = _calculateCartItemCount(cartItemsAsync);

    return Scaffold(
      appBar: _buildAppBar(context, cartItemCount),
      floatingActionButton: _buildFloatingActionButton(context),
      body: Row(
        children: [
          // Main Content Area (Filters + Grid)
          Expanded(
            child: Column(
              children: [
                _buildCategoryFilterBar(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: smallPadding),
                    child: _buildBody(productsState),
                  ),
                ),
              ],
            ),
          ),
          // Side Panel for AI Chat (Sliding animation)
          _buildChatPanel(context, productsState),
        ],
      ),
    );
  }

  /// Safely calculates total items from the AsyncValue.
  ///
  /// We use `fold` to sum quantities across all unique cart items.
  /// Returns 0 if data is loading or errored to prevent UI glitches.
  int _calculateCartItemCount(AsyncValue<List<dynamic>> cartItemsAsync) {
    return cartItemsAsync.when(
      data: (items) => items
          .fold<num>(0, (previousValue, element) => previousValue + element.quantity)
          .toInt(),
      loading: () => 0,
      error: (err, stack) => 0,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, int cartItemCount) {
    return AppBar(
      title: _buildAppBarTitle(),
      actions: [
        _buildSearchToggleButton(),

        // --- Profile Icon ---
        IconButton(
          icon: const Icon(Icons.person),
          tooltip: 'Personal Area',
          onPressed: () {
            // Intelligent routing:
            // If logged in -> Go to Dashboard.
            // If anonymous -> Go to Login/Register.
            if (_authService.currentUser == null) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AuthPage()),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CustomerAreaPage()),
              );
            }
          },
        ),
        
        _buildCartButton(context, cartItemCount),
      ],
    );
  }

  /// Toggles between the app name and the search text field.
  Widget _buildAppBarTitle() {
    if (_isSearching) {
      return TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search products...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: whiteColor.withOpacity(0.7)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: whiteColor),
            onPressed: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
        ),
        style: const TextStyle(color: whiteColor),
        // Live search: Update query as user types.
        onChanged: (v) => setState(() => _query = v),
      );
    }
    return const Text(appName);
  }

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

  /// Builds the cart icon with a badge overlay.
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
        // Only show badge if there are items.
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

  Widget _buildCategoryFilterBar(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
        scrollDirection: Axis.horizontal,
        itemCount: productCategories.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (ctx, index) {
          final cat = productCategories[index];
          final isSelected = cat == _selectedCategory;
          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (bool selected) {
              setState(() {
                if (selected) _selectedCategory = cat;
              });
            },
            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            labelStyle: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  /// Hides the FAB when the chat panel is open to avoid visual clutter.
  Widget? _buildFloatingActionButton(BuildContext context) {
    if (_isChatVisible) return null;
    return FloatingActionButton.extended(
      icon: const Icon(Icons.support_agent, size: 24),
      label: const Text('Chat'),
      onPressed: () => setState(() => _isChatVisible = true),
    );
  }

  /// Renders the AI Chat sidebar with a sliding transition.
  ///
  /// We pass the current [productsState] to the chat so the AI knows about
  /// the products currently visible/loaded context.
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

  /// Builds the main grid based on the provider state.
  ///
  /// Handles:
  /// 1. Initial Loading Spinner.
  /// 2. Error State (with retry).
  /// 3. Empty State (no search results).
  /// 4. Data Grid (with pull-to-refresh).
  Widget _buildBody(ProductsState state) {
    // 1. Initial Load
    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    
    // 2. Error State
    if (state.errorMessage != null && state.products.isEmpty) {
      return ErrorRetryWidget(
        errorMessage: state.errorMessage!,
        onRetry: () => ref.read(productsProvider.notifier).refresh(),
      );
    }
    
    // Apply local filters (Search/Category)
    final displayProducts = _filterProducts(state.products);
    
    // 3. Empty State
    if (displayProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No products found for "$_selectedCategory".',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    // 4. Data Grid
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(productsProvider.notifier).refresh();
      },
      child: GridView.builder(
        controller: _scrollController,
        // AlwaysScrollable ensures Pull-to-Refresh works even if list is short.
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.70,
          crossAxisSpacing: smallPadding,
          mainAxisSpacing: smallPadding,
        ),
        // Add extra slot for the bottom loading spinner if fetching more pages.
        itemCount: displayProducts.length + (state.isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= displayProducts.length) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator()));
          }
          return ProductCard(product: displayProducts[index]);
        },
      ),
    );
  }
}