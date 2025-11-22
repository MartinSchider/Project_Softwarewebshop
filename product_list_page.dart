import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/auth_page.dart';
import 'package:webshop/product_detail_page.dart';
import 'package:webshop/cart_page.dart';
import 'package:webshop/ai_chatbot.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showChatbot(context);
        },
        tooltip: 'AI Shopping Assistant',
        icon: const Icon(Icons.smart_toy),
        label: const Text('AI Chat'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showChatbot(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chatbot',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.4,
              height: MediaQuery.of(context).size.height,
              child: const ChatbotWidget(),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
    );
  }
}

// Helper class to represent product data for the chatbot
class _ProductData {
  final String name;
  final double price;
  final int stock;

  _ProductData({
    required this.name,
    required this.price,
    required this.stock,
  });
}

class ChatbotWidget extends StatefulWidget {
  const ChatbotWidget({super.key});

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'sender': 'bot',
      'text': 'Hello! I\'m your shop assistant. I can help you with product prices, availability, and recommendations. What would you like to know?'
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });

    _messageController.clear();

    try {
      // Fetch all products from Firestore
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      
      if (snapshot.docs.isEmpty) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': 'Sorry, no products are available in the database.'});
          _isLoading = false;
        });
        return;
      }

      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        // Create a dynamic object with accessible properties
        return _ProductData(
          name: data['productName']?.toString() ?? 'Unknown',
          price: (data['productPrice'] is num) ? (data['productPrice'] as num).toDouble() : 0.0,
          stock: (data['productStock'] is num) ? (data['productStock'] as num).toInt() : 0,
        );
      }).toList();

      // Get AI response
      final response = await AIChatBot.respond(text, products);

      setState(() {
        _messages.add({'sender': 'bot', 'text': response});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': 'Sorry, I encountered an error: $e'});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.white),
                const SizedBox(width: 12),
                const Text(
                  'AI Shopping Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.smart_toy, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('Typing...', style: TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  );
                }

                final message = _messages[index];
                final isUser = message['sender'] == 'user';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.smart_toy, size: 20),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? Theme.of(context).primaryColor : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message['text']!,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 12),
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(Icons.person, size: 20, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask about products...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).primaryColor,
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
