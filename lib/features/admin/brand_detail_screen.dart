import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/brand_model.dart';
import '../../services/data_service.dart';

class BrandDetailScreen extends ConsumerStatefulWidget {
  final String brandName;
  const BrandDetailScreen({super.key, required this.brandName});

  @override
  ConsumerState<BrandDetailScreen> createState() => _BrandDetailScreenState();
}

class _BrandDetailScreenState extends ConsumerState<BrandDetailScreen> {
  bool _isBusy = false;

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Category',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Interior',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.adminPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.adminPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Add', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (confirmed != true || !mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(dataServiceProvider).addBrandCategory(widget.brandName, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$name" added to ${widget.brandName}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteCategory(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Category?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Remove "$name" from ${widget.brandName}? '
            'Existing products in this category are not deleted.',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(dataServiceProvider).deleteBrandCategory(id);
  }

  Future<void> _editBrand(BrandModel brand) async {
    final nameCtrl = TextEditingController(text: brand.name);
    File? newLogoFile;
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Brand',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.5,
              maxWidth: 400,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                        maxWidth: 400,
                      );
                      if (picked != null) setDlg(() => newLogoFile = File(picked.path));
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.adminPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.adminPrimary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: newLogoFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(newLogoFile!, fit: BoxFit.cover),
                            )
                          : brand.hasLogo
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.network(brand.logoUrl!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.image_not_supported_rounded,
                                          size: 28,
                                          color: AppColors.adminPrimary)),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_rounded,
                                        size: 28, color: AppColors.adminPrimary),
                                    const SizedBox(height: 4),
                                    Text('Add Logo',
                                        style: GoogleFonts.poppins(
                                            fontSize: 10, color: AppColors.adminPrimary)),
                                  ],
                                ),
                    ),
                  ),
                  if (newLogoFile != null || brand.hasLogo)
                    TextButton.icon(
                      onPressed: () => setDlg(() => newLogoFile = null),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: Text('Change', style: GoogleFonts.poppins(fontSize: 11)),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Brand Name *',
                      hintText: 'e.g. Nerolac',
                      labelStyle: GoogleFonts.poppins(),
                      hintStyle: GoogleFonts.poppins(color: AppColors.textLight),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.adminPrimary),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child:
                  Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final newName = nameCtrl.text.trim();
                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Brand name is required')),
                        );
                        return;
                      }
                      setDlg(() => saving = true);
                      try {
                        final ds = ref.read(dataServiceProvider);
                        
                        // Update name if changed
                        if (newName != brand.name) {
                          await ds.updateBrandName(brand.id, newName);
                        }
                        
                        // Update logo if a new file was selected
                        if (newLogoFile != null) {
                          final bytes = await newLogoFile!.readAsBytes();
                          final url = await ds.uploadBrandLogo(brand.id, bytes,
                              'logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await ds.updateBrandLogo(brand.id, url);
                        }
                        
                        // Pop dialog first
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        // Wait a frame before showing snackbar
                        await Future.delayed(Duration.zero);
                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Brand updated!'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      } catch (e) {
                        setDlg(() => saving = false);
                        if (ctx.mounted && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save Changes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _deleteBrand(BrandModel brand, int productCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${brand.name}?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete:', style: GoogleFonts.poppins(fontSize: 14)),
            const SizedBox(height: 8),
            _bullet('The brand "${brand.name}"'),
            _bullet('$productCount product${productCount == 1 ? '' : 's'} under this brand'),
            _bullet('All categories for this brand'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('This action cannot be undone.',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await ref.read(dataServiceProvider).deleteBrand(brand.id);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: AppColors.textSecondary)),
            Expanded(
                child: Text(text,
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final brand = ds.getBrandByName(widget.brandName);
    if (brand == null && !ds.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final primary = AppColors.getBrandPrimary(widget.brandName);
    final categories = ds.getAllCategoriesForBrand(widget.brandName);
    final categoryIds = ds.getPersistedCategoryIds(widget.brandName);
    final products = ds.getProductsByBrand(widget.brandName);

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: primary,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                ),
                actions: [
                  if (brand != null && !_isBusy)
                    IconButton(
                      onPressed: () => _editBrand(brand),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      tooltip: 'Edit brand',
                    ),
                  if (brand != null && !_isBusy)
                    IconButton(
                      onPressed: () => _deleteBrand(brand, products.length),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      tooltip: 'Delete brand',
                    ),
                  if (_isBusy)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.fromLTRB(70, 0, 16, 16),
                  title: Text(widget.brandName,
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppColors.getBrandGradient(widget.brandName),
                      ),
                    ),
                    child: Center(
                      child: brand != null && brand.hasLogo
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 32),
                              child: Image.network(
                                brand.logoUrl!,
                                height: 80,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _logoFallback(primary),
                              ),
                            )
                          : _logoFallback(primary),
                    ),
                  ),
                ),
              ),

              // ── Stats row ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statChip('${products.length}', 'Products', Icons.inventory_2_outlined, primary),
                      _statChip('${categories.length}', 'Categories', Icons.category_outlined, AppColors.textSecondary),
                      // Add product shortcut
                      OutlinedButton.icon(
                        onPressed: () => context.push('/admin/add-product'),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text('Add Product',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Add Category button ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: OutlinedButton.icon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.adminPrimary),
                    label: Text('Add Category',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.adminPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.adminPrimary),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

              // ── Categories ───────────────────────────────────
              if (categories.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No categories yet',
                            style: GoogleFonts.poppins(
                                fontSize: 15, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Tap "Add Category" above to create one',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final cat = categories[i];
                      final catProducts = ds.getProductsByCategory(widget.brandName, cat);
                      final catId = categoryIds[cat]; // null → derived, not persisted
                      return _buildCategorySection(cat, catProducts, catId, primary);
                    },
                    childCount: categories.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoFallback(Color color) => Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              widget.brandName.isNotEmpty ? widget.brandName[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      );

  Widget _statChip(String value, String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text('$value $label',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );

  Widget _buildCategorySection(
    String category,
    List<dynamic> products,
    String? categoryId,
    Color primary,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.85), blurRadius: 10, offset: const Offset(-4, -4)),
          BoxShadow(color: const Color(0xFFD1CCC4).withValues(alpha: 0.65), blurRadius: 10, offset: const Offset(4, 4)),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.category_rounded, color: primary, size: 18),
        ),
        title: Text(category,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${products.length} product${products.length == 1 ? '' : 's'}',
          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only persisted categories can be deleted from here
            if (categoryId != null)
              IconButton(
                onPressed: () => _deleteCategory(categoryId, category),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.error),
                tooltip: 'Remove category',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: AppColors.textLight),
          ],
        ),
        children: [
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No products in this category yet.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic)),
            )
          else
            ...products.map((p) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  leading: Container(
                    width: 40,
                    height: 40,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                        ? Image.network(p.imageUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textLight))
                        : const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textLight),
                  ),
                  title: Text(p.name,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Stock: ${p.stockLevel}',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                  onTap: () => context.push('/admin/edit-product/${p.id}'),
                )),
        ],
      ),
    );
  }
}
