// lib/product_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; 
import 'package:webshop/models/product.dart';
import 'package:webshop/models/review.dart'; 
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/providers/wishlist_provider.dart';
import 'package:webshop/providers/review_provider.dart';
import 'package:webshop/providers/products_provider.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/widgets/custom_image.dart';
import 'package:webshop/utils/ui_helper.dart';

/// A comprehensive screen displaying the full details of a specific product.
///
/// This page allows users to:
/// 1. **View Details**: High-resolution images, descriptions, pricing, and stock.
/// 2. **Check Delivery**: Calculates estimated delivery dates based on working days.
/// 3. **Manage Cart**: Select quantity and add items to the shopping cart.
/// 4. **Manage Wishlist**: Add or remove the item from favorites.
/// 5. **Reviews**: Read existing reviews and verify purchase history to submit new ones.
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
  
  // Local state for the quantity selector.
  int _quantity = 1;

  // ==================================================================
  // DELIVERY DATE LOGIC
  // ==================================================================

  /// Calculates the estimated delivery date by adding [workingDays] to the current date.
  ///
  /// **Logic:**
  /// This function iterates through days one by one. It only increments the
  /// "days covered" counter if the current day is NOT Saturday or Sunday.
  /// This ensures the delivery estimate reflects business days only.
  ///
  /// **Formatting:**
  /// Returns a formatted string in English (e.g., "Monday, October 15").
  String _formatDeliveryDate(int workingDays) {
    DateTime date = DateTime.now();
    int daysAdded = 0;

    // Loop until we have accounted for all required working days.
    while (daysAdded < workingDays) {
      date = date.add(const Duration(days: 1));
      
      // If the day is distinct from Saturday (6) and Sunday (7), count it as a working day.
      if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
        daysAdded++;
      }
    }
    
    // Manual mapping for English localization (avoids extra 'intl' dependencies configuration).
    final daysNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final monthsNames = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    // Note: DateTime.weekday returns 1 for Monday, 7 for Sunday.
    final dayName = daysNames[date.weekday - 1];
    final dayNum = date.day;
    final monthName = monthsNames[date.month - 1];
    
    return "Estimated delivery by: $dayName, $monthName $dayNum";
  }

  // ==================================================================
  // QUANTITY LOGIC
  // ==================================================================

  /// Increments the local quantity counter, ensuring it doesn't exceed available stock.
  void _incrementQuantity() {
    if (_quantity < widget.product.stock) {
      setState(() => _quantity++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum available stock reached.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// Decrements the local quantity counter, ensuring it stays above 1.
  void _decrementQuantity() {
    if (_quantity > 1) setState(() => _quantity--);
  }

  // ==================================================================
  // CART & WISHLIST ACTIONS
  // ==================================================================

  /// Adds the selected quantity of the product to the global cart.
  ///
  /// * Checks authentication first.
  /// * Shows success/error feedback via [UiHelper].
  Future<void> _addToCart() async {
    if (_authService.currentUser == null) {
      _showLoginDialog();
      return;
    }
    try {
      await ref
          .read(cartServiceProvider)
          .addProductToCart(widget.product, _quantity);
      if (mounted) {
        UiHelper.showSuccess(
            context, 'Added $_quantity x ${widget.product.name} to cart!');
      }
    } catch (e) {
      if (mounted) UiHelper.showError(context, e);
    }
  }

  /// Toggles the product's status in the user's wishlist (Firestore).
  Future<void> _toggleWishlist(bool isFavorite) async {
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

  // ==================================================================
  // REVIEWS LOGIC
  // ==================================================================

  /// Prepares to show the "Add Review" dialog.
  ///
  /// **Business Rule:** Only users who have purchased this specific product
  /// are allowed to leave a review. This method queries [reviewRepositoryProvider]
  /// to verify purchase history before opening the form.
  Future<void> _showAddReviewDialog() async {
    final user = _authService.currentUser;

    if (user == null) {
      _showLoginDialog();
      return;
    }

    UiHelper.showLoading(context);

    try {
      final hasPurchased = await ref
          .read(reviewRepositoryProvider)
          .hasUserPurchasedProduct(user.uid, widget.product.id);

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (!hasPurchased) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Action not allowed"),
              content: const Text(
                  "You can only review products that you have purchased."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK")),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) _openReviewFormDialog(user);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading on error
      if (mounted) {
        UiHelper.showError(context, "Could not verify purchase history.");
      }
    }
  }

  /// Displays the form to rate and comment on the product.
  void _openReviewFormDialog(User user) {
    double newRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Write a Review"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Rate this product:"),
            const SizedBox(height: 8),
            RatingBar.builder(
              initialRating: 5,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) => newRating = rating,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: "Comment",
                hintText: "What did you like?",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (commentController.text.trim().isEmpty) {
                UiHelper.showError(context, "Please write a comment.");
                return;
              }

              // Create review object
              final review = Review(
                id: '', // Generated by Firestore
                userId: user.uid,
                userName: user.displayName ?? 'Customer',
                productId: widget.product.id,
                rating: newRating,
                comment: commentController.text.trim(),
                timestamp: DateTime.now(),
              );

              try {
                await ref
                    .read(reviewRepositoryProvider)
                    .addReview(widget.product.id, review);

                ref.invalidate(productsProvider); // Refresh global product data (ratings)

                if (mounted) {
                  Navigator.pop(ctx);
                  UiHelper.showSuccess(context, "Review posted!");
                }
              } catch (e) {
                if (mounted) UiHelper.showError(context, e);
              }
            },
            child: const Text("Submit"),
          )
        ],
      ),
    );
  }

  /// Renders the list of existing reviews or a placeholder message.
  Widget _buildReviewsSection() {
    // Watches a specific provider family for this product's reviews.
    final reviewsAsync = ref.watch(productReviewsProvider(widget.product.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reviews',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.rate_review),
              label: const Text("Write a Review"),
              onPressed: _showAddReviewDialog,
            )
          ],
        ),
        const SizedBox(height: 16),
        
        // Handle loading/error/data states for reviews
        reviewsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error loading reviews: $err'),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                      "No reviews yet. Be the first to verify and review!",
                      style: TextStyle(color: Colors.grey)),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(review.userName.isNotEmpty
                        ? review.userName[0].toUpperCase()
                        : 'U'),
                  ),
                  title: Row(
                    children: [
                      Text(review.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      RatingBarIndicator(
                        rating: review.rating,
                        itemBuilder: (context, index) =>
                            const Icon(Icons.star, color: Colors.amber),
                        itemCount: 5,
                        itemSize: 14.0,
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(review.comment),
                      Text(
                        review.timestamp.toString().split(' ')[0],
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Helper method to prompt anonymous users to log in.
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
    // ==================================================================
    // UI BUILD
    // ==================================================================
    final bool isOutOfStock = widget.product.stock <= 0;
    final bool isOnSale = widget.product.discountPercentage > 0;

    // Check if product is in wishlist to update UI state
    final wishlistIdsAsync = ref.watch(wishlistIdsProvider);
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
            // ==================================================================
            // 1. HEADER IMAGE & DISCOUNT BADGE
            // ==================================================================
            Stack(
              children: [
                if (widget.product.imageUrl.isNotEmpty)
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: CustomImage(
                      imageUrl: widget.product.imageUrl,
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
                  
                if (isOnSale)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: errorColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                      ),
                      child: Text(
                        "-${widget.product.discountPercentage}%",
                        style: const TextStyle(color: whiteColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  )
              ],
            ),

            // ==================================================================
            // 2. PRODUCT INFO SECTION
            // ==================================================================
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isOnSale)
                            Text(
                              '€${widget.product.originalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          Text(
                            '€${widget.product.price.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: isOnSale ? errorColor : Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // --- DELIVERY ESTIMATE DISPLAY ---
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        // Uses the custom function to format delivery date
                        _formatDeliveryDate(widget.product.deliveryDays),
                        style: const TextStyle(
                          color: successColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // ---------------------------------

                  const SizedBox(height: defaultPadding),

                  // Stock Status Indicator
                  Row(
                    children: [
                      Icon(
                        isOutOfStock
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
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

                  // Description
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

                  // ==================================================================
                  // 3. ACTIONS (QUANTITY & ADD TO CART)
                  // ==================================================================
                  Row(
                    children: [
                      const Text('Quantity:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      // Quantity Selector Widget
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
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
                              onPressed: isOutOfStock ||
                                      _quantity >= widget.product.stock
                                  ? null
                                  : _incrementQuantity,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      // Wishlist Button
                      Container(
                        height: 50, 
                        width: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(smallPadding),
                          border: Border.all(
                            color:
                                isFavorite ? errorColor : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          color: isFavorite
                              ? errorColor.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? errorColor : Colors.grey,
                          ),
                          onPressed: () => _toggleWishlist(isFavorite),
                        ),
                      ),

                      const SizedBox(width: 16), 

                      // Add to Cart Button
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
                                style: const TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isOutOfStock ? Colors.grey : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ==================================================================
                  // 4. REVIEWS SECTION
                  // ==================================================================
                  _buildReviewsSection(),

                  const SizedBox(height: 24), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}