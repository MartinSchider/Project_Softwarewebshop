// lib/pages/admin/admin_edit_product_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/admin_repository.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/utils/ui_helper.dart';

/// A screen that provides a form for administrators to create or edit products.
///
/// This widget handles:
/// * **State Management**: Using [TextEditingController]s for input fields.
/// * **Validation**: Ensuring required fields (name, price, stock) are valid.
/// * **Business Logic**: Calculating the final price based on the discount percentage.
/// * **Persistence**: communicating with [AdminRepository] to save data to Firestore.
class AdminEditProductPage extends StatefulWidget {
  /// The product object to be edited.
  ///
  /// * If `null`, the screen operates in **Create Mode** (empty fields).
  /// * If provided, the screen operates in **Edit Mode** (pre-filled fields).
  final Product? product;

  const AdminEditProductPage({super.key, this.product});

  @override
  State<AdminEditProductPage> createState() => _AdminEditProductPageState();
}

class _AdminEditProductPageState extends State<AdminEditProductPage> {
  // GlobalKey to identify the form and trigger validation.
  final _formKey = GlobalKey<FormState>();
  
  // Repository to handle database operations.
  final AdminRepository _repo = AdminRepository();

  // --- CONTROLLERS ---
  // Controllers bind the UI TextFormFields to the logic variables.
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  
  // Represents the 'originalPrice' (base price before discount).
  late TextEditingController _priceCtrl; 
  
  late TextEditingController _discountCtrl; 
  late TextEditingController _stockCtrl;
  late TextEditingController _imageCtrl;
  
  // Controller for the estimated delivery time (in days).
  late TextEditingController _deliveryCtrl; 

  // Dropdown selection state.
  String _selectedCategory = 'General';

  /// Initializes the form state.
  ///
  /// If a [product] was passed to the widget, this method pre-fills the
  /// controllers with the existing data. Otherwise, it sets default values.
  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    
    // Pre-fill price. Prioritize originalPrice, fallback to current price.
    _priceCtrl = TextEditingController(
        text: p?.originalPrice.toString() ?? p?.price.toString() ?? '');
    
    _discountCtrl = TextEditingController(
        text: p?.discountPercentage.toString() ?? '0');
    _stockCtrl = TextEditingController(text: p?.stock.toString() ?? '');
    _imageCtrl = TextEditingController(text: p?.imageUrl ?? '');
    
    // Initialize delivery days (Default to 3 if new or missing).
    _deliveryCtrl = TextEditingController(text: p?.deliveryDays.toString() ?? '3');

    // Category logic: Ensure selected category exists in the global list.
    _selectedCategory = p?.category ?? 'General';
    if (!productCategories.contains(_selectedCategory)) {
      _selectedCategory = 'General';
    }
  }

  /// Cleans up controllers to free resources when the widget is removed.
  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _stockCtrl.dispose();
    _imageCtrl.dispose();
    _deliveryCtrl.dispose(); 
    super.dispose();
  }

  /// Validates inputs and saves the product to the database.
  ///
  /// 1. Trigger form validation.
  /// 2. Parse string inputs to numerical types.
  /// 3. Apply discount logic: `finalPrice = originalPrice - (originalPrice * discount%)`.
  /// 4. Create [Product] object.
  /// 5. Call repository.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Show blocking loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final double originalPrice = double.parse(_priceCtrl.text.trim());
      final int discountPercent = int.parse(_discountCtrl.text.trim());

      // --- PRICE CALCULATION LOGIC ---
      double finalPrice = originalPrice;
      if (discountPercent > 0) {
        finalPrice = originalPrice - (originalPrice * (discountPercent / 100));
      }

      // Create updated product instance
      final newProduct = Product(
        id: widget.product?.id ?? '', // Keeps ID if editing, empty if creating
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: finalPrice, 
        originalPrice: originalPrice,
        discountPercentage: discountPercent,
        stock: int.parse(_stockCtrl.text.trim()),
        imageUrl: _imageCtrl.text.trim().isEmpty
            ? defaultNoImageUrl
            : _imageCtrl.text.trim(),
        category: _selectedCategory,
        // Save delivery estimate
        deliveryDays: int.parse(_deliveryCtrl.text.trim()),
      );

      // Persist to Firestore
      await _repo.saveProduct(newProduct);

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        Navigator.of(context).pop(); // Close the Edit Page
        UiHelper.showSuccess(context, 'Product saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        UiHelper.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Product' : 'New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Product Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              // Category Selector
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: productCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              
              const SizedBox(height: 16),
              
              // --- PRICING ROW ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Base Price (€)', 
                          suffixText: '€',
                          helperText: 'Original price'
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _discountCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Discount %', 
                          suffixText: '%',
                          helperText: '0-99'
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) return '0 if none';
                        final val = int.tryParse(v);
                        if (val == null || val < 0 || val >= 100) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // --- INVENTORY & LOGISTICS ROW ---
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockCtrl,
                      decoration: const InputDecoration(labelText: 'Stock Qty'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _deliveryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Days',
                        suffixText: 'days',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              
              // Image URL
              TextFormField(
                controller: _imageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  helperText: 'Leave empty for default image',
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}