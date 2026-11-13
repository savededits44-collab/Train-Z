import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/support_service.dart';
import '../../../../shared/models/support_ticket_model.dart';
import '../../../../widgets/app_widgets.dart';

/// Detailed view and structured conversation thread for a single support ticket.
class ClientSupportDetailScreen extends StatefulWidget {
  final SupportTicketModel ticket;
  final String clientId;
  final String clientName;

  const ClientSupportDetailScreen({
    super.key,
    required this.ticket,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientSupportDetailScreen> createState() => _ClientSupportDetailScreenState();
}

class _ClientSupportDetailScreenState extends State<ClientSupportDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late SupportTicketModel _currentTicket;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);
    HapticFeedback.lightImpact();

    try {
      await SupportService.instance.sendFollowUpMessage(
        ticketId: _currentTicket.id,
        clientId: widget.clientId,
        senderName: widget.clientName,
        message: text,
      );

      // Auto-scroll to bottom of conversation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleCloseTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Close Support Ticket?', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text(
          'Mark this ticket as closed? You can always submit a new support request if you experience another issue.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close Ticket', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupportService.instance.closeTicket(
        ticketId: _currentTicket.id,
        clientId: widget.clientId,
      );
      setState(() {
        _currentTicket = _currentTicket.copyWith(status: SupportTicketStatus.closed);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket closed successfully.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to close ticket: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final isClosed = _currentTicket.isClosed;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              _currentTicket.ticketNumber,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (16.0 * sf).clamp(15.0, 18.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),
            Text(
              _currentTicket.category.label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (!isClosed)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: kDark),
              onSelected: (val) {
                if (val == 'close') _handleCloseTicket();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'close',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                      SizedBox(width: 8),
                      Text('Mark as Resolved / Close', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Ticket Header Overview Card ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _currentTicket.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (13.5 * sf).clamp(12.5, 15.0),
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(_currentTicket.status),
                  ],
                ),
                if (_currentTicket.hasRelatedBooking) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Iconsax.calendar_1, size: 12, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        'Related Booking: ${_currentTicket.bookingReference}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Conversation Thread ──
          Expanded(
            child: StreamBuilder<List<SupportMessageModel>>(
              stream: SupportService.instance.streamTicketMessages(_currentTicket.id, widget.clientId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: kDark));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg, sf);
                  },
                );
              },
            ),
          ),

          // ── Reply Bar or Closed Advisory ──
          if (isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This ticket has been marked as closed. To report another issue, please raise a new support request.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: TextField(
                          controller: _messageController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSendMessage(),
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Type follow-up response...',
                            hintStyle: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            color: kDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: kDark,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kLime),
                              )
                            : const Icon(Icons.send_rounded, size: 18, color: kLime),
                        onPressed: _isSending ? null : _handleSendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(SupportMessageModel msg, double sf) {
    final isClient = msg.isClient;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isClient) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: kDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.headphone, size: 14, color: kLime),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isClient ? kDark : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isClient ? 14 : 2),
                  bottomRight: Radius.circular(isClient ? 2 : 14),
                ),
                border: isClient ? null : Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: isClient
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isClient ? 'You' : 'TRAIN Z Support',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isClient ? kLime : const Color(0xFF2563EB),
                        ),
                      ),
                      if (!isClient) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 10, color: Color(0xFF2563EB)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.message,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (12.0 * sf).clamp(11.0, 13.0),
                      color: isClient ? Colors.white : kDark,
                      height: 1.35,
                    ),
                  ),
                  if (msg.attachmentName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isClient ? const Color(0xFF222222) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attachment, size: 12, color: isClient ? kLime : kDark),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              msg.attachmentName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: isClient ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    msg.formattedTime,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: isClient ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isClient) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildStatusPill(SupportTicketStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: status.color,
        ),
      ),
    );
  }
}
