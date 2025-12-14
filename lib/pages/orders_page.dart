// lib/pages/orders_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:webshop/models/order.dart' as app_model;
import 'package:webshop/pages/order_detail_page.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/widgets/error_retry_widget.dart';

/// A screen that displays the purchase history for the current logged-in user.
///
/// This widget connects directly to Firestore to provide real-time updates
/// on order statuses (e.g., if an admin marks an order as "Shipped", it updates here immediately).
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: const Center(child: Text('Please log in to view orders.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot>(
        // Query Logic:
        // 1. Filter by 'userId' to ensure data privacy (users see only their own orders).
        // 2. Sort by 'timestamp' descending so the most recent purchases appear at the top.
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return ErrorRetryWidget(
              errorMessage: 'Error loading orders: ${snapshot.error}',
              onRetry: () {}, 
            );
          }

          // 3. Empty State
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No orders placed yet.', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // 4. Data List
          return ListView.builder(
            padding: const EdgeInsets.all(defaultPadding),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              // Transform the raw Firestore document into our strongly-typed Order model.
              final order = app_model.Order.fromMap(data, docs[index].id);

              return Card(
                margin: const EdgeInsets.only(bottom: smallPadding),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(mediumPadding),
                  // Leading icon to quickly identify the list item type.
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
                  ),
                  // Title: Order Number
                  title: Text(
                    'Order #${order.orderId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Subtitle: Date and Total Amount
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // Simple date formatting (removing milliseconds for cleaner UI).
                          order.timestamp.toLocal().toString().split('.')[0],
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total: €${order.finalAmountPaid.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: Colors.black87
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trailing arrow to indicate navigability.
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    // Navigate to the detailed view of this specific order.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailPage(order: order),
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
}