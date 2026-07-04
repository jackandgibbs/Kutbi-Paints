import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
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
    File? newCoverFile;
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
                                  child: CachedNetworkImage(
                                      imageUrl: brand.logoUrl!,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 160,
                                      errorWidget: (_, __, ___) => const Icon(
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

                  // Cover image picker (wide banner used as the brand header on
                  // the painter side, mirroring Birla Opus's cover)
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                        maxWidth: 1000,
                      );
                      if (picked != null) setDlg(() => newCoverFile = File(picked.path));
                    },
                    child: Container(
                      width: double.infinity,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.adminPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.adminPrimary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: newCoverFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(newCoverFile!, width: double.infinity, fit: BoxFit.cover),
                            )
                          : brand.hasCover
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: CachedNetworkImage(
                                      imageUrl: brand.coverImageUrl!,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 600,
                                      errorWidget: (_, __, ___) => const Icon(
                                          Icons.image_not_supported_rounded,
                                          size: 26,
                                          color: AppColors.adminPrimary)),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.image_rounded,
                                        size: 26, color: AppColors.adminPrimary),
                                    const SizedBox(height: 4),
                                    Text('Add Cover Image (optional)',
                                        style: GoogleFonts.poppins(
                                            fontSize: 10, color: AppColors.adminPrimary)),
                                  ],
                                ),
                    ),
                  ),
                  if (newCoverFile != null || brand.hasCover)
                    TextButton.icon(
                      onPressed: () => setDlg(() => newCoverFile = null),
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
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Brand name is required')),
                        );
                        return;
                      }

                      // Capture router + messenger from the *screen* context BEFORE
                      // any async work. Doing the mutations (which call
                      // notifyListeners) while this dialog is still mounted tears
                      // the screen's InheritedElements down underneath the open
                      // dialog and triggers the '_dependents.isEmpty' assertion.
                      final router = GoRouter.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final ds = ref.read(dataServiceProvider);
                      final nameChanged = newName != brand.name;

                      setDlg(() => saving = true);

                      // Read image bytes while the dialog is still open (no
                      // notifyListeners fires yet, so the tree is stable).
                      Uint8List? logoBytes;
                      Uint8List? coverBytes;
                      try {
                        if (newLogoFile != null) {
                          logoBytes = await newLogoFile!.readAsBytes();
                        }
                        if (newCoverFile != null) {
                          coverBytes = await newCoverFile!.readAsBytes();
                        }
                      } catch (e) {
                        setDlg(() => saving = false);
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      // Close the dialog FIRST so its dependents are detached
                      // before the mutations rebuild the underlying screen.
                      if (ctx.mounted) Navigator.pop(ctx);

                      // Wait for the dialog to fully close and detach
                      await Future.delayed(const Duration(milliseconds: 100));

                      try {
                        if (nameChanged) {
                          await ds.updateBrandName(brand.id, newName);
                        }
                        if (logoBytes != null) {
                          final url = await ds.uploadBrandLogo(brand.id, logoBytes,
                              'logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await ds.updateBrandLogo(brand.id, url);
                        }
                        if (coverBytes != null) {
                          final url = await ds.uploadBrandCover(brand.id, coverBytes,
                              '${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await ds.updateBrandCover(brand.id, url);
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Brand updated!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );

                        // If the name changed, this screen was keyed on the old
                        // name and now resolves to a null brand — re-bind it to
                        // the renamed route so it shows live data again.
                        if (nameChanged && context.mounted) {
                          router.pushReplacement(
                              '/admin/brand-detail/${Uri.encodeComponent(newName)}');
                        }
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.error,
                              duration: const Duration(seconds: 3)),
                        );
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

    // Capture navigator + messenger, then leave this screen BEFORE the mutation.
    // deleteBrand calls notifyListeners, which would rebuild/tear down this
    // screen's dataServiceProvider watchers while it is still mounted and trip
    // the '_dependents.isEmpty' framework assertion. Popping first detaches
    // those watchers so the refresh lands on the (already updated) brands list.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ds = ref.read(dataServiceProvider);
    navigator.pop();
    try {
      await ds.deleteBrand(brand.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
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
    // brand can momentarily be null right after a rename (this screen was keyed
    // on the old name) — show a stable loader instead of tearing the whole
    // content tree down, which is what tripped the framework assertion.
    if (brand == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: Center(child: CircularProgressIndicator()),
      );
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
                  if (!_isBusy)
                    IconButton(
                      onPressed: () => _editBrand(brand),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      tooltip: 'Edit brand',
                    ),
                  if (!_isBusy)
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
                      child: brand.hasLogo
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 32),
                              child: CachedNetworkImage(
                                imageUrl: brand.logoUrl!,
                                height: 80,
                                fit: BoxFit.contain,
                                fadeInDuration: const Duration(milliseconds: 150),
                                errorWidget: (_, __, ___) => _logoFallback(primary),
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
                        ? CachedNetworkImage(
                            imageUrl: p.imageUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 80,
                            memCacheHeight: 80,
                            fadeInDuration: const Duration(milliseconds: 150),
                            placeholder: (_, __) => const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.textLight),
                            errorWidget: (_, __, ___) =>
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
