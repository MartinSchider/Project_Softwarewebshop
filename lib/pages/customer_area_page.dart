// lib/pages/customer_area_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:webshop/models/app_user.dart';
import 'package:webshop/pages/admin/admin_dashboard_page.dart';
import 'package:webshop/pages/orders_page.dart';
import 'package:webshop/pages/wishlist_page.dart';
import 'package:webshop/pages/fidelity_card_page.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/utils/constants.dart'; // Import constants for consistent styling

/// The central dashboard for the logged-in user.
///
/// This page acts as a navigation hub, providing quick access to all
/// customer-centric features:
/// * **Profile Overview**: Displays basic user info (Email).
/// * **Order History**: Link to past purchases.
/// * **Wishlist**: Link to saved favorite items.
/// * **Fidelity Program**: Access to the digital fidelity card.
/// * **Admin Tools**: Conditionally rendered link for administrators.
class CustomerAreaPage extends StatelessWidget {
  const CustomerAreaPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Access Firebase Auth directly to get the current user's session data.
    final user = FirebaseAuth.instance.currentUser;
    final AuthService authService = AuthService();

      if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Personal Area')),
        body: const Center(child: Text('Please log in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Area'),
        actions: [
          // --- LOGOUT ACTION ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Sign out from Firebase and close this screen to return to the main view.
              await authService.signOut();
              if (context.mounted) Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          children: [
            // ==================================================================
            // HEADER SECTION (Avatar & Email)
            // ==================================================================
            const CircleAvatar(
              radius: 40,
              backgroundColor: lightGreyColor,
              child: Icon(Icons.person, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: defaultPadding),
            Text(
              user.email ?? 'Customer',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // ==================================================================
            // DYNAMIC MENU GRID
            // ==================================================================
            // We use a FutureBuilder to fetch the user's full profile data (AppUser).
            // This is necessary to check the 'isAdmin' flag, which isn't available
            // in the standard FirebaseAuth user object.
            FutureBuilder<AppUser?>(
              future: authService.getAppUserProfileOnce(),
              builder: (context, snapshot) {
                // Determine admin status (default to false if loading or null)
                final bool isAdmin = snapshot.data?.isAdmin ?? false;

                // Use a GridView with SliverGridDelegateWithMaxCrossAxisExtent
                // to ensure the menu buttons have a consistent size and aspect ratio,
                // matching the responsive behavior of the product cards.
                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(), // Let the outer ScrollView handle scrolling
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280, // Same logic as ProductsScreen
                    childAspectRatio: 0.60,  // Consistent aspect ratio
                    crossAxisSpacing: smallPadding, // Consistent spacing
                    mainAxisSpacing: smallPadding,
                  ),
                  children: [
                    // 1. My Orders Button
                    _buildMenuButton(
                      context,
                      title: 'My Orders',
                      icon: Icons.receipt_long,
                      color: Colors.blueAccent,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const OrdersPage())),
                    ),
                    
                    // 2. Wishlist Button
                    _buildMenuButton(
                      context,
                      title: 'Wishlist',
                      icon: Icons.favorite_border,
                      color: Colors.pinkAccent,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WishlistPage())),
                    ),
                    
                    // 3. Fidelity Card Button
                    _buildMenuButton(
                      context,
                      title: 'Fidelity Card',
                      icon: Icons.card_membership,
                      color: Colors.purple,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FidelityCardPage())),
                    ),

                    // 4. Admin Panel Button (Conditional Render)
                    // Only visible if the user has administrative privileges.
                    if (isAdmin)
                      _buildMenuButton(
                        context,
                        title: 'Admin Panel',
                        icon: Icons.admin_panel_settings,
                        color: blackColor, // Use constant color
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AdminDashboardPage())),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget to construct consistent, clickable menu cards.
  ///
  /// This encapsulates the design logic for the dashboard buttons, ensuring
  /// uniform padding, elevation, and shape across the grid.
  ///
  /// * [title]: Label text displayed below the icon.
  /// * [icon]: The Material icon to represent the feature.
  /// * [color]: The primary color used for the icon and its background tint.
  /// * [onTap]: The function to execute when the card is tapped (usually navigation).
  Widget _buildMenuButton(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      elevation: cardElevation, // Use constant elevation
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius)), // Use constant radius
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Container(
              padding: const EdgeInsets.all(defaultPadding),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: defaultPadding),
            
            // Label Text
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}