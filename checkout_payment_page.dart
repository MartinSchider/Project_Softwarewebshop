import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:webshop/order_confirmation_page.dart';

class CheckoutPaymentPage extends StatefulWidget {
  const CheckoutPaymentPage({super.key});

  @override
  State<CheckoutPaymentPage> createState() => _CheckoutPaymentPageState();
}

class _CheckoutPaymentPageState extends State<CheckoutPaymentPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _completeOrder,
                child: const Text('Completa Ordine'),
              ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Ok'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _completeOrder() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showErrorDialog('Authentication Error', 'You must be logged in to complete the order.');
      return;
    }

    final String? userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null || userEmail.isEmpty) {
      _showErrorDialog('Email Error', 'Could not retrieve user email address. Please ensure your account has an associated email.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('completeOrder');
      final result = await callable.call<Map<String, dynamic>>({
        'email': userEmail,
      });

      final data = result.data;
      if (data != null && data['orderId'] != null) {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => OrderConfirmationPage(
              orderId: data['orderId'],
              finalAmountPaid: data['finalAmountPaid'] ?? 0.0,
            ),
          ),
          (Route<dynamic> route) => false,
        );
      } else {
        _showErrorDialog('Order Error', 'Unexpected response from the order completion function.');
      }
    } on FirebaseFunctionsException catch (e) {
      _showErrorDialog('Cloud Function Error', '${e.message}');
    } catch (e) {
      _showErrorDialog('Generic Error', 'An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
