// lib/repositories/admin_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/product.dart';
// We use an alias 'app_model' to avoid potential naming conflicts if other
// libraries export a class named 'Order' (e.g., payment SDKs).
import 'package:webshop/models/order.dart' as app_model;

/// Handles data operations for administrative tasks.
///
/// This repository provides privileged access to the database, allowing
/// modifications to the product catalog and full visibility into all customer orders.
class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Product Management ---

  /// Saves a product to the Firestore 'products' collection.
  ///
  /// This method intelligently handles both creation and updates:
  /// * If [product.id] is empty, it treats it as a new item and lets Firestore generate a unique ID.
  /// * If [product.id] exists, it updates the existing document.
  Future<void> saveProduct(Product product) async {
    final collection = _firestore.collection('products');
    if (product.id.isEmpty) {
      // Create: Add new document
      await collection.add(product.toMap());
    } else {
      // Update: Modify existing document
      await collection.doc(product.id).update(product.toMap());
    }
  }

  /// Permanently deletes a product from the catalog.
  Future<void> deleteProduct(String productId) async {
    await _firestore.collection('products').doc(productId).delete();
  }

  // --- Order Management ---

  /// Returns a real-time stream of ALL orders from all users.
  ///
  /// The stream is sorted by timestamp (descending) to ensure the administrator
  /// sees the most recent orders at the top of the list for quick processing.
  Stream<List<app_model.Order>> getAllOrdersStream() {
    return _firestore
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => app_model.Order.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Updates the workflow status of a specific order.
  ///
  /// * [orderId]: The unique document ID of the order.
  /// * [newStatus]: The new status string (e.g., 'shipped', 'delivered', 'cancelled').
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
    });
  }
}
