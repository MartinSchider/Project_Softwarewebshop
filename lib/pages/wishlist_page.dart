// lib/pages/wishlist_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/providers/wishlist_provider.dart';
import 'package:webshop/providers/products_provider.dart';
import 'package:webshop/widgets/product_card.dart';
import 'package:webshop/utils/constants.dart';

/// A screen that displays the user's saved favorite products.
///
/// This widget acts as a filter over the global product list, showing only
/// items that match the IDs stored in the user's wishlist collection.
class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Fetch Wishlist IDs
    // We watch the list of IDs from Firestore (user-specific).
    final wishlistIdsAsync = ref.watch(wishlistIdsProvider);
    
    // 2. Fetch All Products
    // We access the global product state to retrieve full product details (name, price, image)
    // corresponding to the IDs. 
    //
    // Trade-off: In a production app with thousands of products, this "filter client-side" 
    // approach isn't scalable. We would typically use a `whereIn` Firestore query to fetch 
    // only specific items. However, since our architecture uses a paginated list for the 
    // home screen, we reuse that data here for simplicity and cache efficiency.
    final productsState = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: wishlistIdsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (ids) {
          if (ids.isEmpty) {
            return const Center(child: Text('Your wishlist is empty.'));
          }

          // Filter the products currently loaded in memory to find matches.
          final wishlistProducts = productsState.products
              .where((p) => ids.contains(p.id))
              .toList();

          // Edge Case: 
          // If a user favorites an item on page 10, then restarts the app, 
          // 'productsState' might only have page 1 loaded. The favorite ID exists, 
          // but the product data isn't in memory yet.
          //
          // For now, we show a helpful message. A robust fix would be to 
          // fetch missing products by ID explicitly.
          if (wishlistProducts.isEmpty) {
             return const Center(child: Text('Loading wishlist items... (Try scrolling the home page to load more products)'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(smallPadding),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.70,
              crossAxisSpacing: smallPadding,
              mainAxisSpacing: smallPadding,
            ),
            itemCount: wishlistProducts.length,
            itemBuilder: (context, index) {
              return ProductCard(product: wishlistProducts[index]);
            },
          );
        },
      ),
    );
  }
}