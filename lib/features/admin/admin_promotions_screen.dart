import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../models/promotion_model.dart';
import '../../services/data_service.dart';
import '../../core/widgets/lottie_loading_widget.dart';

class AdminPromotionsScreen extends ConsumerStatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  ConsumerState<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends ConsumerState<AdminPromotionsScreen> {
  final _titleController = TextEditingController();
  final _discountPercentController = TextEditingController();
  final _discountFlatController = TextEditingController();
  String _selectedBrand = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _titleController.dispose();
    _discountPercentController.dispose();
    _discountFlatController.dispose();
    super.dispose();
  }

  void _showAddPromotionSheet() {
    _titleController.clear();
    _discountPercentController.clear();
    _discountFlatController.clear();
    _selectedBrand = 'All';
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Promotion',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Promotion Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Brand Filter
                  DropdownButtonFormField<String>(
                    value: _selectedBrand,
                    decoration: InputDecoration(
                      labelText: 'Applies to Brand',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    items: ['All', 'Asian Paints', 'Berger', 'Birla Opus']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setStateSB(() => _selectedBrand = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Discounts
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _discountPercentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: '% Discount (e.g. 0.1 for 10%)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _discountFlatController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Flat ₹ Discount (e.g. 50)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dates
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate!,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setStateSB(() => _startDate = date);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                            ),
                            child: Text(DateFormat('yyyy-MM-dd').format(_startDate!)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate!,
                              firstDate: _startDate!,
                              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                            );
                            if (date != null) setStateSB(() => _endDate = date);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                            ),
                            child: Text(DateFormat('yyyy-MM-dd').format(_endDate!)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.adminPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_titleController.text.trim().isEmpty) return;
                        
                        final promo = PromotionModel(
                          id: const Uuid().v4(),
                          title: _titleController.text.trim(),
                          brand: _selectedBrand,
                          discountPercent: double.tryParse(_discountPercentController.text) ?? 0.0,
                          discountFlat: double.tryParse(_discountFlatController.text) ?? 0.0,
                          startDate: _startDate!,
                          endDate: _endDate!,
                          isActive: true,
                          createdAt: DateTime.now(),
                        );
                        
                        ref.read(dataServiceProvider).addPromotion(promo);
                        Navigator.pop(context);
                      },
                      child: Text('Create Promotion', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final promos = ds.getAllPromotions;

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: LottieLoadingWidget(message: 'Loading promotions...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        title: Text('Promotions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.adminPrimary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
        onPressed: _showAddPromotionSheet,
      ),
      body: promos.isEmpty
          ? const Center(child: Text('No active promotions'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: promos.length,
              itemBuilder: (context, index) {
                final basePromo = promos.toList()..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
                final promo = basePromo[index];
                final isValid = promo.isValidNow;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDE8),
                    borderRadius: BorderRadius.circular(18),
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(promo.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isValid ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isValid ? 'Active' : 'Inactive/Expired',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: isValid ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              promo.brand,
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${promo.discountPercent > 0 ? '${(promo.discountPercent*100).toStringAsFixed(0)}% OFF' : ''} ${promo.discountFlat > 0 ? '₹${promo.discountFlat} OFF' : ''}'.trim(),
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.adminPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Valid: ${DateFormat('MMM d').format(promo.startDate)} - ${DateFormat('MMM d').format(promo.endDate)}',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textLight),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () {
                        // Confirm deletion and call delete
                        ref.read(dataServiceProvider).deletePromotion(promo.id);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
