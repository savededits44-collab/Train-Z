import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/chat_service.dart';
import '../../shared/models/conversation_model.dart';
import 'trainer_conversation_screen.dart';

const Color _kDark = Color(0xFF111111);
const Color _kBg = Color(0xFFF9FAFB);
const Color _kCardBg = Colors.white;
const Color _kCardSubBg = Color(0xFFF3F4F6);
const Color _kGrey = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFE5E7EB);

/// Dedicated Messages Screen for Trainers to manage all active 1-on-1 client conversations.
class TrainerMessagesScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerMessagesScreen({
    super.key,
    this.trainerId,
  });

  @override
  State<TrainerMessagesScreen> createState() => _TrainerMessagesScreenState();
}

class _TrainerMessagesScreenState extends State<TrainerMessagesScreen> {
  late final String _trainerId;
  final ChatService _chatService = ChatService.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Yesterday';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Client Messages',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kDark,
          ),
        ),
      ),
      body: StreamBuilder<List<ConversationModel>>(
        stream: _chatService.streamTrainerConversations(_trainerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _kDark));
          }

          final allConversations = snapshot.data ?? [];
          final filtered = _chatService.filterConversations(allConversations, query: _searchQuery);

          // Unread message calculation
          final totalUnread = allConversations.fold<int>(0, (sum, c) => sum + c.trainerUnreadCount);

          return SafeArea(
            child: Column(
              children: [
                // Top Search and Stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: _kBorder)),
                  ),
                  child: Column(
                    children: [
                      // Stats Overview Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _kCardSubBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Iconsax.messages_2, color: _kDark, size: 18),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Conversations',
                                        style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: _kGrey),
                                      ),
                                      Text(
                                        '${allConversations.length}',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _kDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _kCardSubBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: totalUnread > 0 ? const Color(0xFFEF5350).withValues(alpha: 0.5) : _kBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Iconsax.message_notif,
                                    color: totalUnread > 0 ? const Color(0xFFEF5350) : _kGrey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Unread Messages',
                                        style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: _kGrey),
                                      ),
                                      Text(
                                        '$totalUnread',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: totalUnread > 0 ? const Color(0xFFEF5350) : _kDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Search Box
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(color: _kDark, fontFamily: 'Outfit', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search by athlete name or message...',
                          hintStyle: TextStyle(color: _kGrey.withValues(alpha: 0.6), fontSize: 13),
                          prefixIcon: const Icon(Iconsax.search_normal, color: _kGrey, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: _kGrey, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: _kCardSubBg,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Conversation List
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(allConversations.isEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final conv = filtered[index];
                            return _buildConversationCard(conv);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Conversation Card ──────────────────────────────────────────────────────

  Widget _buildConversationCard(ConversationModel conv) {
    final clientName = conv.clientName;
    final initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C';
    final hasUnread = conv.trainerUnreadCount > 0;
    final timeStr = _formatTimestamp(conv.lastMessageAt ?? conv.updatedAt ?? conv.createdAt);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrainerConversationScreen(
              conversation: conv,
              trainerId: _trainerId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread ? _kDark : _kBorder,
            width: hasUnread ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: hasUnread ? _kDark : _kCardSubBg,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: hasUnread ? Colors.white : _kDark,
                    ),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          clientName,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w600,
                            color: _kDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: hasUnread ? _kDark : _kGrey,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessage.isNotEmpty
                              ? (conv.lastMessageSenderId == _trainerId ? 'You: ${conv.lastMessage}' : conv.lastMessage)
                              : 'New booked conversation',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            color: hasUnread ? _kDark : _kGrey,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conv.trainerUnreadCount}',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool noConversationsOverall) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kCardBg,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Iconsax.messages_2, size: 48, color: _kGrey),
            ),
            const SizedBox(height: 18),
            Text(
              noConversationsOverall ? 'No Conversations Yet' : 'No Matching Messages',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              noConversationsOverall
                  ? 'Direct 1-on-1 messaging is active for clients who have booked training sessions with you.'
                  : 'Try searching with a different athlete name or keyword.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: _kGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

