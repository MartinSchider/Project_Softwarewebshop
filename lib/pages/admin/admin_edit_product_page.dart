// lib/pages/admin/admin_edit_product_page.dart
import 'package:flutter/material.dart';
import 'package:webshop/models/product.dart';
import 'package:webshop/repositories/admin_repository.dart';
import 'package:webshop/utils/constants.dart';
import 'package:webshop/utils/ui_helper.dart';

/// A form screen for administrators to create or modify products.
///
/// This widget handles input validation, state management for form fields,
/// and communication with the [AdminRepository] to persist changes.
class AdminEditProductPage extends StatefulWidget {
  /// The product to edit.
  ///
  /// If [product] is `null`, the page operates in "Create Mode".
  /// If [product] is provided, the page operates in "Edit Mode" and pre-fills the fields.
  final Product? product;

  const AdminEditProductPage({super.key, this.product});

  @override
  State<AdminEditProductPage> createState() => _AdminEditProductPageState();
}

class _AdminEditProductPageState extends State<AdminEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final AdminRepository _repo = AdminRepository();
  
  // Controllers to manage the text state of input fields.
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _imageCtrl;
  
  // Default category if creating a new product.
  String _selectedCategory = 'General';

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    
    // Initialize controllers with existing data if editing, or empty strings if creating.
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    
    // Numeric fields must be converted to strings for the text controllers.
    _priceCtrl = TextEditingController(text: p?.price.toString() ?? '');
    _stockCtrl = TextEditingController(text: p?.stock.toString() ?? '');
    _imageCtrl = TextEditingController(text: p?.imageUrl ?? '');
    
    _selectedCategory = p?.category ?? 'General';
    
    // Safety check: If the loaded category is no longer in our supported list
    // (e.g., deprecated), fallback to 'General' to prevent dropdown crashes.
    if (!productCategories.contains(_selectedCategory)) {
      _selectedCategory = 'General';
    }
  }

  @override
  void dispose() {
    // Always dispose controllers to free up resources.
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  /// Validates the form and persists the product data to Firestore.
  Future<void> _save() async {
    // 1. Client-side validation (check for empty required fields, invalid numbers).
    if (!_formKey.currentState!.validate()) return;

    try {
      // 2. UX: Show a blocking loading dialog to prevent double submissions.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 3. Create the Product object from form data.
      final newProduct = Product(
        // If editing, keep the ID. If creating, use empty string (Repository will handle generation).
        id: widget.product?.id ?? '', 
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        stock: int.parse(_stockCtrl.text.trim()),
        // Use default placeholder if the image URL field is left empty.
        imageUrl: _imageCtrl.text.trim().isEmpty 
            ? defaultNoImageUrl 
            : _imageCtrl.text.trim(),
        category: _selectedCategory,
      );

      // 4. Perform the async save operation.
      await _repo.saveProduct(newProduct);
      
      // 5. Navigation & Feedback
      // Check mounted to ensure the widget is still on screen before using context.
      if (mounted) {
        Navigator.of(context).pop(); // Close the loading dialog
        Navigator.of(context).pop(); // Close the edit page, returning to Dashboard
        UiHelper.showSuccess(context, 'Product saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close the loading dialog even on error
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
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: productCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price (€)', suffixText: '€'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                // Ensure the input is a valid double.
                validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid number' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _stockCtrl,
                decoration: const InputDecoration(labelText: 'Stock Quantity'),
                keyboardType: TextInputType.number,
                // Ensure the input is a valid integer.
                validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid integer' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _imageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  helperText: 'Leave empty for default image', // Helper moved inside decoration
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

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