// lib/product_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/widgets/custom_image.dart';

/// Displays the full details of a selected product.
///
/// This screen allows the user to:
/// 1. View high-resolution images and full descriptions.
/// 2. Select a quantity to purchase.
/// 3. Add the product to the shopping cart.
class ProductDetailPage extends ConsumerStatefulWidget {
  /// The product object passed from the listing screen.
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

  // Local state for the quantity selector. Defaults to 1 item.
  int _quantity = 1;

  /// Increases the selected quantity.
  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  /// Decreases the selected quantity (minimum 1).
  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  /// Handles the "Add to Cart" action.
  ///
  /// This method performs two main tasks:
  /// 1. **Auth Check:** Verifies if the user is logged in. If not, shows a login dialog.
  /// 2. **Service Call:** Calls [CartService] to add the item with the selected quantity.
  Future<void> _addToCart() async {
    // 1. Auth Check: We gate the cart functionality behind authentication.
    if (_authService.currentUser == null) {
      _showLoginDialog();
      return;
    }

    try {
      // 2. Call the Service via Riverpod provider.
      await ref
          .read(cartServiceProvider)
          .addProductToCart(widget.product, _quantity);

      // Provide visual feedback if the widget is still active.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $_quantity x ${widget.product.name} to cart!'),
            backgroundColor: successColor,
            duration: const Duration(seconds: 2),
          ),
        );
        // Optional: Close the page to return to the list
        // Navigator.of(context).pop();
      }
    } catch (e) {
      // Error Handling: Show specific error (e.g., "Not enough stock").
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to cart: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  /// Displays a dialog prompting the user to log in.
  ///
  /// This is a "soft block" - allows browsing but restricts transactional actions.
  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Access required'),
          content: const Text('You must log in to add products to the cart.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Login / Sign Up'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to the Auth Page
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Product Image ---
            // Uses cached network image for performance.
            if (widget.product.imageUrl.isNotEmpty)
              SizedBox(
                height: 300,
                width: double.infinity,
                child: CustomImage(
                  imageUrl: widget.product.imageUrl,
                  fit: BoxFit.contain, // Ensures the whole product is visible
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
                  // --- Title and Price ---
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
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _decrementQuantity,
                            ),
                            Text(
                              '$_quantity',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _incrementQuantity,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // --- Add to Cart Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(Icons.shopping_cart),
                      label: Text(
                          'Add to Cart (€${(widget.product.price * _quantity).toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
