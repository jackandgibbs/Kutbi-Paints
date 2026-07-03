import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

final cartProvider = StateNotifierProvider<CartService, List<CartItemModel>>((ref) {
  return CartService();
});

class CartService extends StateNotifier<List<CartItemModel>> {
  CartService() : super([]);

  void addItem(ProductModel product, String bucketSize, {String? shadeCode, int quantity = 1}) {
    final qty = quantity < 1 ? 1 : quantity;
    final existingIndex = state.indexWhere((item) =>
      item.productId == product.id &&
      item.bucketSize == bucketSize &&
      item.shadeCode == shadeCode
    );

    if (existingIndex != -1) {
      final updatedList = List<CartItemModel>.from(state);
      updatedList[existingIndex] = updatedList[existingIndex]
          .copyWith(quantity: updatedList[existingIndex].quantity + qty);
      state = updatedList;
    } else {
      state = [
        ...state,
        CartItemModel(
          productId: product.id,
          productName: product.name,
          productImageUrl: product.imageUrl ?? '',
          bucketSize: bucketSize,
          shadeCode: shadeCode,
          price: product.prices[bucketSize] ?? 0.0,
          quantity: qty,
        ),
      ];
    }
  }

  void removeItem(String productId, String bucketSize, {String? shadeCode}) {
    state = state.where((item) => 
      !(item.productId == productId && 
        item.bucketSize == bucketSize && 
        item.shadeCode == shadeCode)
    ).toList();
  }

  void updateQuantity(String productId, String bucketSize, int quantity, {String? shadeCode}) {
    if (quantity <= 0) {
      removeItem(productId, bucketSize, shadeCode: shadeCode);
      return;
    }
    
    state = state.map((item) {
      if (item.productId == productId && 
          item.bucketSize == bucketSize && 
          item.shadeCode == shadeCode) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
  }

  void clear() {
    state = [];
  }

  double get totalAmount => state.fold(0, (sum, item) => sum + item.total);
  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);
}
