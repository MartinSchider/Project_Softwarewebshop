// lib/pages/wishlist_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/providers/wishlist_provider.dart';
import 'package:webshop/providers/products_provider.dart';
import 'package:webshop/widgets/product_card.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/widgets/error_retry_widget.dart';

/// A dedicated screen for displaying the user's saved favorite products.
///
/// This widget acts as a filter view over the global product catalog. It combines
/// data from two sources:
/// 1. **Wishlist IDs**: fetched from the user's private collection in Firestore.
/// 2. **Product Data**: fetched from the global product repository.
///
/// This approach ensures that the wishlist always displays the most up-to-date
/// product information (price, stock) without duplicating data in the user's document.
class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the list of Product IDs marked as favorites by the user.
    final wishlistIdsAsync = ref.watch(wishlistIdsProvider);
    
    // 2. Watch the global state of loaded products to resolve IDs into actual objects.
    final productsState = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      
      // Handle the asynchronous state of fetching the ID list.
      body: wishlistIdsAsync.when(
        // Show a loading spinner while the IDs are being retrieved.
        loading: () => const Center(child: CircularProgressIndicator()),
        
        // Show a standardized error widget if the fetch fails (e.g., network issues).
        error: (e, st) => ErrorRetryWidget(
          errorMessage: e.toString(),
          onRetry: () => ref.refresh(wishlistIdsProvider),
        ),
        
        data: (ids) {
          // ==================================================================
          // EMPTY STATE
          // ==================================================================
          // Display a friendly placeholder if the user hasn't saved any items.
          if (ids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  const SizedBox(height: defaultPadding),
                  const Text(
                    'Your wishlist is empty.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: smallPadding),
                  const Text(
                    'Save items you want to buy later!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // ==================================================================
          // DATA FILTERING
          // ==================================================================
          // Match the fetched IDs against the globally loaded products.
          // Note: In a production app with pagination, this might require fetching
          // specific missing IDs from the server if they aren't in the current 'productsState'.
          final wishlistProducts =
              productsState.products.where((p) => ids.contains(p.id)).toList();

          // Handle case where IDs exist but product data isn't loaded yet.
          if (wishlistProducts.isEmpty) {
             return const Center(
                child: Padding(
                  padding: EdgeInsets.all(defaultPadding),
                  child: Text(
                    'Loading wishlist items... (Try scrolling the home page to load more products)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ));
          }

          // ==================================================================
          // PRODUCT GRID
          // ==================================================================
          // Uses the exact same grid delegate as ProductsScreen to maintain
          // visual consistency across the application.
          return GridView.builder(
            padding: const EdgeInsets.all(defaultPadding),
            
            // Responsive Grid Layout:
            // Uses MaxCrossAxisExtent to adapt column count to screen width.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280, // Matches global product card width
              childAspectRatio: 0.60,  // Matches global product card aspect ratio
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