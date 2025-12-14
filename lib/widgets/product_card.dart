// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/providers/wishlist_provider.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/services/cart_service.dart';
import 'package:webshop/product_detail_page.dart';
import 'package:webshop/utils/ui_helper.dart';
import 'package:webshop/widgets/custom_image.dart';

/// A widget representing a single product item within a grid or list.
///
/// This widget encapsulates the UI presentation of a [Product] and handles
/// immediate user interactions such as:
/// * Navigating to the detail page.
/// * Toggling the wishlist status.
/// * Adding the item to the cart (if in stock).
class ProductCard extends ConsumerWidget {
  /// The product data to display.
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartService = ref.read(cartServiceProvider);
    
    // --- Wishlist State ---
    final wishlistIdsAsync = ref.watch(wishlistIdsProvider);
    final wishlistController = ref.read(wishlistControllerProvider);
    
    // Check if the current product ID exists in the list of user favorites
    // to determine the state of the heart icon.
    final bool isFavorite = wishlistIdsAsync.maybeWhen(
      data: (ids) => ids.contains(product.id),
      orElse: () => false,
    );

    // --- Stock Logic ---
    // Pre-calculate these booleans to drive UI variations (badges, button disabling)
    // without cluttering the widget tree with logic.
    final bool isOutOfStock = product.stock <= 0;
    final bool isLowStock = product.stock > 0 && product.stock < 5;

    // --- Actions ---

    /// Toggles the product in the user's wishlist.
    ///
    /// Requires authentication because the wishlist is persisted in the
    /// user's specific Firestore document.
    Future<void> _toggleWishlist() async {
      if (FirebaseAuth.instance.currentUser == null) {
        // Redirect anonymous users to the auth page to secure the data.
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthPage()));
        return;
      }
      try {
        if (isFavorite) {
          await wishlistController.remove(product.id);
        } else {
          await wishlistController.add(product.id);
          UiHelper.showSuccess(context, "Added to wishlist");
        }
      } catch (e) {
        if (context.mounted) UiHelper.showError(context, e);
      }
    }

    /// Adds the product to the cart.
    ///
    /// Also enforces authentication because carts are tied to specific User UIDs
    /// in the database structure.
    void _attemptAddToCart() async {
      if (FirebaseAuth.instance.currentUser == null) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthPage()));
        // If user cancelled login, abort operation.
        if (FirebaseAuth.instance.currentUser == null) return;
      }
      
      try {
        await cartService.addProductToCart(product, 1);
        if (context.mounted) UiHelper.showSuccess(context, 'Added to cart');
      } catch (e) {
        if (context.mounted) UiHelper.showError(context, e);
      }
    }

    return Card(
      elevation: 2, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      margin: const EdgeInsets.all(4), 
      clipBehavior: Clip.antiAlias,
      color: Colors.white, // Clean white background for better image contrast
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. IMAGE AREA ---
            Expanded(
              child: Stack(
                children: [
                  // Product Image
                  Padding(
                    padding: const EdgeInsets.all(12.0), 
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: CustomImage(
                        imageUrl: product.imageUrl,
                        // Use 'contain' to ensure the entire product is visible.
                        // 'cover' might crop essential details (e.g., shoe shape, bottle branding).
                        fit: BoxFit.contain, 
                      ),
                    ),
                  ),

                  // Wishlist Button (Floating Top-Right)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1)
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18, 
                        ),
                        color: isFavorite ? Colors.red : Colors.grey,
                        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                        padding: EdgeInsets.zero,
                        onPressed: _toggleWishlist,
                      ),
                    ),
                  ),

                  // Stock Badge (Floating Top-Left)
                  // Provides immediate visual feedback on availability urgency.
                  if (isOutOfStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildBadge('SOLD OUT', errorColor),
                    )
                  else if (isLowStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildBadge('LOW STOCK', Colors.orange),
                    ),
                ],
              ),
            ),

            // --- 2. INFO AREA ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Label
                  Text(
                    product.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 2),

                  // Product Name
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Price & Add Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      Text(
                        '€${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),

                      // Add to Cart Button (Compact Circle)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Material(
                          // Grey out button if out of stock to indicate non-interactivity
                          color: isOutOfStock ? Colors.grey[300] : Theme.of(context).primaryColor,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: isOutOfStock ? null : _attemptAddToCart,
                            child: Icon(
                              Icons.add_shopping_cart,
                              size: 18,
                              color: isOutOfStock ? Colors.grey : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to create consistent status badges (Sold Out / Low Stock).
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}