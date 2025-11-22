import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/auth_page.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductDetailPage({
    Key? key,
    required this.productId,
    required this.productData,
  }) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // This function adds the product to the cart
  Future<void> addProductToCart() async {
    final user = _auth.currentUser;
    if (user == null) {
    print("Error: addProductToCart called without authenticated user.");
      return;
    }

    try {
      final cartRef = _firestore.collection('carts').doc(user.uid);
      final itemRef = cartRef.collection('items').doc(widget.productId);

      // Ensure the cart document exists and has the ownerUID (security rule requires it)
      await cartRef.set({'ownerUID': user.uid}, SetOptions(merge: true));

      final String productName = (widget.productData['productName'] is String) ? widget.productData['productName'] : 'Unknown Name';
      final double productPrice = (widget.productData['productPrice'] is num) ? widget.productData['productPrice'].toDouble() : 0.0;
      final String imageUrl = (widget.productData['imageUrl'] is String) ? widget.productData['imageUrl'] : '';

      await itemRef.set({
        'productId': widget.productId,
        'productName': productName,
        'productPrice': productPrice,
        'imageUrl': imageUrl,
        'quantity': FieldValue.increment(1),
        'addedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${productName}" added to cart!'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding product to cart: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      print('Error addProductToCart from detail page: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser; // Get the current user
    final String productName = (widget.productData['productName'] is String) ? widget.productData['productName'] : 'Unknown Name';
    final String productDescription = (widget.productData['productDescription'] is String) ? widget.productData['productDescription'] : 'No description available.';
    final double productPrice = (widget.productData['productPrice'] is num) ? widget.productData['productPrice'].toDouble() : 0.0;
    final String imageUrl = (widget.productData['imageUrl'] is String) ? widget.productData['imageUrl'] : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(productName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                Center(
                  child: Image.network(
                    imageUrl,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
                  ),
                )
              else
                Center(
                  child: Icon(Icons.image_not_supported, size: 100, color: Colors.grey[400]),
                ),
              const SizedBox(height: 20),

              Text(
                productName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.black),
              ),
              const SizedBox(height: 10),

              Text(
                productDescription,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[800]),
              ),
              const SizedBox(height: 10),

              Text(
                'Price: €${productPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (user != null) {
                      // Logged-in user: add directly to cart
                      addProductToCart();
                    } else {
                      // NOT logged-in user: show login dialog
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Access required'),
                            content: const Text('You must log in to add products to the cart.'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              ElevatedButton(
                                child: const Text('Login / Sign Up'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const AuthPage()),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  child: const Text('Add to Cart'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
