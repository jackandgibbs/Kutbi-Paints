import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

import '../shared/widgets/chat_coming_soon_view.dart';

class OrderChatScreen extends ConsumerWidget {
  final String orderId;
  const OrderChatScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Notes / Chat', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Order #${orderId.substring(0, 8).toUpperCase()}', 
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: const ChatComingSoonView(),
    );
  }
}


/* 
// ORIGINAL CHAT IMPLEMENTATION (DEACTIVATED)
class OrderChatScreenOriginal extends ConsumerStatefulWidget {
  final String orderId;
  const OrderChatScreenOriginal({super.key, required this.orderId});

  @override
  ConsumerState<OrderChatScreenOriginal> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreenOriginal> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      await ref.read(dataServiceProvider).sendMessage(
            orderId: widget.orderId,
            senderId: user.id,
            text: text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dataServiceProvider);
    final currentUser = ref.watch(authProvider).user;
    final messages = ds.getMessagesForOrder(widget.orderId);
    
    // Auto-scroll on new messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && 
          _scrollController.position.pixels < _scrollController.position.maxScrollExtent - 100) {
        // Only auto scroll if user is near bottom
      } else {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Notes / Chat', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Order #${widget.orderId.substring(0, 8).toUpperCase()}', 
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticService.light();
              ref.read(dataServiceProvider).refresh();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Send a note about this order.',
                      style: GoogleFonts.poppins(color: AppColors.textLight),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUser?.id;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                              bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${ds.getUserById(msg.senderId)?.name ?? 'Unknown'} (${ds.getUserById(msg.senderId)?.role == 'admin' ? 'Admin' : 'Painter'})',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              Text(
                                msg.text,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isMe ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  DateFormat('h:mm a').format(msg.createdAt),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isMe ? Colors.white70 : AppColors.textLight,
                                  ),
                                ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Chat Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.scaffoldBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
*/

