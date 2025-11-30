// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/services/cart_service.dart';
import 'package:webshop/product_detail_page.dart';
import 'package:webshop/utils/ui_helper.dart';
import 'package:webshop/widgets/custom_image.dart';

/// A card widget displaying a summary of a product.
///
/// This component is used in the main product grid list. It provides:
/// 1. A cached image preview.
/// 2. Essential product details (name, price).
/// 3. Quick actions: View details (tap) and Add to Cart (button).
class ProductCard extends ConsumerWidget {
  /// The product data to display.
  final Product product;

  /// Creates a [ProductCard].
  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Access the cart service to handle "Add to Cart" actions.
    final cartService = ref.read(cartServiceProvider);

    return Card(
      elevation: cardElevation,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius)),
      margin: const EdgeInsets.all(smallPadding),
      // Anti-alias clip is required to ensure the InkWell ripple effect respects the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // NAVIGATION: Tapping the card opens the full detail page.
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(smallPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Image Section ---
              // Expanded ensures the image takes up all available vertical space
              // in the card, pushing text to the bottom.
              Expanded(
                child: Center(
                  child: CustomImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit
                        .contain, // Ensures the whole product is visible without cropping
                  ),
                ),
              ),
              const SizedBox(height: smallPadding),

              // --- Text Section ---
              Text(
                product.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                product.description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // --- Action Section ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '€${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),

                  // Quick Add Button
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () async {
                      // AUTH CHECK: Ensure user is logged in before adding to cart.
                      if (FirebaseAuth.instance.currentUser == null) {
                        // If not logged in, redirect to AuthPage.
                        // We await the result to see if they logged in successfully.
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const AuthPage()),
                        );

                        // Safety check: Context might be invalid if user navigated away.
                        if (!context.mounted) return;

                        // Check again if login was successful
                        if (FirebaseAuth.instance.currentUser != null) {
                          _attemptAddToCart(context, cartService, product);
                        } else {
                          // Feedback if user cancelled login
                          UiHelper.showError(
                              context, 'Please sign in to add items to cart.');
                        }
                      } else {
                        // User is already logged in, proceed directly.
                        _attemptAddToCart(context, cartService, product);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper method to execute the add-to-cart logic with UI feedback.
  void _attemptAddToCart(
      BuildContext context, CartService cartService, Product product) async {
    try {
      await cartService.addProductToCart(product, 1);

      // Provide positive feedback
      if (context.mounted) {
        UiHelper.showSuccess(context, '${product.name} added to cart!');
      }
    } catch (e) {
      // Provide error feedback (e.g., network error or out of stock)
      if (context.mounted) {
        UiHelper.showError(context, e);
      }
    }
  }
}
