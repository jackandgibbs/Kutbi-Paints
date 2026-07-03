import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../models/product_model.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AddProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '100');
  final _lowStockCtrl = TextEditingController(text: '10');
  final _imageUrlCtrl = TextEditingController();

  // Dynamic size entries: each entry has a size value controller and a price controller
  final List<TextEditingController> _sizeValueCtrls = [];
  final List<TextEditingController> _sizePriceCtrls = [];

  final _customCategoryCtrl = TextEditingController();
  final _customSubCategoryCtrl = TextEditingController();
  final _customBrandCtrl = TextEditingController();

  // Built-in brands that always appear in the dropdown.
  static const List<String> _baseBrands = ['Asian Paints', 'Berger', 'Birla Opus', 'Tools'];

  String _brand = 'Asian Paints';
  String _category = 'ADD_NEW';
  String _subCategory = 'ADD_NEW';
  String _unit = 'L';
  bool _isCustomBrand = false;
  bool _isCustomCategory = true;
  bool _isCustomSubCategory = true;

  bool _isEdit = false;
  File? _pickedImage;
  bool _isSaving = false;
  final _minQtyCtrl = TextEditingController(text: '1');
  bool _hasColorShade = true;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _loadProduct();
    } else {
      // Default: 2 empty size entries
      _addSizeEntry('1');
      _addSizeEntry('4');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateCategoriesForBrand(_brand);
      });
    }
  }

  void _addSizeEntry([String value = '', String price = '']) {
    setState(() {
      _sizeValueCtrls.add(TextEditingController(text: value));
      _sizePriceCtrls.add(TextEditingController(text: price));
    });
  }

  void _removeSizeEntry(int index) {
    if (_sizeValueCtrls.length > 1) {
      setState(() {
        _sizeValueCtrls[index].dispose();
        _sizePriceCtrls[index].dispose();
        _sizeValueCtrls.removeAt(index);
        _sizePriceCtrls.removeAt(index);
      });
    }
  }

  /// Parse a bucket size string like "10L" or "500ML" into its numeric value
  String _parseSizeValue(String sizeStr) {
    return sizeStr.replaceAll(RegExp(r'[A-Za-z]+$'), '');
  }

  void _updateCategoriesForBrand(String brand) {
    if (!mounted) return;
    final ds = ref.read(dataServiceProvider);
    final cats = ds.getCategoriesForBrand(brand).where((c) => c != 'None' && c.isNotEmpty).toList();
    setState(() {
      if (cats.isNotEmpty) {
        _category = cats.first;
        _isCustomCategory = false;
        final subCats = ds.getProductsGroupedBySubCategory(brand, _category).keys.where((s) => s != 'None' && s.isNotEmpty).toList();
        if (subCats.isNotEmpty) {
          _subCategory = subCats.first;
          _isCustomSubCategory = false;
        } else {
          _subCategory = 'ADD_NEW';
          _isCustomSubCategory = true;
        }
      } else {
        _category = 'ADD_NEW';
        _isCustomCategory = true;
        _subCategory = 'ADD_NEW';
        _isCustomSubCategory = true;
      }
    });
  }


  void _loadProduct() {
    final ds = ref.read(dataServiceProvider);
    final p = ds.getAllProducts().firstWhere(
        (p) => p.id == widget.productId,
        orElse: () => throw Exception('Not found'));
    _isEdit = true;
    _nameCtrl.text = p.name;
    _brand = p.brand;
    _descCtrl.text = p.description ?? '';
    _category = p.category;
    _subCategory = p.subCategory;

    // Check if brand is a custom (non built-in) brand
    if (!_baseBrands.contains(_brand)) {
      _isCustomBrand = true;
      _customBrandCtrl.text = _brand;
    }

    // Check if category is custom
    final brandCats = ds.getCategoriesForBrand(_brand).where((c) => c != 'None' && c.isNotEmpty).toList();
    if (!brandCats.contains(_category)) {
      _isCustomCategory = true;
      _customCategoryCtrl.text = _category;
      _category = 'ADD_NEW';
    } else {
      _isCustomCategory = false;
    }

    final brandSubCats = ds.getProductsGroupedBySubCategory(_brand, _category == 'ADD_NEW' ? p.category : _category).keys.where((s) => s != 'None' && s.isNotEmpty).toList();
    if (!brandSubCats.contains(_subCategory)) {
      _isCustomSubCategory = true;
      _customSubCategoryCtrl.text = _subCategory;
      _subCategory = 'ADD_NEW';
    } else {
      _isCustomSubCategory = false;
    }

    _stockCtrl.text = p.stockLevel.toString();
    _lowStockCtrl.text = p.lowStockThreshold.toString();
    _imageUrlCtrl.text = p.imageUrl ?? '';
    _unit = p.unit;
    _minQtyCtrl.text = p.minQuantity.toString();
    _hasColorShade = p.hasColorShade;

    // Load dynamic size entries from existing bucket sizes & prices
    for (final size in p.bucketSizes) {
      final sizeValue = _parseSizeValue(size);
      final price = p.prices[size]?.toString() ?? '';
      _addSizeEntry(sizeValue, price == '0.0' ? '' : price);
    }
    if (_sizeValueCtrls.isEmpty) {
      _addSizeEntry('1');
      _addSizeEntry('4');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _stockCtrl.dispose();
    _lowStockCtrl.dispose();
    _imageUrlCtrl.dispose();
    for (final c in _sizeValueCtrls) {
      c.dispose();
    }
    for (final c in _sizePriceCtrls) {
      c.dispose();
    }
    _customCategoryCtrl.dispose();
    _customSubCategoryCtrl.dispose();
    _customBrandCtrl.dispose();
    _minQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1000,
    );

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Build bucket sizes from dynamic entries
    final bucketSizes = <String>[];
    final prices = <String, double>{};
    for (int i = 0; i < _sizeValueCtrls.length; i++) {
      final val = _sizeValueCtrls[i].text.trim();
      if (val.isEmpty) continue;
      final sizeKey = '$val$_unit';
      bucketSizes.add(sizeKey);
      final price = double.tryParse(_sizePriceCtrls[i].text.trim()) ?? 0;
      prices[sizeKey] = price;
    }

    if (bucketSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one container size before saving'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ds = ref.read(dataServiceProvider);
      String? finalImageUrl = _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text.trim();
      final productId = _isEdit ? widget.productId! : const Uuid().v4();

      // Upload image if picked
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
        finalImageUrl = await ds.uploadProductImage(productId, bytes, fileName);
      }

      final product = ProductModel(
        id: productId,
        name: _nameCtrl.text.trim(),
        brand: _isCustomBrand ? _customBrandCtrl.text.trim() : _brand,
        category: _isCustomCategory ? _customCategoryCtrl.text.trim() : _category,
        subCategory: _isCustomSubCategory ? _customSubCategoryCtrl.text.trim() : _subCategory.trim(),
        colorCode: '',
        colorName: '',
        colorHex: '#FFFFFF',
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        bucketSizes: bucketSizes,
        prices: prices,
        stockLevel: int.tryParse(_stockCtrl.text) ?? 0,
        lowStockThreshold: int.tryParse(_lowStockCtrl.text) ?? 10,
        unit: _unit,
        minQuantity: int.tryParse(_minQtyCtrl.text) ?? 1,
        hasColorShade: _hasColorShade,
        imageUrl: finalImageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEdit) {
        await ds.updateProduct(product);
      } else {
        await ds.addProduct(product);
      }

      await ds.refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Product updated!' : 'Product added!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        title: Text(_isEdit ? 'Edit Product' : 'Add Product',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Display/Picker
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDE8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.85),
                            blurRadius: 12,
                            offset: const Offset(-6, -6),
                          ),
                          BoxShadow(
                            color: const Color(0xFFD1CCC4).withValues(alpha: 0.65),
                            blurRadius: 12,
                            offset: const Offset(6, 6),
                          ),
                        ],
                      ),
                      child: _pickedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: Image.file(_pickedImage!, fit: BoxFit.cover),
                            )
                          : (_imageUrlCtrl.text.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(19),
                                  child: Image.network(_imageUrlCtrl.text, fit: BoxFit.cover),
                                )
                              : Icon(Icons.image_rounded, size: 64, color: Colors.grey.shade300)),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                      label: Text(_isEdit ? 'Change Image' : 'Add Image',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Brand Dropdown (supports adding a custom brand)
              Builder(
                builder: (context) {
                  final ds = ref.watch(dataServiceProvider);
                  // Derive brand list from the brands table (dynamic); fall back to base brands.
                  final managedBrands = ds.getAllBrands().map((b) => b.name).toList();
                  final brandList = managedBrands.isNotEmpty
                      ? managedBrands
                      : <String>[
                          ..._baseBrands,
                          ...ds.getAllProducts()
                              .map((p) => p.brand)
                              .where((b) => b.isNotEmpty && !_baseBrands.contains(b)),
                        ].toSet().toList();

                  return DropdownButtonFormField<String>(
                    value: _isCustomBrand ? 'ADD_NEW' : _brand,
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      prefixIcon: Icon(Icons.business_rounded, color: AppColors.primary),
                    ),
                    items: [
                      ...brandList.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                      const DropdownMenuItem(
                        value: 'ADD_NEW',
                        child: Text('+ Add New Brand',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        if (v == 'ADD_NEW') {
                          _isCustomBrand = true;
                          // A brand-new brand has no preset categories yet.
                          _category = 'ADD_NEW';
                          _isCustomCategory = true;
                          _subCategory = 'ADD_NEW';
                          _isCustomSubCategory = true;
                        } else {
                          _isCustomBrand = false;
                          _brand = v;
                        }
                      });
                      if (v != 'ADD_NEW') _updateCategoriesForBrand(v);
                    },
                  );
                },
              ),
              if (_isCustomBrand) ...[
                const SizedBox(height: 12),
                _field(_customBrandCtrl, 'New Brand Name', Icons.add_business_rounded,
                    validator: (v) => _isCustomBrand && v!.trim().isEmpty ? 'Required' : null),
              ],
              const SizedBox(height: 14),

              // Category Dropdown — union of product-derived + persisted categories
              Builder(
                builder: (context) {
                  final ds = ref.watch(dataServiceProvider);
                  final effectiveBrand = _isCustomBrand ? (_customBrandCtrl.text.trim().isEmpty ? '' : _customBrandCtrl.text.trim()) : _brand;
                  final catList = ds.getAllCategoriesForBrand(effectiveBrand);
                  if (!catList.contains(_category) && _category != 'ADD_NEW') {
                     catList.add(_category);
                  }
                  
                  return DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_rounded, color: AppColors.primary),
                    ),
                    items: [
                      ...catList.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      const DropdownMenuItem(
                        value: 'ADD_NEW',
                        child: Text('+ Add New Category', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _category = v!;
                        if (_category == 'ADD_NEW') {
                          _isCustomCategory = true;
                          _isCustomSubCategory = true;
                          _subCategory = 'ADD_NEW';
                        } else {
                          _isCustomCategory = false;
                          final subCats = ds.getProductsGroupedBySubCategory(_brand, _category).keys.where((s) => s != 'None' && s.isNotEmpty).toList();
                          if (subCats.isNotEmpty) {
                             _subCategory = subCats.first;
                             _isCustomSubCategory = false;
                          } else {
                             _subCategory = 'ADD_NEW';
                             _isCustomSubCategory = true;
                          }
                        }
                      });
                    },
                  );
                }
              ),
              if (_isCustomCategory) ...[
                const SizedBox(height: 12),
                _field(_customCategoryCtrl, 'New Category Name', Icons.edit_note_rounded,
                    validator: (v) => _isCustomCategory && v!.isEmpty ? 'Required' : null),
              ],
              const SizedBox(height: 14),

              // Sub-Category Dropdown
              if (!_isCustomCategory) Builder(
                builder: (context) {
                  final ds = ref.watch(dataServiceProvider);
                  final effectiveBrand = _isCustomBrand ? (_customBrandCtrl.text.trim().isEmpty ? '' : _customBrandCtrl.text.trim()) : _brand;
                  final subCatList = ds.getProductsGroupedBySubCategory(effectiveBrand, _category).keys.where((s) => s != 'None' && s.isNotEmpty).toList();
                  if (!subCatList.contains(_subCategory) && _subCategory != 'ADD_NEW') {
                     subCatList.add(_subCategory);
                  }

                  return DropdownButtonFormField<String>(
                    value: _subCategory,
                    decoration: const InputDecoration(
                      labelText: 'Sub Category',
                      prefixIcon: Icon(Icons.layers_rounded, color: AppColors.primary),
                    ),
                    items: [
                      ...subCatList.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                      const DropdownMenuItem(
                        value: 'ADD_NEW',
                        child: Text('+ Add New Sub-Category', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _subCategory = v!;
                        _isCustomSubCategory = (_subCategory == 'ADD_NEW');
                      });
                    },
                  );
                }
              ),
              if (_isCustomSubCategory) ...[
                const SizedBox(height: 12),
                _field(_customSubCategoryCtrl, 'New Sub-Category Name', Icons.edit_note_rounded,
                    validator: (v) => _isCustomSubCategory && v!.isEmpty ? 'Required' : null),
              ],
              const SizedBox(height: 14),
              
              _field(_nameCtrl, 'Product Name', Icons.format_paint_rounded,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 14),

              // Color Shade Toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE8),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.85),
                      blurRadius: 8,
                      offset: const Offset(-4, -4),
                    ),
                    BoxShadow(
                      color: const Color(0xFFD1CCC4).withValues(alpha: 0.55),
                      blurRadius: 8,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  value: _hasColorShade,
                  onChanged: (v) => setState(() => _hasColorShade = v),
                  title: Text(
                    'Color Shade Required',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'If enabled, painters must provide a shade code',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  activeColor: AppColors.adminPrimary,
                  secondary: Icon(Icons.format_color_fill_rounded, color: _hasColorShade ? AppColors.adminPrimary : AppColors.textLight),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              
              _field(_descCtrl, 'Description', Icons.description_rounded, maxLines: 2),
              const SizedBox(height: 14),
              
              Row(
                children: [
                  Expanded(
                    child: _field(_stockCtrl, 'Stock Level', Icons.inventory_2_rounded,
                        keyboard: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => v!.isEmpty ? 'Required' : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_lowStockCtrl, 'Low Stock Alert', Icons.warning_amber_rounded,
                        keyboard: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly]),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Unit & Minimum Quantity
              _sectionLabel('Unit & Minimum Order'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE8),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.85),
                      blurRadius: 8,
                      offset: const Offset(-4, -4),
                    ),
                    BoxShadow(
                      color: const Color(0xFFD1CCC4).withValues(alpha: 0.55),
                      blurRadius: 8,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _unit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    prefixIcon: Icon(Icons.straighten_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ML', child: Text('ML (Milliliters)')),
                    DropdownMenuItem(value: 'L', child: Text('L (Liters)')),
                    DropdownMenuItem(value: 'KG', child: Text('KG (Kilograms)')),
                    DropdownMenuItem(value: 'G', child: Text('G (Grams)')),
                    DropdownMenuItem(value: 'IN', child: Text('IN (Inches)')),
                  ],
                  onChanged: (v) => setState(() => _unit = v!),
                ),
              ),
              const SizedBox(height: 12),
              _field(_minQtyCtrl, 'Min. Order Qty', Icons.production_quantity_limits_rounded,
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 20),

              // Container Sizes & Prices
              _sectionLabel('Container Sizes'),
              const SizedBox(height: 10),
              ...List.generate(_sizeValueCtrls.length, (i) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDE8),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.85),
                        blurRadius: 8,
                        offset: const Offset(-4, -4),
                      ),
                      BoxShadow(
                        color: const Color(0xFFD1CCC4).withValues(alpha: 0.55),
                        blurRadius: 8,
                        offset: const Offset(4, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Size value
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _sizeValueCtrls[i],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Size',
                            suffixText: _unit,
                            suffixStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Price
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _sizePriceCtrls[i],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Price (Optional)',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Remove button
                      if (_sizeValueCtrls.length > 1)
                        IconButton(
                          onPressed: () => _removeSizeEntry(i),
                          icon: const Icon(Icons.remove_circle_rounded, color: AppColors.error, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                );
              }),
              // Add size button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addSizeEntry(),
                  icon: const Icon(Icons.add_circle_rounded, size: 20),
                  label: Text('Add Size',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(_isSaving ? 'Saving...' : (_isEdit ? 'Update Product' : 'Add Product'),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.adminPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard,
      List<TextInputFormatter>? formatters,
      String? Function(String?)? validator,
      int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 8,
            offset: const Offset(-4, -4),
          ),
          BoxShadow(
            color: const Color(0xFFD1CCC4).withValues(alpha: 0.55),
            blurRadius: 8,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        validator: validator,
      ),
    );
  }


  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
