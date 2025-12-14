// lib/pages/admin/admin_order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:webshop/models/order.dart';
import 'package:webshop/repositories/admin_repository.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/utils/ui_helper.dart';

/// A comprehensive view of a specific order for administrators.
///
/// This page allows admins to:
/// 1. View customer shipping details and purchased items.
/// 2. See the financial breakdown.
/// 3. Update the lifecycle status of the order (e.g., mark as Shipped).
class AdminOrderDetailPage extends StatefulWidget {
  final Order order;

  const AdminOrderDetailPage({super.key, required this.order});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  final AdminRepository _repo = AdminRepository();
  late String _currentStatus;

  // The allowed lifecycle states for an order.
  final List<String> _statusOptions = ['pending', 'processing', 'shipped', 'delivered', 'cancelled'];

  @override
  void initState() {
    super.initState();
    // Initialize local state with the order's existing status.
    _currentStatus = widget.order.status;
  }

  /// Updates the order status in the backend.
  Future<void> _updateStatus(String? newStatus) async {
    // Avoid unnecessary network calls if the status hasn't actually changed.
    if (newStatus == null || newStatus == _currentStatus) return;

    try {
      // Show a blocking loader to prevent interactions while writing to Firestore.
      UiHelper.showLoading(context);
      await _repo.updateOrderStatus(widget.order.id, newStatus);
      
      // Check mounted to ensure the widget is still in the tree before using context.
      if (mounted) {
        Navigator.pop(context); // Dismiss the loading dialog.
        setState(() => _currentStatus = newStatus); // Update local UI state.
        UiHelper.showSuccess(context, 'Status updated to $newStatus');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog on error.
        UiHelper.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final address = order.shippingAddress;

    return Scaffold(
      appBar: AppBar(title: Text('Order #${order.orderId}')),
      // SingleChildScrollView ensures the content is accessible on smaller screens
      // or when the item list is long.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- STATUS MANAGEMENT ---
            // Card visual separation emphasizes the administrative action area.
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _statusOptions.contains(_currentStatus) ? _currentStatus : _statusOptions.first,
                        isExpanded: true,
                        items: _statusOptions.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.toUpperCase()),
                        )).toList(),
                        onChanged: _updateStatus,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- CUSTOMER INFO ---
            const Text('Shipping Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Use collection-if to conditionally render address lines or fallback text.
            if (address != null) ...[
              Text('${address['name']} ${address['surname']}'),
              Text(address['address']),
              Text('${address['city']}, ${address['postcode']}'),
            ] else 
              const Text('No address provided'),
            
            const Divider(height: 32),

            // --- ITEMS ---
            const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            // We use shrinkWrap: true and NeverScrollableScrollPhysics because
            // this list is nested inside a SingleChildScrollView.
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.items.length,
              itemBuilder: (ctx, i) {
                final item = order.items[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.product.name),
                  subtitle: Text('Qty: ${item.quantity}'),
                  // We calculate the line total (price * qty) for immediate visibility.
                  trailing: Text('€${(item.product.price * item.quantity).toStringAsFixed(2)}'),
                );
              },
            ),
            const Divider(),
            
            // --- TOTAL ---
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: €${order.finalAmountPaid.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}