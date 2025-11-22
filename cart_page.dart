import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/checkout_shipping_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // Function to update the quantity of an item in the cart
  Future<void> updateCartItemQuantity(String itemId, int change) async {
    if (currentUser == null) return;

    final itemRef = _firestore.collection('carts').doc(currentUser!.uid).collection('items').doc(itemId);

    final currentItemSnapshot = await itemRef.get();
    final currentQuantity = (currentItemSnapshot.data()?['quantity'] is int) ? currentItemSnapshot.data()!['quantity'] : 0;

    if (currentQuantity + change <= 0) {
      await removeCartItem(itemId);
    } else {
      await itemRef.update({
        'quantity': FieldValue.increment(change),
      });
    }
  }

  // Function to remove an item from the cart
  Future<void> removeCartItem(String itemId) async {
    if (currentUser == null) return;

    final itemRef = _firestore.collection('carts').doc(currentUser!.uid).collection('items').doc(itemId);
    await itemRef.delete();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: const Center(child: Text('You must be logged in to view your cart.')),
      );
    }

    final String userId = currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
      ),
      body: Column(
        children: [
          // Section to display cart items
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('carts').doc(userId).collection('items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Your cart is empty.'));
                }

                final cartItems = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final itemDoc = cartItems[index];
                    final itemId = itemDoc.id;
                    final itemData = itemDoc.data() as Map<String, dynamic>;

                    final String productName = (itemData['productName'] is String) ? itemData['productName'] : 'Unknown Name';
                    final double productPrice = (itemData['productPrice'] is num) ? itemData['productPrice'].toDouble() : 0.0;
                    final int quantity = (itemData['quantity'] is int) ? itemData['quantity'] : 1;
                    final String imageUrl = (itemData['imageUrl'] is String) ? itemData['imageUrl'] : '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            // Product Image
                            if (imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4.0),
                                child: Image.network(
                                  imageUrl,
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                ),
                              )
                            else
                              Container(
                                height: 60,
                                width: 60,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, size: 40, color: Colors.grey),
                              ),
                            const SizedBox(width: 12),

                            // Product Details and Quantity Controls
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text('€${productPrice.toStringAsFixed(2)} x $quantity = €${(productPrice * quantity).toStringAsFixed(2)}'),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: quantity > 1
                                            ? () => updateCartItemQuantity(itemId, -1)
                                            : () => removeCartItem(itemId),
                                      ),
                                      Text('$quantity'),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () => updateCartItemQuantity(itemId, 1),
                                      ),
                                      // Remove Button
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => removeCartItem(itemId),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Cart Total and Checkout Section
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('carts').doc(userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Cart error: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Calculating total...'),
                );
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }

              final cartData = snapshot.data!.data() as Map<String, dynamic>;
              final double totalPrice = (cartData['totalPrice'] is num) ? cartData['totalPrice'].toDouble() : 0.0;
              final int itemCount = (cartData['itemCount'] is int) ? cartData['itemCount'] : 0;
              final double giftCardAppliedAmount = (cartData['giftCardAppliedAmount'] is num) ? cartData['giftCardAppliedAmount'].toDouble() : 0.0;
              final double finalAmountToPay = (cartData['finalAmountToPay'] is num) ? cartData['finalAmountToPay'].toDouble() : totalPrice;


              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal (${itemCount} items):',
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '€${totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (giftCardAppliedAmount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gift Card Discount:',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green[700],
                            ),
                          ),
                          Text(
                            '-€${giftCardAppliedAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total to Pay:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '€${finalAmountToPay.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: itemCount > 0 ? () { // Disable button if cart is empty
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const CheckoutShippingPage()),
                          );
                        } : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Proceed to Order',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
