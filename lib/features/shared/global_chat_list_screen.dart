import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/data_service.dart';
import '../../models/order_model.dart';
import '../../core/services/haptic_service.dart';
import '../shared/widgets/skeleton_loaders.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../shared/widgets/chat_coming_soon_view.dart';

class GlobalChatListScreen extends ConsumerWidget {
  const GlobalChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Order Messages', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: const ChatComingSoonView(),
    );
  }
}


/* 
// ORIGINAL CHAT IMPLEMENTATION (DEACTIVATED)
class GlobalChatListScreenOriginal extends ConsumerWidget {
  const GlobalChatListScreenOriginal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold();

    final ds = ref.watch(dataServiceProvider);
    final List<OrderModel> orders = user.isAdmin 
        ? ds.getOrdersWithMessages()
        : ds.getPainterOrdersForChatList(user.id);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Order Messages', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticService.light();
              ds.refresh();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !ds.isLoaded
          ? ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: 8,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => const OrderTileSkeleton(),
            )
          : orders.isEmpty
              ? _buildEmptyState(context, user.isAdmin)
              : AnimationLimiter(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      final lastMsg = ds.getLastMessageForOrder(order.id);

                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          horizontalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildOrderChatTile(
                                context, order, lastMsg, user.isAdmin, ds),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isAdmin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            isAdmin ? 'No active conversations' : 'No order messages yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 8),
            Text(
              'Select an order from history to start a chat',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderChatTile(BuildContext context, OrderModel order, lastMsg, bool isAdmin, DataService ds) {
    return GestureDetector(
      onTap: () {
        HapticService.light();
        context.push('/order/${order.id}/chat');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.forum_outlined, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isAdmin 
                            ? (ds.getUserById(order.painterId)?.name ?? 'Unknown Painter') 
                            : 'ORDER ID: ${order.id.substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: isAdmin ? 0 : 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        lastMsg != null 
                            ? DateFormat('hh:mm a').format(lastMsg.createdAt)
                            : DateFormat('MMM dd').format(order.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg != null ? lastMsg.text : 'Order placed • ₹${order.totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: lastMsg != null ? AppColors.textSecondary : AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
*/

