import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/product_detail_page.dart';
import 'package:webshop/cart_page.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text != _currentSearchQuery) {
        setState(() {
          _currentSearchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getProductStream() {
    Query productsQuery = FirebaseFirestore.instance.collection('products');

    if (_currentSearchQuery.isEmpty) {
      return productsQuery.snapshots();
    } else {
      return productsQuery
          .orderBy('productName')
          .startAt([_currentSearchQuery])
          .endAt([_currentSearchQuery + '\uf8ff'])
          .snapshots();
    }
  }

  Future<void> addProductToCart(String productId, Map<String, dynamic> productData) async {
    final user = _auth.currentUser;
    if (user == null) {
      print("Error: addProductToCart called without authenticated user.");
      return;
    }

    try {
      final cartRef = FirebaseFirestore.instance.collection('carts').doc(user.uid);
      final itemRef = cartRef.collection('items').doc(productId);

      await cartRef.set({'ownerUID': user.uid}, SetOptions(merge: true));

      final String productName = (productData['productName'] is String) ? productData['productName'] : 'Unknown Name';
      final double productPrice = (productData['productPrice'] is num) ? productData['productPrice'].toDouble() : 0.0;
      final String imageUrl = (productData['imageUrl'] is String) ? productData['imageUrl'] : '';

      await itemRef.set({
        'productId': productId,
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
      print('Error addProductToCart: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (value) {
                },
              )
            : const Text('Products'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close Search' : 'Search Products',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _currentSearchQuery = '';
                }
              });
            },
          ),
          if (user != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('carts').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                int itemCount = 0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final cartData = snapshot.data!.data() as Map<String, dynamic>;
                  itemCount = (cartData['itemCount'] is int) ? cartData['itemCount'] : 0;
                }

                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart),
                      tooltip: 'Cart',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const CartPage()),
                        );
                      },
                    ),
                    if (itemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red, // Colore del badge
                            borderRadius: BorderRadius.circular(10), // Forma arrotondata
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$itemCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                  ],
                );
              },
            ),
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                await _auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const ProductListPage()),
                  );
                }
              },
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AuthPage()),
                );
              },
              child: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getProductStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text(_currentSearchQuery.isEmpty ? 'No products available.' : 'No products found for "${_currentSearchQuery}".'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 0.7,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final product = snapshot.data!.docs[index];
              final productId = product.id;
              final productData = product.data() as Map<String, dynamic>;

              final String productName = (productData['productName'] is String) ? productData['productName'] : 'Unknown Name';
              final String productDescription = (productData['productDescription'] is String) ? productData['productDescription'] : 'No description available.';
              final double productPrice = (productData['productPrice'] is num) ? productData['productPrice'].toDouble() : 0.0;
              final String imageUrl = (productData['imageUrl'] is String) ? productData['imageUrl'] : '';

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(
                        productId: productId,
                        productData: {
                          'productName': productName,
                          'productDescription': productDescription,
                          'productPrice': productPrice,
                          'imageUrl': imageUrl,
                        },
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    width: double.infinity,
                                    child: const Icon(Icons.image, size: 60, color: Colors.grey),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        Text(
                          productDescription,
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Price: €${productPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (user != null) {
                                addProductToCart(productId, productData);
                              } else {
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
            },
          );
        },
      ),
    );
  }
}
