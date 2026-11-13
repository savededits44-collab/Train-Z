import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/chat_service.dart';
import '../../shared/models/conversation_model.dart';
import '../../shared/models/trainer_client_model.dart';
import 'trainer_client_detail_screen.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kCardSubBg = Color(0xFF23262F);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);

/// Dedicated 1-on-1 Conversation Screen for Trainers communicating with booked Clients.
class TrainerConversationScreen extends StatefulWidget {
  final ConversationModel conversation;
  final String? trainerId;

  const TrainerConversationScreen({
    super.key,
    required this.conversation,
    this.trainerId,
  });

  @override
  State<TrainerConversationScreen> createState() => _TrainerConversationScreenState();
}

class _TrainerConversationScreenState extends State<TrainerConversationScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ChatService _chatService = ChatService.instance;

  late final String _trainerId;
  bool _isSending = false;
  String? _errorMessage;

  // Pagination support
  final List<ChatMessageModel> _historicalMessages = [];
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        widget.conversation.trainerId;
    _markRead();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _markRead() {
    try {
      if (_trainerId.isNotEmpty) {
        _chatService.markConversationAsRead(
          conversationId: widget.conversation.id,
          currentUserId: _trainerId,
          isClient: false,
        );
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadOlderMessages(DateTime oldestDate) async {
    if (_isLoadingOlder || !_hasMoreOlder) return;
    setState(() => _isLoadingOlder = true);

    try {
      final older = await _chatService.fetchOlderMessages(
        widget.conversation.id,
        beforeDate: oldestDate,
        limit: 25,
      );

      if (!mounted) return;
      setState(() {
        if (older.isEmpty) {
          _hasMoreOlder = false;
        } else {
          _historicalMessages.insertAll(0, older);
        }
        _isLoadingOlder = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOlder = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    _textCtrl.clear();
    HapticFeedback.lightImpact();

    String trainerDisplayName = widget.conversation.trainerName;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.displayName != null && user!.displayName!.isNotEmpty) {
        trainerDisplayName = user.displayName!;
      }
    } catch (_) {}

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _trainerId,
        senderName: trainerDisplayName,
        receiverId: widget.conversation.clientId,
        text: text,
        isClient: false,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to send: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _openClientProfile() {
    final clientModel = TrainerClientModel(
      clientId: widget.conversation.clientId,
      name: widget.conversation.clientName,
      photoUrl: widget.conversation.clientPhotoUrl,
      activePackageName: 'Booked Client',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerClientDetailScreen(
          client: clientModel,
          trainerId: _trainerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.conversation.clientName;
    final initial = clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: _openClientProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kLime.withValues(alpha: 0.2),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _kLime,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF66BB6A)),
                        SizedBox(width: 4),
                        Text(
                          'Booked Athlete • Active',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: _kGrey,
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
        actions: [
          IconButton(
            tooltip: 'Client Records',
            icon: const Icon(Iconsax.profile_circle, color: Colors.white, size: 22),
            onPressed: _openClientProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Professional Privacy Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: _kCardBg,
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: const Row(
                children: [
                  Icon(Iconsax.shield_tick, color: _kLime, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Private 1-on-1 coaching chat. Restricted to booked session inquiries.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: _kGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Messages Stream
            Expanded(
              child: StreamBuilder<List<ChatMessageModel>>(
                stream: _chatService.streamMessages(widget.conversation.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: _kLime));
                  }

                  final liveMessages = snapshot.data ?? [];
                  final allMessages = [..._historicalMessages, ...liveMessages];

                  if (allMessages.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Automatically trigger mark as read when new incoming messages arrive
                  _markRead();
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: allMessages.length + (_hasMoreOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_hasMoreOlder && index == 0) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _isLoadingOlder
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _kLime),
                                  )
                                : TextButton.icon(
                                    onPressed: () {
                                      final oldest = allMessages.first.createdAt ?? DateTime.now();
                                      _loadOlderMessages(oldest);
                                    },
                                    icon: const Icon(Icons.history, size: 14, color: _kGrey),
                                    label: const Text(
                                      'Load older messages',
                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: _kGrey),
                                    ),
                                  ),
                          ),
                        );
                      }

                      final msgIndex = _hasMoreOlder ? index - 1 : index;
                      final msg = allMessages[msgIndex];
                      final isMe = msg.senderId == _trainerId;

                      // Date separator check
                      bool showDateHeader = false;
                      if (msgIndex == 0) {
                        showDateHeader = true;
                      } else {
                        final prevMsg = allMessages[msgIndex - 1];
                        if (msg.createdAt != null && prevMsg.createdAt != null) {
                          showDateHeader = msg.createdAt!.day != prevMsg.createdAt!.day ||
                              msg.createdAt!.month != prevMsg.createdAt!.month ||
                              msg.createdAt!.year != prevMsg.createdAt!.year;
                        }
                      }

                      return Column(
                        children: [
                          if (showDateHeader && msg.createdAt != null)
                            _buildDateSeparator(msg.createdAt!),
                          _buildMessageBubble(msg, isMe),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFFEF5350).withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF5350)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFFEF5350)),
                      ),
                    ),
                  ],
                ),
              ),

            // Text Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── Date Separator ─────────────────────────────────────────────────────────

  Widget _buildDateSeparator(DateTime dt) {
    final now = DateTime.now();
    String text;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      text = 'Today';
    } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      text = 'Yesterday';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      text = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _kCardSubBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: _kGrey, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Message Bubble ─────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe) {
    final timeStr = msg.createdAt != null
        ? '${msg.createdAt!.hour.toString().padLeft(2, '0')}:${msg.createdAt!.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF263238) : _kCardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
          border: Border.all(
            color: isMe ? _kLime.withValues(alpha: 0.3) : _kBorder,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                color: Colors.white,
                height: 1.4,
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
                    fontSize: 10,
                    color: _kGrey.withValues(alpha: 0.8),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 13,
                    color: msg.isRead ? _kLime : _kGrey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Input Bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: _kCardBg,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Type a message to your athlete...',
                hintStyle: TextStyle(color: _kGrey.withValues(alpha: 0.6), fontSize: 13),
                filled: true,
                fillColor: _kCardSubBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _kLime),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _kLime,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kDark),
                    )
                  : const Icon(Iconsax.send_1, size: 20, color: _kDark),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
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
              child: const Icon(Iconsax.message, size: 44, color: _kLime),
            ),
            const SizedBox(height: 16),
            Text(
              'Direct Chat with ${widget.conversation.clientName}',
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Send a welcome message or coordinate training location and session preparation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kGrey),
            ),
          ],
        ),
      ),
    );
  }
}

