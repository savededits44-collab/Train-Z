import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/chat_service.dart';
import '../../../../shared/models/conversation_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Professional 1-on-1 messaging screen between a Client and their booked Personal Trainer.
class ClientChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ClientChatScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends State<ClientChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService.instance;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _chatService.markConversationAsRead(
          conversationId: widget.conversation.id,
          currentUserId: uid,
          isClient: true,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    String uid = widget.conversation.clientId;
    String senderName = widget.conversation.clientName;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        uid = user.uid;
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          senderName = user.displayName!;
        }
      }
    } catch (_) {}

    setState(() => _isSending = true);
    _textController.clear();
    HapticFeedback.lightImpact();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: uid,
        senderName: senderName,
        receiverId: widget.conversation.trainerId,
        text: text,
        isClient: true,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    String myUid = widget.conversation.clientId;
    try {
      myUid = FirebaseAuth.instance.currentUser?.uid ?? widget.conversation.clientId;
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: kDark,
                  backgroundImage: (widget.conversation.trainerPhotoUrl != null &&
                          widget.conversation.trainerPhotoUrl!.isNotEmpty)
                      ? NetworkImage(widget.conversation.trainerPhotoUrl!)
                      : null,
                  child: (widget.conversation.trainerPhotoUrl == null ||
                          widget.conversation.trainerPhotoUrl!.isEmpty)
                      ? Text(
                          widget.conversation.trainerName.isNotEmpty
                              ? widget.conversation.trainerName[0].toUpperCase()
                              : 'T',
                          style: const TextStyle(
                            fontFamily: 'Syne',
                            color: kLime,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.trainerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (14.5 * sf).clamp(13.5, 16.0),
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                  Text(
                    'Personal Trainer • Active',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (10.0 * sf).clamp(9.5, 11.5),
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (10.5 * sf).clamp(9.5, 11.5),
                    fontWeight: FontWeight.w600,
                    color: kDark,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEEEEEE), height: 1),
        ),
      ),
      body: Column(
        children: [
          // Security policy reminder banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF0FDF4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 12, color: Color(0xFF15803D)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Private 1-on-1 Fitness Chat for booked training sessions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (10.0 * sf).clamp(9.0, 11.0),
                      color: const Color(0xFF166534),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages stream
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatService.streamMessages(widget.conversation.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kDark));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return _buildConversationStarter(sf);
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myUid;
                    final showDateDivider = _shouldShowDateDivider(messages, index);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateDivider) _buildDateDivider(msg.createdAt, sf),
                        _buildMessageBubble(msg, isMe, sf),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Input Bar
          _buildInputBar(sf),
        ],
      ),
    );
  }

  Widget _buildConversationStarter(double sf) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: kDark,
            backgroundImage: (widget.conversation.trainerPhotoUrl != null &&
                    widget.conversation.trainerPhotoUrl!.isNotEmpty)
                ? NetworkImage(widget.conversation.trainerPhotoUrl!)
                : null,
            child: (widget.conversation.trainerPhotoUrl == null ||
                    widget.conversation.trainerPhotoUrl!.isEmpty)
                ? Text(
                    widget.conversation.trainerName.isNotEmpty
                        ? widget.conversation.trainerName[0].toUpperCase()
                        : 'T',
                    style: const TextStyle(fontFamily: 'Syne', fontSize: 28, color: kLime, fontWeight: FontWeight.w800),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            widget.conversation.trainerName,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (18.0 * sf).clamp(16.0, 20.0),
              fontWeight: FontWeight.w800,
              color: kDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personal Trainer',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: (12.0 * sf).clamp(11.0, 13.0),
              color: kGrey,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              children: [
                const Icon(Iconsax.message_tick, size: 28, color: kDark),
                const SizedBox(height: 10),
                Text(
                  'Connected for Training',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: (13.5 * sf).clamp(12.5, 15.0),
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use this channel to coordinate session locations, discuss workout preferences, or notify your trainer about scheduling updates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (11.0 * sf).clamp(10.0, 12.0),
                    color: const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateDivider(List<ChatMessageModel> list, int index) {
    if (index == 0) return true;
    final prev = list[index - 1].createdAt;
    final curr = list[index].createdAt;
    if (prev == null || curr == null) return false;
    return prev.day != curr.day || prev.month != curr.month || prev.year != curr.year;
  }

  Widget _buildDateDivider(DateTime? date, double sf) {
    if (date == null) return const SizedBox.shrink();
    final now = DateTime.now();
    String label;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day} ${_monthName(date.month)} ${date.year}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (10.0 * sf).clamp(9.0, 11.0),
            color: const Color(0xFF4B5563),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe, double sf) {
    final timeStr = msg.createdAt != null ? _formatTime(msg.createdAt!) : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: isMe ? kDark : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (12.5 * sf).clamp(11.5, 14.0),
                color: isMe ? Colors.white : const Color(0xFF111827),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: (9.0 * sf).clamp(8.5, 10.0),
                    color: isMe ? Colors.white60 : const Color(0xFF9CA3AF),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead ? Icons.done_all : Icons.done,
                    size: 13,
                    color: msg.isRead ? kLime : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(double sf) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (12.5 * sf).clamp(11.5, 14.0),
                  color: kDark,
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _sendMessage,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: kDark,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kLime),
                      ),
                    )
                  : const Center(
                      child: Icon(Iconsax.send_1, size: 18, color: kLime),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }
}
