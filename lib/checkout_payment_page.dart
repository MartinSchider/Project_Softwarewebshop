// lib/checkout_payment_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webshop/order_confirmation_page.dart';
import 'package:webshop/services/order_service.dart';
import 'package:webshop/services/auth_service.dart';
import 'package:webshop/services/cart_service.dart';
import 'package:webshop/models/cart_item.dart';
import 'package:webshop/providers/cart_providers.dart';
import 'package:webshop/utils/constants.dart';

/// The final step of the checkout process.
///
/// This screen allows the user to:
/// 1. Review their order items and financial breakdown.
/// 2. Apply or remove Gift Cards.
/// 3. Confirm the payment method (simulated).
/// 4. Finalize the order, which triggers server-side processing and local updates.
class CheckoutPaymentPage extends ConsumerStatefulWidget {
  const CheckoutPaymentPage({super.key});

  @override
  ConsumerState<CheckoutPaymentPage> createState() =>
      _CheckoutPaymentPageState();
}

class _CheckoutPaymentPageState extends ConsumerState<CheckoutPaymentPage> {
  // Services for business logic execution
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();

  // Controller for the gift card input field
  final TextEditingController _giftCardController = TextEditingController();

  // Local state to show a loading spinner during async network operations
  bool _isLoading = false;

  // Holds the currently applied gift card code to conditionally update the UI
  String? _appliedGiftCardCode;

  @override
  void dispose() {
    _giftCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers to get real-time updates on cart details (price, discount) and item list.
    // This ensures the summary is always accurate even if backend data changes.
    final cartDetailsAsync = ref.watch(cartDetailsProvider);
    final cartItemsAsync = ref.watch(cartItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartDetailsAsync.when(
              // Show loading state while fetching cart metadata
              loading: () => const Center(child: CircularProgressIndicator()),
              
              // Handle errors during fetch
              error: (err, stack) =>
                  Center(child: Text('Error loading cart details: $err')),
              
              // Render the payment content when data is available
              data: (cartDetails) =>
                  _buildPaymentContent(cartDetails, cartItemsAsync),
            ),
    );
  }

  /// Builds the main content scroll view for the payment page.
  Widget _buildPaymentContent(
      Map<String, dynamic> cartDetails, AsyncValue cartItemsAsync) {
    // Extract financial data safely
    final double totalPrice =
        (cartDetails['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final double giftCardAppliedAmount =
        (cartDetails['giftCardAppliedAmount'] as num?)?.toDouble() ?? 0.0;
    final double finalAmountToPay =
        (cartDetails['finalAmountToPay'] as num?)?.toDouble() ?? 0.0;
    
    // Update local variable for UI logic
    _appliedGiftCardCode = cartDetails['appliedGiftCardCode'] as String?;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummaryHeader(),
                const SizedBox(height: defaultPadding),
                
                // 1. List of items being purchased
                _buildCartItemsList(cartItemsAsync),
                
                const SizedBox(height: 24),
                
                // 2. Financial Breakdown (Subtotal, Discount, Total)
                _buildFinancialBreakdown(
                    totalPrice, giftCardAppliedAmount, finalAmountToPay),
                
                const SizedBox(height: 24),
                
                // 3. Gift Card Management Section
                _buildGiftCardSection(),
                
                const SizedBox(height: 24),
                
                // 4. Payment Method Selection (Static for this demo)
                _buildPaymentMethodSection(),
              ],
            ),
          ),
        ),
        
        // 5. "Complete Order" Action Button (Pinned to bottom)
        _buildActionButton(finalAmountToPay),
      ],
    );
  }

  /// Builds the "Order Summary" text header.
  Widget _buildOrderSummaryHeader() {
    return const Text(
      orderSummaryTitle,
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    );
  }

  /// Builds the list of cart item cards.
  ///
  /// Handles the AsyncValue state of the items provider separately.
  Widget _buildCartItemsList(AsyncValue cartItemsAsync) {
    return cartItemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error loading cart items: $err')),
      data: (cartItems) {
        if (cartItems.isEmpty) {
          return const Text('Your cart is empty.');
        }
        return Column(
          children: cartItems.map((item) => _buildCartItemCard(item)).toList(),
        );
      },
    );
  }

  /// Builds an individual card representing a cart item.
  Widget _buildCartItemCard(CartItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: smallPadding),
      child: Padding(
        padding: const EdgeInsets.all(smallPadding),
        child: Row(
          children: [
            // Product Thumbnail
            Image.network(
              item.product.imageUrl,
              width: 50,
              height: 50,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
            ),
            const SizedBox(width: smallPadding),
            
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Quantity: ${item.quantity}'),
                  Text('Price: €${item.product.price.toStringAsFixed(2)}'),
                ],
              ),
            ),
            
            // Item Total Price
            Text('€${(item.product.price * item.quantity).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// Builds the section displaying Subtotal, Discounts, and Final Total.
  Widget _buildFinancialBreakdown(double totalPrice,
      double giftCardAppliedAmount, double finalAmountToPay) {
    return Column(
      children: [
        _buildPriceRow('Subtotal:', totalPrice),
        if (giftCardAppliedAmount > 0)
          _buildPriceRow('Discount (Gift Card):', -giftCardAppliedAmount,
              color: successColor),
        const Divider(),
        _buildPriceRow('Total to Pay:', finalAmountToPay, isTotal: true),
      ],
    );
  }

  /// Builds the Gift Card input or applied status section.
  Widget _buildGiftCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          giftCardTitle,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: smallPadding),
        
        // Conditional rendering: Show input field OR remove button
        if (_appliedGiftCardCode != null && _appliedGiftCardCode!.isNotEmpty)
          _buildAppliedGiftCardRow()
        else
          _buildGiftCardInputRow(),
      ],
    );
  }

  /// Displays the currently applied gift card code and a remove button.
  Widget _buildAppliedGiftCardRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Gift Card Applied: $_appliedGiftCardCode',
            style: const TextStyle(fontSize: 16, color: successColor),
          ),
        ),
        TextButton(
          onPressed: _removeGiftCard,
          child: const Text('Remove'),
        ),
      ],
    );
  }

  /// Displays the text field and button to apply a new gift card.
  Widget _buildGiftCardInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _giftCardController,
            decoration: const InputDecoration(
              labelText: 'Gift Card Code',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: smallPadding),
        ElevatedButton(
          onPressed: _applyGiftCard,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  /// Builds the section showing the selected payment method.
  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          paymentMethodTitle,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: smallPadding),
        const Card(
          child: ListTile(
            leading: Icon(Icons.credit_card),
            title: Text('Credit/Debit Card (Simulated)'),
            trailing: Icon(Icons.check_circle_outline, color: successColor),
          ),
        ),
      ],
    );
  }

  /// Builds the main action button ("Complete Order").
  Widget _buildActionButton(double finalAmountToPay) {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: ElevatedButton(
        // Disable button if calculations are invalid (negative total)
        onPressed: finalAmountToPay >= 0 ? _completeOrder : null,
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        child: Text(
          finalAmountToPay > 0
              ? 'Complete Order (€${finalAmountToPay.toStringAsFixed(2)})'
              : 'Complete Order (No Cost)',
        ),
      ),
    );
  }

  /// Helper widget to render consistent rows for price breakdown.
  Widget _buildPriceRow(String label, double amount,
      {Color? color, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '€${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isTotal ? Theme.of(context).primaryColor : null),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER METHODS FOR DIALOGS AND SNACKBARS ---

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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : successColor,
        duration: snackbarDuration,
      ),
    );
  }

  // --- BUSINESS LOGIC METHODS ---

  /// Attempts to apply a gift card using the CartService.
  Future<void> _applyGiftCard() async {
    final giftCardCode = _giftCardController.text.trim();
    if (giftCardCode.isEmpty) {
      _showSnackBar('Please enter a gift card code.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final CartService cartService = ref.read(cartServiceProvider);
      await cartService.applyGiftCard(giftCardCode);

      _showSnackBar('Gift card applied successfully!');
      _giftCardController.clear();
    } catch (e) {
      _showErrorDialog('Gift Card Error', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Removes the currently applied gift card using the CartService.
  Future<void> _removeGiftCard() async {
    setState(() => _isLoading = true);

    try {
      final CartService cartService = ref.read(cartServiceProvider);
      await cartService.removeGiftCard();

      _showSnackBar('Gift card removed successfully!');
    } catch (e) {
      _showErrorDialog('Gift Card Error', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Finalizes the order process.
  /// 
  /// 1. Retrieves user email.
  /// 2. Fetches current cart subtotal for fidelity points calculation.
  /// 3. Calls the OrderService to process the transaction.
  /// 4. Navigates to the Confirmation Page on success.
  Future<void> _completeOrder() async {
    final userEmail = _authService.currentUser?.email;

    if (userEmail == null || userEmail.isEmpty) {
      _showErrorDialog('Email Error',
          'Could not retrieve user email address. Please ensure your account has an associated email.');
      return;
    }

    // 1. Retrieve the cart total (Subtotal) to calculate fidelity points correctly
    final cartState = ref.read(cartDetailsProvider);
    // 'subtotal' comes from the logic in cart_providers.dart, representing the raw cart value
    final double subtotal =
        (cartState.value?['subtotal'] as num?)?.toDouble() ?? 0.0;

    setState(() => _isLoading = true);

    try {
      // 2. Pass the subtotal to the completeOrder method service
      final result = await _orderService.completeOrder(userEmail, subtotal);

      final data = result as Map<String, dynamic>?;

      if (data != null && data['orderId'] != null) {
        if (mounted) {
          // Navigate to Success Page on successful order
          await Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => OrderConfirmationPage(
                orderId: data['orderId'].toString(),
                finalAmountPaid:
                    (data['finalAmountPaid'] as num?)?.toDouble() ?? 0.0,
              ),
            ),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        _showErrorDialog('Order Error',
            'Unexpected response from the order completion service.');
      }
    } catch (e) {
      _showErrorDialog('Error Completing Order', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}