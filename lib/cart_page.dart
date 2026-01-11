// lib/cart_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/checkout_shipping_page.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/models/cart_item.dart';
import 'package:webshop/services/cart_service.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/widgets/error_retry_widget.dart';
import 'package:webshop/widgets/custom_image.dart';

/// The main shopping cart screen.
///
/// This widget displays:
/// 1. A list of items currently in the user's cart.
/// 2. Controls to update quantities or remove items.
/// 3. A summary section showing the subtotal, discounts (if any), and the final total.
/// 4. A button to proceed to the Shipping/Checkout phase.
///
/// It relies on Riverpod providers ([cartItemsProvider], [cartDetailsProvider])
/// to reactively update the UI as the cart state changes.
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch cart items (List<CartItem>) to build the product list.
    final cartItemsAsync = ref.watch(cartItemsProvider);
    
    // Watch cart details (Map<String, dynamic>) for totals and discounts.
    final cartDetailsAsync = ref.watch(cartDetailsProvider);
    
    // Access the service to perform write operations (update/delete).
    final CartService cartService = ref.read(cartServiceProvider);

    /// Helper function to safely update item quantity.
    ///
    /// Wraps the service call in a try-catch block to show a SnackBar on failure.
    Future<void> _updateQuantity(
        BuildContext context, String productId, int newQuantity) async {
      try {
        await cartService.updateCartItemQuantity(productId, newQuantity);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating quantity: $e'),
              backgroundColor: errorColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: Column(
        children: [
          // ==================================================================
          // 1. PRODUCT LIST SECTION
          // ==================================================================
          Expanded(
            child: cartItemsAsync.when(
              // Show loading spinner while fetching items.
              loading: () => const Center(child: CircularProgressIndicator()),
              
              // Show error widget with retry button on failure.
              error: (err, stack) => ErrorRetryWidget(
                errorMessage: err.toString(),
                onRetry: () => ref.refresh(cartItemsProvider),
              ),
              
              // Render the list of cart items.
              data: (List<CartItem> items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Your cart is empty.',
                        style: TextStyle(fontSize: 18)),
                  );
                }
                
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: smallPadding, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            // Product Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CustomImage(
                                imageUrl: item.product.imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: smallPadding),
                            
                            // Product Info (Name & Price)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '€${item.product.price.toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Quantity Controls (- 1 +)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _updateQuantity(context,
                                      item.product.id, item.quantity - 1),
                                ),
                                Text('${item.quantity}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _updateQuantity(context,
                                      item.product.id, item.quantity + 1),
                                ),
                              ],
                            ),
                            
                            // Delete Button
                            IconButton(
                              icon: const Icon(Icons.delete, color: errorColor),
                              onPressed: () =>
                                  cartService.removeCartItem(item.product.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ==================================================================
          // 2. TOTALS & CHECKOUT SUMMARY SECTION
          // ==================================================================
          cartDetailsAsync.when(
            // Hide summary while loading or if list is empty (handled below).
            loading: () => const SizedBox.shrink(),
            
            // Basic error message if metadata fails to load.
            error: (err, stack) => Container(
                padding: const EdgeInsets.all(16), child: Text('Error: $err')),
            
            data: (details) {
              // Extract financial details safely.
              final double subtotal =
                  (details['subtotal'] as num?)?.toDouble() ?? 0.0;
              final double discount =
                  (details['giftCardAppliedAmount'] as num?)?.toDouble() ?? 0.0;
              final double totalToPay =
                  (details['finalAmountToPay'] as num?)?.toDouble() ?? 0.0;
              
              // Only show the footer if there are items in the cart.
              final int itemCount = cartItemsAsync.value?.length ?? 0;
              if (itemCount == 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subtotal Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:',
                              style: TextStyle(fontSize: 16)),
                          Text('€${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      
                      // Discount Row (Conditional)
                      if (discount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount:',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.green)),
                              Text('-€${discount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      
                      const Divider(height: 24),
                      
                      // Final Total Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total to Pay:',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('€${totalToPay.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor)),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Proceed to Shipping Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            // Navigate to the Shipping Address Form
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const CheckoutShippingPage()),
                            );
                          },
                          child: const Text('Proceed to Shipping',
                              style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}