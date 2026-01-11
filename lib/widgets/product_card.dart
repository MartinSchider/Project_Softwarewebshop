// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/providers/wishlist_provider.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/product_detail_page.dart';
import 'package:webshop/utils/ui_helper.dart';
import 'package:webshop/widgets/custom_image.dart';

/// A reusable widget that displays a summary of a [Product].
///
/// This card is used in grids (Home, Wishlist) and lists. It handles:
/// * **Visuals**: Product image, badges (Sale, Express, Stock), and details.
/// * **Interactions**: Tapping to view details, toggling wishlist status, and adding to cart.
/// * **State Integration**: Connects to Riverpod providers for Cart and Wishlist management.
class ProductCard extends ConsumerWidget {
  /// The product data model to display.
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ==================================================================
    // 1. PROVIDERS & STATE ACCESS
    // ==================================================================
    final cartService = ref.read(cartServiceProvider);
    
    // Watch the wishlist IDs to reactively update the heart icon.
    final wishlistIdsAsync = ref.watch(wishlistIdsProvider);
    final wishlistController = ref.read(wishlistControllerProvider);

    // Determine if the current product is in the user's wishlist.
    final bool isFavorite = wishlistIdsAsync.maybeWhen(
      data: (ids) => ids.contains(product.id),
      orElse: () => false,
    );

    // ==================================================================
    // 2. DERIVED UI STATE (BADGES LOGIC)
    // ==================================================================
    final bool isOutOfStock = product.stock <= 0;
    final bool isLowStock = product.stock > 0 && product.stock < 5;
    final bool isOnSale = product.discountPercentage > 0;
    
    // Determine if the product qualifies for "Express" delivery (<= 2 days).
    final bool isExpress = product.deliveryDays <= 2;

    // ==================================================================
    // 3. EVENT HANDLERS
    // ==================================================================

    /// Toggles the product's presence in the user's wishlist.
    /// Redirects to Login if the user is anonymous.
    Future<void> _toggleWishlist() async {
      if (FirebaseAuth.instance.currentUser == null) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AuthPage()));
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

    /// Adds one unit of the product to the cart.
    /// Redirects to Login if the user is anonymous.
    void _attemptAddToCart() async {
      if (FirebaseAuth.instance.currentUser == null) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AuthPage()));
        // Check if user logged in successfully after returning
        if (FirebaseAuth.instance.currentUser == null) return;
      }

      try {
        await cartService.addProductToCart(product, 1);
        if (context.mounted) UiHelper.showSuccess(context, 'Added to cart');
      } catch (e) {
        if (context.mounted) UiHelper.showError(context, e);
      }
    }

    // ==================================================================
    // 4. UI COMPOSITION
    // ==================================================================
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius)), // Uses constant
      margin: const EdgeInsets.all(4),
      clipBehavior: Clip.antiAlias,
      color: whiteColor, // Uses constant
      child: InkWell(
        // Navigate to Detail Page on tap
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
            // --- TOP SECTION: Image & Overlays ---
            Expanded(
              child: Stack(
                children: [
                  // Product Image
                  Padding(
                    padding: const EdgeInsets.all(16.0), 
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: CustomImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Wishlist Icon (Top-Right)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: whiteColor.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              spreadRadius: 1)
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                        ),
                        color: isFavorite ? errorColor : Colors.grey,
                        constraints: const BoxConstraints.tightFor(
                            width: 32, height: 32),
                        padding: EdgeInsets.zero,
                        onPressed: _toggleWishlist,
                      ),
                    ),
                  ),

                  // Badges Column (Top-Left)
                  // Displays Sale, Express, or Stock warnings
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOutOfStock)
                          _buildBadge('SOLD OUT', errorColor)
                        else ...[
                          // Sale Badge
                          if (isOnSale) ...[
                            _buildBadge('-${product.discountPercentage}%', errorColor),
                            const SizedBox(height: 4),
                          ],
                          // Express Delivery Badge
                          if (isExpress) ...[
                            _buildBadge('EXPRESS', successColor),
                            const SizedBox(height: 4),
                          ],
                          // Low Stock Warning
                          if (isLowStock)
                            _buildBadge('LOW STOCK', Colors.orange),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- BOTTOM SECTION: Info & Actions ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
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

                  const SizedBox(height: 4),

                  // Rating Row
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: product.averageRating,
                        itemBuilder: (context, index) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        itemCount: 5,
                        itemSize: 12.0,
                        direction: Axis.horizontal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${product.reviewCount})',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Price & Add to Cart Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Pricing Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isOnSale)
                            Text(
                              '€${product.originalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '€${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isOnSale ? errorColor : Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      
                      // Add to Cart Button (Mini FAB style)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Material(
                          color: isOutOfStock
                              ? Colors.grey[300]
                              : Theme.of(context).primaryColor,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: isOutOfStock ? null : _attemptAddToCart,
                            child: Icon(
                              Icons.add_shopping_cart,
                              size: 18,
                              color: isOutOfStock ? Colors.grey : whiteColor,
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

  /// Helper method to create a standardized label badge.
  ///
  /// * [text]: The label to display (e.g., 'EXPRESS', '-20%').
  /// * [color]: The background color of the badge.
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
          color: whiteColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}