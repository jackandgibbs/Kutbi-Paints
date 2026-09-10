import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/responsive_center.dart';
import '../../models/promotion_model.dart';
import '../../services/data_service.dart';
import '../../core/widgets/lottie_loading_widget.dart';

class AdminPromotionsScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const AdminPromotionsScreen({super.key, this.initialTab});

  @override
  ConsumerState<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends ConsumerState<AdminPromotionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _discountPercentController = TextEditingController();
  final _searchController = TextEditingController();
  String _selectedBrand = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialTab == 'deactivated' || widget.initialTab == '1') {
      initialIndex = 1;
    } else if (widget.initialTab == 'deleted' || widget.initialTab == '2') {
      initialIndex = 2;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _discountPercentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddOfferSheet({PromotionModel? existingOffer, bool isRecreate = false}) {
    if (existingOffer != null) {
      _titleController.text = existingOffer.title;
      // Convert to integer percentage if <= 1.0 (e.g. 0.15 -> 15)
      if (existingOffer.discountPercent <= 1.0 && existingOffer.discountPercent > 0) {
        _discountPercentController.text =
            (existingOffer.discountPercent * 100).toStringAsFixed(0);
      } else {
        _discountPercentController.text =
            existingOffer.discountPercent.toStringAsFixed(0);
      }
      _selectedBrand = existingOffer.brand;

      if (isRecreate) {
        // Fresh dates for re-creating the offer
        _startDate = DateTime.now();
        _endDate = DateTime.now().add(const Duration(days: 30));
      } else {
        _startDate = existingOffer.startDate;
        _endDate = existingOffer.endDate;
      }
    } else {
      _titleController.clear();
      _discountPercentController.clear();
      _selectedBrand = 'All';
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 14));
    }

    final ds = ref.read(dataServiceProvider);
    final brandOptions = <String>{'All', 'Asian Paints', 'Berger', 'Birla Opus'};
    for (final p in ds.products) {
      if (p.brand.isNotEmpty) brandOptions.add(p.brand);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isRecreate
                                  ? Colors.orange.shade50
                                  : AppColors.adminPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isRecreate
                                  ? Icons.autorenew_rounded
                                  : (existingOffer != null
                                      ? Icons.edit_rounded
                                      : Icons.campaign_rounded),
                              color: isRecreate ? Colors.orange.shade700 : AppColors.adminPrimary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isRecreate
                                      ? 'Re-create Offer'
                                      : (existingOffer != null ? 'Edit Offer' : 'Create New Offer'),
                                  style: GoogleFonts.poppins(
                                      fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                if (isRecreate)
                                  Text(
                                    'Create a fresh active offer cloned from previous terms',
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Offer Title',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Festive Monsoon Special',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          prefixIcon: const Icon(Icons.title_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Brand Filter
                      Text(
                        'Applies to Brand',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: brandOptions.contains(_selectedBrand) ? _selectedBrand : 'All',
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          prefixIcon: const Icon(Icons.category_rounded, size: 20),
                        ),
                        items: brandOptions
                            .map((b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(b, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setStateSB(() => _selectedBrand = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Discounts
                      Text(
                        'Discount Percentage',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _discountPercentController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'e.g. 10 for 10% off',
                          suffixText: '% OFF',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          prefixIcon: const Icon(Icons.percent_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dates
                      Text(
                        'Validity Period',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                );
                                if (date != null) setStateSB(() => _startDate = date);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Start Date',
                                  border:
                                      OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                ),
                                child: Text(DateFormat('dd MMM yyyy').format(_startDate!)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ??
                                      (_startDate ?? DateTime.now()).add(const Duration(days: 14)),
                                  firstDate: _startDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                                );
                                if (date != null) setStateSB(() => _endDate = date);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End Date',
                                  border:
                                      OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.event_available_rounded, size: 18),
                                ),
                                child: Text(DateFormat('dd MMM yyyy').format(_endDate!)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRecreate
                                ? const Color(0xFFF97316)
                                : AppColors.adminPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final title = _titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter an offer title')),
                              );
                              return;
                            }

                            double discountVal =
                                double.tryParse(_discountPercentController.text) ?? 0.0;
                            if (discountVal > 100) discountVal = 100;
                            if (discountVal > 1.0) discountVal = discountVal / 100.0;
                            if (discountVal <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid discount %')),
                              );
                              return;
                            }

                            if (existingOffer != null && !isRecreate) {
                              // Edit existing
                              final updated = existingOffer.copyWith(
                                title: title,
                                brand: _selectedBrand,
                                discountPercent: discountVal,
                                discountFlat: 0.0,
                                startDate: _startDate!,
                                endDate: _endDate!,
                              );
                              ref.read(dataServiceProvider).updatePromotion(updated);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Offer updated successfully')),
                              );
                            } else {
                              // Brand new or Re-created
                              final promo = PromotionModel(
                                id: const Uuid().v4(),
                                title: title,
                                brand: _selectedBrand,
                                discountPercent: discountVal,
                                discountFlat: 0.0,
                                startDate: _startDate!,
                                endDate: _endDate!,
                                isActive: true,
                                createdAt: DateTime.now(),
                                isDeleted: false,
                              );
                              ref.read(dataServiceProvider).addPromotion(promo);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF059669),
                                  content: Text(isRecreate
                                      ? 'Offer re-created and published!'
                                      : 'New offer created successfully!'),
                                ),
                              );
                              // Switch to Active Tab
                              _tabController.animateTo(0);
                            }
                            Navigator.pop(context);
                          },
                          child: Text(
                            isRecreate
                                ? 'Re-create & Launch Offer'
                                : (existingOffer != null ? 'Save Changes' : 'Create Offer'),
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteOffer(PromotionModel promo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Offer', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Move "${promo.title}" to Deleted Offers? You can re-create or restore it later.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(dataServiceProvider).deletePromotion(promo.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Moved "${promo.title}" to Deleted Offers'),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: Colors.amber,
                    onPressed: () {
                      ref.read(dataServiceProvider).restorePromotion(promo);
                    },
                  ),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDelete(PromotionModel promo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Permanently',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text(
          'Are you sure you want to permanently delete "${promo.title}"? This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(dataServiceProvider).permanentlyDeletePromotion(promo.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Permanently deleted "${promo.title}"')),
              );
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: LottieLoadingWidget(message: 'Loading offers...'),
      );
    }

    final query = _searchQuery.trim().toLowerCase();

    // Active offers: not deleted, isActive == true, and not expired
    final allActive = ds.getActivePromotionsAdmin;
    final activeOffers = query.isEmpty
        ? allActive
        : allActive.where((p) =>
            p.title.toLowerCase().contains(query) || p.brand.toLowerCase().contains(query)).toList();

    // Deactivated offers: not deleted, and (isActive == false OR isExpired)
    final allDeactivated = ds.getDeactivatedPromotions;
    final deactivatedOffers = query.isEmpty
        ? allDeactivated
        : allDeactivated.where((p) =>
            p.title.toLowerCase().contains(query) || p.brand.toLowerCase().contains(query)).toList();

    // Deleted offers: soft deleted offers
    final allDeleted = ds.getDeletedPromotions;
    final deletedOffers = query.isEmpty
        ? allDeleted
        : allDeleted.where((p) =>
            p.title.toLowerCase().contains(query) || p.brand.toLowerCase().contains(query)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        title: Text('Offers & Promotions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.adminPrimary,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppColors.adminPrimary,
              indicatorWeight: 3,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelStyle: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500),
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Active'),
                        const SizedBox(width: 5),
                        _countBadge(allActive.length, const Color(0xFF10B981)),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Deactivated'),
                        const SizedBox(width: 5),
                        _countBadge(allDeactivated.length, const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Deleted'),
                        const SizedBox(width: 5),
                        _countBadge(allDeleted.length, const Color(0xFFEF4444)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.adminPrimary,
        onPressed: () => _showAddOfferSheet(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Offer',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: ResponsiveCenter(
        maxWidth: Responsive.contentMaxWidth(context),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search offers by title or brand...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Active Offers
                  _buildActiveOffersTab(activeOffers),

                  // Tab 2: Deactivated Offers
                  _buildDeactivatedOffersTab(deactivatedOffers),

                  // Tab 3: Deleted Offers
                  _buildDeletedOffersTab(deletedOffers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: ACTIVE OFFERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveOffersTab(List<PromotionModel> offers) {
    if (offers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.campaign_rounded,
        title: 'No Active Offers',
        subtitle: _searchQuery.isNotEmpty
            ? 'No active offers match "$_searchQuery"'
            : 'Create a new campaign or re-activate past offers to engage painters.',
        actionLabel: '+ Create Offer',
        onAction: () => _showAddOfferSheet(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final promo = offers[index];
        final discountText = '${(promo.discountPercent * 100).toStringAsFixed(0)}% OFF';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.shade200),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _chip(promo.brand, Colors.indigo),
                              const SizedBox(width: 8),
                              _chip(discountText, Colors.green),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Quick Deactivate Switch
                    Column(
                      children: [
                        Switch(
                          value: promo.isActive,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            ref
                                .read(dataServiceProvider)
                                .updatePromotion(promo.copyWith(isActive: val));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Offer moved to Deactivated')),
                            );
                          },
                        ),
                        Text(
                          'Active',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Date & Actions
                Row(
                  children: [
                    Icon(Icons.date_range_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${DateFormat('dd MMM yyyy').format(promo.startDate)} - ${DateFormat('dd MMM yyyy').format(promo.endDate)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit Offer',
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showAddOfferSheet(existingOffer: promo),
                    ),
                    IconButton(
                      tooltip: 'Delete Offer',
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () => _confirmDeleteOffer(promo),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: DEACTIVATED OFFERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDeactivatedOffersTab(List<PromotionModel> offers) {
    if (offers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pause_circle_outline_rounded,
        title: 'No Deactivated Offers',
        subtitle: _searchQuery.isNotEmpty
            ? 'No deactivated offers match "$_searchQuery"'
            : 'Offers that expire or are manually switched off will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final promo = offers[index];
        final isExpired = promo.isExpired;
        final discountText = '${(promo.discountPercent * 100).toStringAsFixed(0)}% OFF';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _chip(promo.brand, Colors.blueGrey),
                              const SizedBox(width: 8),
                              _chip(discountText, Colors.orange),
                              const SizedBox(width: 8),
                              _chip(
                                isExpired ? 'Expired' : 'Disabled',
                                isExpired ? Colors.red : Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Quick Re-activate switch
                    Column(
                      children: [
                        Switch(
                          value: false,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            // Re-activate
                            final updated = promo.copyWith(
                              isActive: true,
                              startDate: isExpired ? DateTime.now() : promo.startDate,
                              endDate: isExpired
                                  ? DateTime.now().add(const Duration(days: 30))
                                  : promo.endDate,
                            );
                            ref.read(dataServiceProvider).updatePromotion(updated);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Offer re-activated & live!')),
                            );
                          },
                        ),
                        Text(
                          'Deactivated',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Validity Period
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(promo.startDate)} - ${DateFormat('dd MMM yyyy').format(promo.endDate)}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Actions: Re-create Offer + Delete
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.autorenew_rounded, size: 18),
                        label: const Text('Re-create Offer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => _showAddOfferSheet(existingOffer: promo, isRecreate: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Re-activate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF059669)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final updated = promo.copyWith(
                          isActive: true,
                          startDate: isExpired ? DateTime.now() : promo.startDate,
                          endDate: isExpired
                              ? DateTime.now().add(const Duration(days: 30))
                              : promo.endDate,
                        );
                        ref.read(dataServiceProvider).updatePromotion(updated);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Offer re-activated & live!')),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Delete Offer',
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () => _confirmDeleteOffer(promo),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: DELETED OFFERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDeletedOffersTab(List<PromotionModel> offers) {
    if (offers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.delete_sweep_rounded,
        title: 'No Deleted Offers',
        subtitle: _searchQuery.isNotEmpty
            ? 'No deleted offers match "$_searchQuery"'
            : 'Deleted offers will be kept here so you can re-create or restore them anytime.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final promo = offers[index];
        final discountText = '${(promo.discountPercent * 100).toStringAsFixed(0)}% OFF';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade200),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Deleted Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _chip(promo.brand, Colors.blueGrey),
                              const SizedBox(width: 8),
                              _chip(discountText, Colors.orange),
                              const SizedBox(width: 8),
                              _chip('Deleted', Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete Permanently',
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                      onPressed: () => _confirmPermanentDelete(promo),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Original validity info
                Row(
                  children: [
                    Icon(Icons.history_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Original Validity: ${DateFormat('dd MMM yyyy').format(promo.startDate)} - ${DateFormat('dd MMM yyyy').format(promo.endDate)}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Actions: Re-create Offer + Restore
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.autorenew_rounded, size: 18),
                        label: const Text('Re-create Offer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => _showAddOfferSheet(existingOffer: promo, isRecreate: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restore_from_trash_rounded, size: 18),
                      label: const Text('Restore'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0284C7),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        ref.read(dataServiceProvider).restorePromotion(promo);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF059669),
                            content: Text('"${promo.title}" restored to Active Offers!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade800,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onAction,
                child: Text(actionLabel, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
