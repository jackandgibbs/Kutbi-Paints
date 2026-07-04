import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoadingProducts extends StatelessWidget {
  final int count;
  
  const ShimmerLoadingProducts({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.55,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top color box
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title lines
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade100,
                        child: Container(height: 14, width: double.infinity, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade100,
                        child: Container(height: 14, width: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      
                      // Chips
                      Row(
                        children: [
                          Shimmer.fromColors(
                            baseColor: Colors.grey.shade200,
                            highlightColor: Colors.grey.shade100,
                            child: Container(height: 20, width: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                          ),
                          const SizedBox(width: 4),
                          Shimmer.fromColors(
                            baseColor: Colors.grey.shade200,
                            highlightColor: Colors.grey.shade100,
                            child: Container(height: 20, width: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Price line
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade100,
                        child: Container(height: 16, width: 100, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      
                      // Button
                      Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          height: 32,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
