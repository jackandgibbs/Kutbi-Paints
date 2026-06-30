import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/data_service.dart';
import '../../models/product_model.dart';
import 'dart:math' as math;

class SmartSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  SmartSearchDelegate(this.ref)
      : super(
          searchFieldLabel: 'Ask AI "red exterior paint"',
          searchFieldStyle: GoogleFonts.poppins(fontSize: 14),
        );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return _buildSuggestionsHelper();
    }
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return _buildSuggestionsHelper();
    }
    return _buildSearchResults(context);
  }

  Widget _buildSuggestionsHelper() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              Text(
                'AI Search Suggestions',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _suggestionChip('white emulsion'),
              _suggestionChip('red exterior paint'),
              _suggestionChip('premium blue'),
              _suggestionChip('matte finish'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      labelStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF4F46E5)),
      backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => query = text,
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    // "AI" fuzzy matching logic
    final ds = ref.read(dataServiceProvider);
    final allProducts = ds.getAllProducts();
    
    final normalizedQuery = query.toLowerCase();
    
    // Scoring logic for AI search
    final scoredProducts = <ProductModel, int>{};
    
    for (final p in allProducts) {
      int score = 0;
      final name = p.name.toLowerCase();
      final colorName = p.colorName.toLowerCase();
      final brand = p.brand.toLowerCase();
      
      // Direct matches
      if (name.contains(normalizedQuery)) score += 10;
      if (colorName.contains(normalizedQuery)) score += 15;
      if (p.colorCode.toLowerCase() == normalizedQuery) score += 20;
      
      // Natural language keywords matching
      final queryWords = normalizedQuery.split(' ');
      for (final word in queryWords) {
        if (word.length <= 2) continue; // Skip very short words like 'is', 'a', etc.
        
        if (name.contains(word)) score += 3;
        if (colorName.contains(word)) score += 5;
        if (brand.contains(word)) score += 2;
        
        // Semantic matching (mocked simple logic)
        if (word == 'exterior' && name.contains('exterior')) score += 8;
        if (word == 'interior' && name.contains('interior')) score += 8;
        if (word == 'red' && (colorName.contains('red') || colorName.contains('crimson') || colorName.contains('rose'))) score += 8;
        if (word == 'blue' && (colorName.contains('blue') || colorName.contains('navy') || colorName.contains('sky'))) score += 8;
        if (word == 'premium' && (name.contains('royale') || name.contains('luxury') || name.contains('premium'))) score += 5;
      }
      
      if (score > 0) {
        scoredProducts[p] = score;
      }
    }
    
    final sortedResults = scoredProducts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    final results = sortedResults.map((e) => e.key).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No matches found for "$query"',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final product = results[index];
        final brandColor = AppColors.getBrandPrimary(product.brand);
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () {
              close(context, null);
              context.push('/painter/order-item/${product.id}');
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _hexToColor(product.colorHex),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${product.brand} • ${product.colorName}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_shopping_cart_rounded, size: 20, color: brandColor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
