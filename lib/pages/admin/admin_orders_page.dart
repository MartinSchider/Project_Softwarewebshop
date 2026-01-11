// lib/pages/admin/admin_orders_page.dart
import 'package:flutter/material.dart';
import 'package:webshop/models/order.dart';
import 'package:webshop/pages/admin/admin_order_detail_page.dart';
import 'package:webshop/repositories/admin_repository.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/widgets/error_retry_widget.dart';

/// A management screen for viewing all customer orders.
///
/// This page provides a high-level overview of sales activity, allowing
/// administrators to:
/// 1. Monitor incoming orders in real-time.
/// 2. Quickly identify order status (Pending, Shipped, etc.) via color-coded chips.
/// 3. Navigate to specific order details for processing.
class AdminOrdersPage extends StatelessWidget {
  const AdminOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // We instantiate the repository directly here as this page is self-contained.
    // In a larger app, this might come from a provider to support testing.
    final AdminRepository adminRepo = AdminRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Orders')),
      body: StreamBuilder<List<Order>>(
        // Subscribe to the real-time stream of all orders.
        // This ensures the admin sees new orders immediately without refreshing.
        stream: adminRepo.getAllOrdersStream(),
        builder: (context, snapshot) {
          // --- Loading State ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- Error State ---
          if (snapshot.hasError) {
            return ErrorRetryWidget(
              errorMessage: snapshot.error.toString(),
              // Retry isn't strictly necessary for a StreamBuilder as it auto-reconnects,
              // but it provides a good UX for manual re-triggering if needed.
              onRetry: () {},
            );
          }

          final orders = snapshot.data ?? [];

          // --- Empty State ---
          if (orders.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          // --- Data List ---
          return ListView.builder(
            padding: const EdgeInsets.all(defaultPadding),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: ListTile(
                  title: Text('Order #${order.orderId}'),
                  subtitle: Text(
                    // Split timestamp to show only date and time (remove milliseconds) for readability.
                    '${order.timestamp.toLocal().toString().split('.')[0]}\n'
                    'Total: €${order.finalAmountPaid.toStringAsFixed(2)}',
                  ),
                  isThreeLine: true,
                  // Visual status indicator at a glance.
                  trailing: _buildStatusChip(order.status),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminOrderDetailPage(order: order),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Helper to create a color-coded status indicator.
  ///
  /// Using distinct colors helps admins quickly scan the list for actionable items
  /// (e.g., Orange for 'Pending' needs attention).
  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'shipped':
        color = Colors.blue;
        break;
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10)),
      backgroundColor: color,
    );
  }
}
