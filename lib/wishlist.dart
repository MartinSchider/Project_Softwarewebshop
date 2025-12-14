// lib/pages/wishlist_page.dart
import 'package:flutter/material.dart';
import 'package:webshop/utils/constants.dart';

/// A placeholder page for the User's Wishlist.
///
/// Currently static, but intended to display items saved for later.
class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
            const SizedBox(height: defaultPadding),
            const Text(
              'Your wishlist is empty yet.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: smallPadding),
            const Text(
              'Save items you want to buy later!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}