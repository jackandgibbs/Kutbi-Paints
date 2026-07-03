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

class BrandsCategoriesScreen extends ConsumerStatefulWidget {
  const BrandsCategoriesScreen({super.key});

  @override
  ConsumerState<BrandsCategoriesScreen> createState() => _BrandsCategoriesScreenState();
}

class _BrandsCategoriesScreenState extends ConsumerState<BrandsCategoriesScreen> {
  bool _isAdding = false;

  // ─── Add Brand Dialog ────────────────────────────────────────
  Future<void> _showAddBrandDialog() async {
    final nameCtrl = TextEditingController();
    File? logoFile;
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add New Brand',
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
                      if (picked != null) setDlg(() => logoFile = File(picked.path));
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
                      child: logoFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(logoFile!, fit: BoxFit.cover),
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
                  if (logoFile != null)
                    TextButton.icon(
                      onPressed: () => setDlg(() => logoFile = null),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
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
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Brand name is required')),
                        );
                        return;
                      }
                      setDlg(() => saving = true);
                      try {
                        final ds = ref.read(dataServiceProvider);
                        final brand = await ds.addBrand(name: name);
                        if (logoFile != null) {
                          final bytes = await logoFile!.readAsBytes();
                          final url = await ds.uploadBrandLogo(
                              brand.id, bytes, 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await ds.updateBrandLogo(brand.id, url);
                        }
                        // Pop dialog first
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        // Wait a frame before showing snackbar to avoid framework assertion
                        await Future.delayed(Duration.zero);
                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$name added!'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      } catch (e) {
                        setDlg(() => saving = false);
                        if (ctx.mounted && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Add Brand', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  // ─── Delete Brand Confirm ────────────────────────────────────
  Future<void> _confirmDeleteBrand(BrandModel brand, int productCount) async {
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
    setState(() => _isAdding = true);
    try {
      await ref.read(dataServiceProvider).deleteBrand(brand.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${brand.name} and its products deleted'),
            backgroundColor: AppColors.error,
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
    } finally {
      if (mounted) setState(() => _isAdding = false);
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
    final brands = ds.getAllBrands();

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
          child: Column(
            children: [
              // Header
              Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16, right: 16, bottom: 8,
                ),
                padding: const EdgeInsets.fromLTRB(6, 10, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDE8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Brands',
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          Text('Manage brands & categories',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.adminPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${brands.length} brands',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.adminPrimary)),
                    ),
                  ],
                ),
              ),

              // Brand grid/list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: ds.refresh,
                  child: brands.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 400,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business_rounded,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text('No brands yet',
                                    style: GoogleFonts.poppins(
                                        fontSize: 16, color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                Text('Tap + to add your first brand',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: AppColors.textLight)),
                              ],
                            ),
                          ),
                        )
                      : Responsive.isDesktop(context)
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.4,
                              ),
                              itemCount: brands.length,
                              itemBuilder: (_, i) => _buildBrandCard(brands[i], ds),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: brands.length,
                              itemBuilder: (_, i) => _buildBrandCard(brands[i], ds),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAdding ? null : _showAddBrandDialog,
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: Text('Add Brand', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBrandCard(BrandModel brand, DataService ds) {
    final productCount = ds.getProductsByBrand(brand.name).length;
    final categoryCount = ds.getAllCategoriesForBrand(brand.name).length;
    final primary = AppColors.getBrandPrimary(brand.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 14,
            offset: const Offset(-6, -6),
          ),
          BoxShadow(
            color: const Color(0xFFD1CCC4).withValues(alpha: 0.65),
            blurRadius: 14,
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/admin/brand-detail/${Uri.encodeComponent(brand.name)}'),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo / letter
              Container(
                width: 60,
                height: 60,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: brand.hasLogo
                    ? Image.network(brand.logoUrl!, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _brandInitial(brand.name, primary))
                    : _brandInitial(brand.name, primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _countChip(Icons.inventory_2_outlined, '$productCount products', AppColors.adminPrimary),
                        _countChip(Icons.category_outlined, '$categoryCount categories', AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
              // Delete
              IconButton(
                onPressed: () => _confirmDeleteBrand(brand, productCount),
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
                tooltip: 'Delete brand',
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandInitial(String name, Color color) => Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w800, color: color),
        ),
      );

  Widget _countChip(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      );
}
