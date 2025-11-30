// lib/providers/cart_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/services/cart_service.dart';
import 'package:webshop/models/cart_item.dart';

/// Provides a singleton instance of the [CartService].
///
/// This provider acts as the entry point for all cart-related operations
/// (add, remove, update quantity, apply gift card). It ensures that
/// the service is instantiated only once and shared across the app.
final cartServiceProvider = Provider<CartService>((ref) {
  return CartService();
});

/// Provides a real-time stream of the items currently in the user's cart.
///
/// This provider listens to the `items` sub-collection in Firestore.
/// It automatically updates the UI whenever a product is added or removed.
///
/// Returns an empty list if the user is not logged in.
final cartItemsProvider = StreamProvider<List<CartItem>>((ref) {
  final user = FirebaseAuth.instance.currentUser;

  // Security check: We don't want to open a stream if there's no user,
  // as it would waste resources and potentially cause permission errors.
  if (user == null) return Stream.value([]);

  final cartService = ref.watch(cartServiceProvider);
  return cartService.getCartStream();
});

/// Provides the raw metadata of the cart from the parent document.
///
/// Unlike [cartItemsProvider] which lists products, this provider listens
/// to fields stored directly on the `carts/{userId}` document, such as:
/// - [giftCardAppliedAmount]: The discount value calculated by Cloud Functions.
/// - [appliedGiftCardCode]: The code string (e.g., "SAVE10").
///
/// We separate this from the items stream to avoid fetching the full product list
/// when only metadata changes (optimization).
final rawCartDetailsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value({});

  final cartService = ref.watch(cartServiceProvider);
  return cartService.getCartDetailsStream();
});

/// Computes the final financial totals for the cart (Client-Side Logic).
///
/// This is a "Computed Provider" that combines data from two sources:
/// 1. [cartItemsProvider]: To calculate the subtotal locally (Price * Quantity).
/// 2. [rawCartDetailsProvider]: To get server-side validated discounts.
///
/// **Why calculate locally?**
/// Calculating the subtotal on the client provides instant feedback to the user
/// when they change quantities, without waiting for a Cloud Function to run
/// and update the database.
final cartDetailsProvider = Provider<AsyncValue<Map<String, dynamic>>>((ref) {
  final cartItemsAsync = ref.watch(cartItemsProvider);
  final rawDetailsAsync = ref.watch(rawCartDetailsProvider);

  // If the product list is loading, we cannot calculate the total yet.
  if (cartItemsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final items = cartItemsAsync.value ?? [];
  final rawDetails = rawDetailsAsync.value ?? {};

  // --- LOCAL CALCULATION ---
  // We iterate through the items to sum up the total price.
  // This ensures the subtotal is always in sync with what the user sees in the list.
  double subtotal = 0.0;
  for (var item in items) {
    subtotal += item.product.price * item.quantity;
  }

  // Retrieve the discount value from the database.
  // This value is typically written by a Cloud Function after verifying the gift card.
  double giftCardDiscount =
      (rawDetails['giftCardAppliedAmount'] as num?)?.toDouble() ?? 0.0;
  String? appliedCode = rawDetails['appliedGiftCardCode'] as String?;

  // Calculate the final amount to pay.
  // We apply a floor of 0.0 to prevent negative totals in case the discount > subtotal.
  double totalToPay = subtotal - giftCardDiscount;
  if (totalToPay < 0) totalToPay = 0.0;

  return AsyncValue.data({
    'subtotal': subtotal, // The raw cost of items
    'giftCardAppliedAmount': giftCardDiscount, // The discount applied
    'finalAmountToPay': totalToPay, // What the user actually pays
    'totalPrice': subtotal, // Alias kept for UI compatibility
    'appliedGiftCardCode': appliedCode, // The code to display in the UI
    'itemCount': items.length, // Total unique items count
  });
});
