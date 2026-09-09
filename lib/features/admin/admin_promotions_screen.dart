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
  const AdminPromotionsScreen({super.key});

  @override
  ConsumerState<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends ConsumerState<AdminPromotionsScreen> {
  final _titleController = TextEditingController();
  final _discountPercentController = TextEditingController();
  String _selectedBrand = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _titleController.dispose();
    _discountPercentController.dispose();
    super.dispose();
  }

  void _showAddOfferSheet({PromotionModel? existingOffer}) {
    if (existingOffer != null) {
      _titleController.text = existingOffer.title;
      _discountPercentController.text = existingOffer.discountPercent.toString();
      _selectedBrand = existingOffer.brand;
      _startDate = existingOffer.startDate;
      _endDate = existingOffer.endDate;
    } else {
      _titleController.clear();
      _discountPercentController.clear();
      _selectedBrand = 'All';
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 7));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
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
                    existingOffer != null ? 'Edit Offer' : 'Create Offer',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Offer Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Brand Filter
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBrand,
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
                  TextField(
                    controller: _discountPercentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '% Discount (e.g. 10 for 10%)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
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
                        
                        double discountVal = double.tryParse(_discountPercentController.text) ?? 0.0;
                        if (discountVal > 100) discountVal = 100;
                        // Storing as a percentage up to 100 directly. 
                        // Note: previous implementation used 0.1 for 10%, let's normalize this: 
                        // If they enter 10, save it as 0.1. If they enter 0.1, it's 0.1.
                        // Let's assume if it's > 1, they mean percentages.
                        if (discountVal > 1.0) discountVal = discountVal / 100.0;

                        if (existingOffer != null) {
                          final updated = existingOffer.copyWith(
                            title: _titleController.text.trim(),
                            brand: _selectedBrand,
                            discountPercent: discountVal,
                            discountFlat: 0.0,
                            startDate: _startDate!,
                            endDate: _endDate!,
                          );
                          ref.read(dataServiceProvider).updatePromotion(updated);
                        } else {
                          final promo = PromotionModel(
                            id: const Uuid().v4(),
                            title: _titleController.text.trim(),
                            brand: _selectedBrand,
                            discountPercent: discountVal,
                            discountFlat: 0.0,
                            startDate: _startDate!,
                            endDate: _endDate!,
                            isActive: true,
                            createdAt: DateTime.now(),
                          );
                          ref.read(dataServiceProvider).addPromotion(promo);
                        }
                        Navigator.pop(context);
                      },
                      child: Text(existingOffer != null ? 'Save Changes' : 'Create Offer', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
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

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final promos = ds.getAllPromotions;

    if (!ds.isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0EDE8),
        body: LottieLoadingWidget(message: 'Loading offers...'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        title: Text('Offers', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.adminPrimary,
        onPressed: () => _showAddOfferSheet(),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: promos.isEmpty
          ? const Center(child: Text('No active offers'))
          : ResponsiveCenter(
              maxWidth: Responsive.contentMaxWidth(context),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: promos.length,
                itemBuilder: (context, index) {
                  final basePromo = promos.toList()..sort((a,b)=>b.createdAt.compareTo(a.createdAt));
                  final promo = basePromo[index];
                  final isUpcoming = promo.isUpcoming;
                  final isExpired = promo.isExpired;

                  String statusText = 'Active';
                  Color statusColor = Colors.green.shade800;
                  Color statusBg = Colors.green.shade50;

                  if (isExpired) {
                    statusText = 'Expired';
                    statusColor = Colors.red.shade800;
                    statusBg = Colors.red.shade50;
                  } else if (isUpcoming) {
                    statusText = 'Upcoming';
                    statusColor = Colors.blue.shade800;
                    statusBg = Colors.blue.shade50;
                  } else if (!promo.isActive) {
                    statusText = 'Disabled';
                    statusColor = Colors.grey.shade800;
                    statusBg = Colors.grey.shade100;
                  }

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              promo.title,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusText,
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Brand: ${promo.brand} • Discount: ${(promo.discountPercent * 100).toInt()}% Off',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('dd MMM').format(promo.startDate)} - ${DateFormat('dd MMM yyyy').format(promo.endDate)}',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: promo.isActive,
                            onChanged: (val) {
                              ref.read(dataServiceProvider).updatePromotion(promo.copyWith(isActive: val));
                            },
                            activeColor: AppColors.adminPrimary,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            onPressed: () => _showAddOfferSheet(existingOffer: promo),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () {
                              ref.read(dataServiceProvider).deletePromotion(promo.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
