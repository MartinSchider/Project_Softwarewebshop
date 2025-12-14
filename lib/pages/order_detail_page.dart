// lib/pages/order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:webshop/models/order.dart' as app_model;
import 'package:webshop/utils/constants.dart';
import 'package:webshop/widgets/custom_image.dart';

/// A read-only screen that displays the full details of a completed order.
///
/// This includes the status, purchased items, shipping address, and final
/// price breakdown. It is reached from the "My Orders" list.
class OrderDetailPage extends StatelessWidget {
  final app_model.Order order;

  const OrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER (Status & ID) ---
            _buildOrderHeader(context),
            const Divider(height: 32),

            // --- ITEMS LIST ---
            const Text(
              'Items Purchased',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: smallPadding),
            
            // We use ListView.builder with shrinkWrap because this list is nested 
            // inside a SingleChildScrollView (Column). Without shrinkWrap, 
            // the ListView would try to expand infinitely, causing a layout error.
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: order.items.length,
              itemBuilder: (context, index) {
                final item = order.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      // Product Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomImage(
                          imageUrl: item.product.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Product Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.quantity} x €${item.product.price.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      
                      // Line Total
                      Text(
                        '€${(item.quantity * item.product.price).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 32),

            // --- PAYMENT METHOD ---
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: smallPadding),
            const Row(
              children: [
                Icon(Icons.credit_card, color: Colors.grey),
                SizedBox(width: 12),
                Text('Credit Card (Simulated)', style: TextStyle(fontSize: 16)),
                Spacer(),
                Icon(Icons.check_circle, color: successColor, size: 20),
              ],
            ),
            const Divider(height: 32),

            // --- SUMMARY TOTALS ---
            Container(
              padding: const EdgeInsets.all(defaultPadding),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', order.totalPrice),
                  if (order.giftCardAppliedAmount > 0)
                    _buildSummaryRow('Discount', -order.giftCardAppliedAmount, color: successColor),
                  const Divider(),
                  _buildSummaryRow('Total Paid', order.finalAmountPaid, isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the top section showing Order ID, Date, and Status chip.
  Widget _buildOrderHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Order #${order.orderId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _buildStatusChip(order.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          // Split timestamp to remove milliseconds for cleaner display.
          'Placed on: ${order.timestamp.toLocal().toString().split('.')[0]}',
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
      ],
    );
  }

  /// Helper to build a price row in the summary section.
  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 16,
          )),
          Text(
            '€${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 16,
              color: color ?? (isTotal ? Colors.teal : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  /// Creates a visual badge for the order status.
  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending': color = Colors.orange; break;
      case 'shipped':
      case 'completed': color = successColor; break;
      case 'cancelled': color = errorColor; break;
      default: color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}