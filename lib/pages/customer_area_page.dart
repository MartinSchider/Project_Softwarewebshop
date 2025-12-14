// lib/pages/customer_area_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/models/app_user.dart';
import 'package:webshop/pages/admin/admin_dashboard_page.dart';
import 'package:webshop/pages/orders_page.dart';
import 'package:webshop/pages/wishlist_page.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/utils/constants.dart';

/// The personal dashboard for authenticated users.
///
/// This page acts as a portal to user-specific features like:
/// * Viewing order history.
/// * Managing the wishlist.
/// * Accessing the Admin Panel (if the user has the 'isAdmin' flag).
/// * Signing out.
class CustomerAreaPage extends StatelessWidget {
  const CustomerAreaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final AuthService authService = AuthService();

    if (user == null) {
      // Fallback UI for unauthenticated state (though usually unreachable via normal navigation).
      return Scaffold(
        appBar: AppBar(title: const Text('Personal Area')),
        body: const Center(child: Text('Please log in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Area'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // Check mounted to ensure context is valid before popping.
              if (context.mounted) Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          children: [
            // User Avatar Placeholder
            const CircleAvatar(
              radius: 40,
              backgroundColor: lightGreyColor,
              child: Icon(Icons.person, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Display User Email
            Text(
              user.email ?? 'Customer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),

            // --- ROLE-BASED UI GENERATION ---
            // We fetch the full user profile from Firestore to determine if they are an Admin.
            // This is an async operation, so we use FutureBuilder to handle the loading state.
            FutureBuilder<AppUser?>(
              future: authService.getAppUserProfileOnce(),
              builder: (context, snapshot) {
                // Default to false (safe fail) if data is loading or null.
                final bool isAdmin = snapshot.data?.isAdmin ?? false;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: defaultPadding,
                  mainAxisSpacing: defaultPadding,
                  children: [
                    _buildMenuButton(
                      context,
                      title: 'My Orders',
                      icon: Icons.receipt_long,
                      color: Colors.blueAccent,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersPage())),
                    ),
                    _buildMenuButton(
                      context,
                      title: 'Wishlist',
                      icon: Icons.favorite_border,
                      color: Colors.pinkAccent,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WishlistPage())),
                    ),
                    
                    // --- ADMIN BUTTON ---
                    // Conditionally rendered only for users with the isAdmin flag.
                    if (isAdmin)
                      _buildMenuButton(
                        context,
                        title: 'Admin Panel',
                        icon: Icons.admin_panel_settings,
                        color: Colors.black87,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDashboardPage())),
                      ),
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  /// Helper to build consistent dashboard menu cards.
  Widget _buildMenuButton(BuildContext context, 
      {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}