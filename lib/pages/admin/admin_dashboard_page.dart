// lib/pages/admin/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/pages/admin/admin_edit_product_page.dart';
import 'package:webshop/pages/admin/admin_orders_page.dart';
import 'package:webshop/providers/products_provider.dart';
import 'package:webshop/repositories/admin_repository.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/utils/ui_helper.dart';
import 'package:webshop/widgets/custom_image.dart';

/// The central hub for administrative tasks.
///
/// This page displays the catalog of products and acts as the entry point for:
/// * Creating new products.
/// * Editing or deleting existing products.
/// * Navigating to the Order Management section.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch the product list to rebuild the UI automatically when items change.
    final productsState = ref.watch(productsProvider);
    final AdminRepository adminRepo = AdminRepository();

    /// Handles the deletion of a product with a safety check.
    ///
    /// We show a confirmation dialog first because deletion is irreversible.
    Future<void> _deleteProduct(String id) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await adminRepo.deleteProduct(id);
          // Explicitly refresh the provider to remove the stale item from the list immediately.
          ref.refresh(productsProvider);
          if (context.mounted) UiHelper.showSuccess(context, 'Product deleted');
        } catch (e) {
          if (context.mounted) UiHelper.showError(context, e);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        // MODIFICA: Uso il colore primario (verde) invece del nero
        backgroundColor: Theme.of(context).primaryColor,
        // We strictly define the icon color to ensure visibility against the dark app bar.
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // "Manage Orders" Button
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            tooltip: 'Manage Orders',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminOrdersPage()));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white, // Ensure high contrast for the icon
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AdminEditProductPage()));
        },
      ),
      body: productsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(defaultPadding),
              itemCount: productsState.products.length,
              itemBuilder: (context, index) {
                final Product p = productsState.products[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: smallPadding),
                  child: ListTile(
                    leading: SizedBox(
                        width: 50,
                        height: 50,
                        // Using CustomImage handles caching and placeholder logic automatically.
                        child: CustomImage(imageUrl: p.imageUrl)),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Stock: ${p.stock} | €${p.price}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        AdminEditProductPage(product: p)));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteProduct(p.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}