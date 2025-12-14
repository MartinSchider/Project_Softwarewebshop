// lib/product_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/providers/wishlist_provider.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/widgets/custom_image.dart';
import 'package:webshop/utils/ui_helper.dart';

/// A screen that displays detailed information about a specific product.
///
/// This page allows the user to:
/// * View product images and descriptions.
/// * Check stock status.
/// * Select a quantity.
/// * Add the item to the cart or wishlist.
class ProductDetailPage extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailPage({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  final AuthService _authService = AuthService();
  
  // Start with a default quantity of 1 to allow immediate addition.
  int _quantity = 1;

  /// Increases the selected quantity, ensuring it doesn't exceed available stock.
  void _incrementQuantity() {
    if (_quantity < widget.product.stock) {
      setState(() => _quantity++);
    } else {
      // UX: Feedback when the user hits the stock limit.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum available stock reached.'),
          duration: Duration(seconds: 1), 
        ),
      );
    }
  }

  /// Decreases the quantity, ensuring it stays above 1.
  void _decrementQuantity() {
    if (_quantity > 1) setState(() => _quantity--);
  }

  /// Handles the "Add to Cart" action with authentication checks.
  Future<void> _addToCart() async {
    // Gatekeeper: Ensure only logged-in users can shop.
    if (_authService.currentUser == null) {
      _showLoginDialog();
      return;
    }
    try {
      await ref.read(cartServiceProvider).addProductToCart(widget.product, _quantity);
      if (mounted) {
        UiHelper.showSuccess(context, 'Added $_quantity x ${widget.product.name} to cart!');
      }
    } catch (e) {
      if (mounted) UiHelper.showError(context, e);
    }
  }

  // --- WISHLIST LOGIC ---
  
  /// Toggles the product's presence in the user's wishlist.
  Future<void> _toggleWishlist(bool isFavorite) async {
    // 1. Check Auth: Wishlist data is user-specific.
    if (_authService.currentUser == null) {
      _showLoginDialog();
      return;
    }

    final controller = ref.read(wishlistControllerProvider);

    try {
      if (isFavorite) {
        await controller.remove(widget.product.id);
        if (mounted) UiHelper.showSuccess(context, "Removed from wishlist");
      } else {
        await controller.add(widget.product.id);
        if (mounted) UiHelper.showSuccess(context, "Added to wishlist");
      }
    } catch (e) {
      if (mounted) UiHelper.showError(context, e);
    }
  }

  /// Displays a dialog prompting anonymous users to sign in.
  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Access required'),
          content: const Text('You must log in to perform this action.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Login / Sign Up'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AuthPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stock status once to drive UI logic.
    final bool isOutOfStock = widget.product.stock <= 0;

    // --- WISHLIST STATE ---
    final wishlistIdsAsync = ref.watch(wishlistIdsProvider);
    // Determine if this specific product is in the wishlist list.
    final bool isFavorite = wishlistIdsAsync.maybeWhen(
      data: (ids) => ids.contains(widget.product.id),
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Product Image ---
            if (widget.product.imageUrl.isNotEmpty)
              SizedBox(
                height: 300,
                width: double.infinity,
                child: CustomImage(
                  imageUrl: widget.product.imageUrl,
                  // Use 'contain' to ensure the whole product is visible.
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                height: 300,
                color: Colors.grey[200],
                child: Center(
                  child: Icon(Icons.image_not_supported,
                      size: 100, color: Colors.grey[400]),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header: Name & Price ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: blackColor,
                              ),
                        ),
                      ),
                      Text(
                        '€${widget.product.price.toStringAsFixed(2)}',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: smallPadding),

                  // --- Stock Indicator ---
                  Row(
                    children: [
                      Icon(
                        isOutOfStock ? Icons.error_outline : Icons.check_circle_outline,
                        color: isOutOfStock ? errorColor : successColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOutOfStock 
                            ? 'Out of Stock' 
                            : 'In Stock: ${widget.product.stock} units',
                        style: TextStyle(
                          color: isOutOfStock ? errorColor : successColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: defaultPadding),

                  // --- Description ---
                  Text(
                    'Description',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: smallPadding),
                  Text(
                    widget.product.description.isNotEmpty
                        ? widget.product.description
                        : 'No description available.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.grey[800], height: 1.5),
                  ),

                  const SizedBox(height: 32),

                  // --- Quantity Selector ---
                  Row(
                    children: [
                      const Text('Quantity:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                          // Visual cue: gray out if out of stock.
                          color: isOutOfStock ? Colors.grey.shade200 : null,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: isOutOfStock || _quantity <= 1 
                                  ? null 
                                  : _decrementQuantity,
                            ),
                            Text(
                              isOutOfStock ? '0' : '$_quantity',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: isOutOfStock || _quantity >= widget.product.stock 
                                  ? null 
                                  : _incrementQuantity,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // --- ACTION BUTTONS ROW ---
                  Row(
                    children: [
                      // 1. WISHLIST BUTTON (Square)
                      Container(
                        height: 50, // Matches height of the cart button for symmetry.
                        width: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(smallPadding),
                          border: Border.all(
                            color: isFavorite ? Colors.red : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          color: isFavorite ? Colors.red.withOpacity(0.1) : Colors.transparent,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                          ),
                          onPressed: () => _toggleWishlist(isFavorite),
                        ),
                      ),
                      
                      const SizedBox(width: 16), // Spacing

                      // 2. ADD TO CART BUTTON (Expanded)
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: isOutOfStock ? null : _addToCart,
                            icon: const Icon(Icons.shopping_cart),
                            label: Text(
                                isOutOfStock 
                                    ? 'Out of Stock' 
                                    : 'Add to Cart (€${(widget.product.price * _quantity).toStringAsFixed(2)})',
                                // Use a slightly smaller font to ensure the price fits on smaller screens.
                                style: const TextStyle(fontSize: 16)), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOutOfStock ? Colors.grey : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24), // Extra bottom padding for scrolling comfortable.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}