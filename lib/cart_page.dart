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
/// This screen displays the list of selected products, allows modifying quantities,
/// and shows the financial breakdown (Subtotal, Discount, Total).
/// It serves as the entry point for the checkout flow.
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch two separate providers:
    // 1. cartItemsProvider: For the list of products (Stream<List<CartItem>>)
    // 2. cartDetailsProvider: For the calculated totals (Future/Stream<Map>)
    final cartItemsAsync = ref.watch(cartItemsProvider);
    final cartDetailsAsync = ref.watch(cartDetailsProvider);
    final CartService cartService = ref.read(cartServiceProvider);

    // Wrapper function to handle async quantity updates with error feedback.
    Future<void> _updateQuantity(
        BuildContext context, String productId, int newQuantity) async {
      try {
        await cartService.updateCartItemQuantity(productId, newQuantity);
      } catch (e) {
        // Only show the SnackBar if the user is still on this screen.
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
          // --- PRODUCT LIST SECTION ---
          // Using Expanded allows the list to take up all available space
          // pushing the totals section to the bottom.
          Expanded(
            child: cartItemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),

              // Custom error widget with Retry button (Fixes 5.5 No Error Recovery)
              error: (err, stack) => ErrorRetryWidget(
                errorMessage: err.toString(),
                onRetry: () => ref.refresh(cartItemsProvider),
              ),

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
                            // Product Image (Using Cached CustomImage)
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

                            // Product Info
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

                            // Quantity Controls
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

          // --- TOTALS & CHECKOUT SECTION ---
          // This section is pinned to the bottom of the screen.
          cartDetailsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => Container(
                padding: const EdgeInsets.all(16), child: Text('Error: $err')),
            data: (details) {
              // Extract calculated values with null safety defaults
              final double subtotal =
                  (details['subtotal'] as num?)?.toDouble() ?? 0.0;
              final double discount =
                  (details['giftCardAppliedAmount'] as num?)?.toDouble() ?? 0.0;
              final double totalToPay =
                  (details['finalAmountToPay'] as num?)?.toDouble() ?? 0.0;
              final int itemCount = cartItemsAsync.value?.length ?? 0;

              // Hide checkout button if cart is empty
              if (itemCount == 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  // Subtle shadow to separate the totals from the list
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

                      // Discount Row (Conditionally rendered)
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

                      // Proceed to Checkout Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
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
