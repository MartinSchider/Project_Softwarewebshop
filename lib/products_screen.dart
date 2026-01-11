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
/// This widget displays a grid of products with search and category filtering capabilities.
/// It features a responsive layout that includes:
/// * **Main Content Area:** A grid of [ProductCard] widgets.
/// * **Sidebar (ChatPanel):** An optional, animated side panel for the AI Assistant.
/// * **Navigation Bar:** Custom AppBar with search, profile, and cart actions.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  // --- UI STATE VARIABLES ---
  String _query = '';
  String _selectedCategory = 'All';
  bool _isChatVisible = false;
  bool _isSearching = false;

  final AuthService _authService = AuthService();
  
  // Controllers for input handling and scrolling.
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Attach listener for infinite scrolling logic.
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Handles scroll events to trigger pagination.
  ///
  /// When the user scrolls near the bottom of the list (within 200 pixels),
  /// this method requests the next batch of products from the provider.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(productsProvider.notifier).loadMoreProducts();
    }
  }

  /// Filters the list of products based on the current search query and category.
  ///
  /// * [allProducts]: The complete list of loaded products.
  /// * Returns: A filtered sub-list matching the criteria.
  List<Product> _filterProducts(List<Product> allProducts) {
    return allProducts.where((p) {
      final q = _query.trim().toLowerCase();
      
      // Match against name or description
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
      
      // Match against selected category (or 'All')
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers for reactive updates.
    final cartItemsAsync = ref.watch(cartItemsProvider);
    final productsState = ref.watch(productsProvider);
    
    // Calculate total items in cart for the badge.
    final int cartItemCount = _calculateCartItemCount(cartItemsAsync);

    return Scaffold(
      appBar: _buildAppBar(context, cartItemCount),
      floatingActionButton: _buildFloatingActionButton(context),
      
      // Main Body Layout: Uses a Row to support the side-by-side Chat Panel.
      body: Row(
        children: [
          // Expanded area for the Product Grid (takes up remaining space)
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
          
          // Collapsible Chat Panel on the right side
          _buildChatPanel(context, productsState),
        ],
      ),
    );
  }

  /// Helper to calculate the total quantity of items in the cart safely.
  int _calculateCartItemCount(AsyncValue<List<dynamic>> cartItemsAsync) {
    return cartItemsAsync.when(
      data: (items) => items
          .fold<num>(0, (previousValue, element) => previousValue + element.quantity)
          .toInt(),
      loading: () => 0,
      error: (err, stack) => 0,
    );
  }

  /// Builds the custom application bar.
  PreferredSizeWidget _buildAppBar(BuildContext context, int cartItemCount) {
    return AppBar(
      title: _buildAppBarTitle(),
      actions: [
        _buildSearchToggleButton(),
        
        // Personal Area / Profile Button
        IconButton(
          icon: const Icon(Icons.person),
          tooltip: 'Personal Area',
          onPressed: () {
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
        
        // Shopping Cart Button with Badge
        _buildCartButton(context, cartItemCount),
      ],
    );
  }

  /// Dynamic AppBar title: toggles between Logo and Search Field.
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
        onChanged: (v) => setState(() => _query = v),
      );
    }
    return Row(
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback text if logo fails to load
            return const Text(appName, style: TextStyle(fontWeight: FontWeight.bold));
          },
        ),
      ],
    );
  }

  /// Toggle button to switch between search mode and normal mode.
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

  /// Cart icon with a red badge counter.
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

  /// Horizontal scrollable list for selecting product categories.
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
              color: isSelected ? Theme.of(context).primaryColor : blackColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  /// FAB to open the Chat Assistant (hidden if already open).
  Widget? _buildFloatingActionButton(BuildContext context) {
    if (_isChatVisible) return null;
    return FloatingActionButton.extended(
      icon: const Icon(Icons.support_agent, size: 24),
      label: const Text('Chat'),
      onPressed: () => setState(() => _isChatVisible = true),
    );
  }

  /// The sliding side panel for the AI Chatbot.
  Widget _buildChatPanel(BuildContext context, ProductsState productsState) {
    return AnimatedContainer(
      duration: animationDuration,
      width: _isChatVisible ? chatPanelWidth : 0, // Animate width
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

  /// Builds the main content area (Error, Loading, Empty, or Grid).
  Widget _buildBody(ProductsState state) {
    // 1. Loading State
    if (state.isLoading)
      return const Center(child: CircularProgressIndicator());

    // 2. Error State (with empty list)
    if (state.errorMessage != null && state.products.isEmpty) {
      return ErrorRetryWidget(
        errorMessage: state.errorMessage!,
        onRetry: () => ref.read(productsProvider.notifier).refresh(),
      );
    }

    // Apply local filters (search query & category)
    final displayProducts = _filterProducts(state.products);

    // 3. Empty State (No results found)
    if (displayProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No products found.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 4. Data State (Product Grid)
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(productsProvider.notifier).refresh();
      },
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        // Responsive Grid Layout matching other screens
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280, 
          childAspectRatio: 0.60, 
          crossAxisSpacing: smallPadding,
          mainAxisSpacing: smallPadding,
        ),
        // Add extra items for loading indicators at the bottom
        itemCount: displayProducts.length + (state.isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          // Show loading spinner at the bottom when fetching more pages
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