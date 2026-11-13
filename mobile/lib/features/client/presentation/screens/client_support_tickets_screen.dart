import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../services/support_service.dart';
import '../../../../shared/models/support_ticket_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'client_submit_ticket_screen.dart';
import 'client_support_detail_screen.dart';

/// Support Request Tracking screen where Clients can view, filter,
/// and track all their submitted support tickets and complaints.
class ClientSupportTicketsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String? clientEmail;

  const ClientSupportTicketsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.clientEmail,
  });

  @override
  State<ClientSupportTicketsScreen> createState() => _ClientSupportTicketsScreenState();
}

class _ClientSupportTicketsScreenState extends State<ClientSupportTicketsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.05).clamp(16.0, 24.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Support Tickets',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (18.0 * sf).clamp(16.0, 20.0),
            fontWeight: FontWeight.w800,
            color: kDark,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_circle, color: kDark, size: 22),
            tooltip: 'New Support Request',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientSubmitTicketScreen(
                    clientId: widget.clientId,
                    clientName: widget.clientName,
                    clientEmail: widget.clientEmail,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kDark,
          unselectedLabelColor: const Color(0xFF888888),
          indicatorColor: kDark,
          indicatorWeight: 2.5,
          labelStyle: TextStyle(
            fontFamily: 'Syne',
            fontSize: (13.0 * sf).clamp(12.0, 14.5),
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (12.0 * sf).clamp(11.0, 13.5),
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Resolved / Closed'),
          ],
        ),
      ),
      body: StreamBuilder<List<SupportTicketModel>>(
        stream: SupportService.instance.streamClientTickets(widget.clientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kDark));
          }

          final allTickets = snapshot.data ?? [];
          final activeTickets = allTickets.where((t) => t.isActive).toList();
          final resolvedTickets = allTickets.where((t) => !t.isActive).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTicketList(allTickets, 'No support tickets found', sf, hPad),
              _buildTicketList(activeTickets, 'No active support requests', sf, hPad),
              _buildTicketList(resolvedTickets, 'No resolved or closed tickets', sf, hPad),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientSubmitTicketScreen(
                clientId: widget.clientId,
                clientName: widget.clientName,
                clientEmail: widget.clientEmail,
              ),
            ),
          );
        },
        backgroundColor: kDark,
        foregroundColor: kLime,
        icon: const Icon(Iconsax.add, size: 18),
        label: const Text(
          'New Request',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildTicketList(List<SupportTicketModel> tickets, String emptyMsg, double sf, double hPad) {
    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.ticket, size: 36, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 14),
              Text(
                emptyMsg,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (15.0 * sf).clamp(14.0, 17.0),
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Have a question, feedback, or training issue? Tap below to submit a support request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientSubmitTicketScreen(
                        clientId: widget.clientId,
                        clientName: widget.clientName,
                        clientEmail: widget.clientEmail,
                      ),
                    ),
                  );
                },
                icon: const Icon(Iconsax.add, size: 16, color: kDark),
                label: const Text(
                  'Submit a Request',
                  style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 13, color: kDark),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLime,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 80),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return _buildTicketCard(ticket, sf);
      },
    );
  }

  Widget _buildTicketCard(SupportTicketModel ticket, double sf) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientSupportDetailScreen(
              ticket: ticket,
              clientId: widget.clientId,
              clientName: widget.clientName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Ticket ID pill + Category Chip + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: kDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ticket.ticketNumber,
                        style: const TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: kLime,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ticket.category.label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(ticket.status),
              ],
            ),

            const SizedBox(height: 10),

            // Subject
            Text(
              ticket.subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: (14.0 * sf).clamp(13.0, 16.0),
                fontWeight: FontWeight.w800,
                color: kDark,
              ),
            ),

            const SizedBox(height: 6),

            // Latest Response / Message preview
            Text(
              ticket.lastMessage ?? ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: (11.0 * sf).clamp(10.0, 12.5),
                color: const Color(0xFF6B7280),
                height: 1.35,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),

            // Bottom metadata row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.clock, size: 12, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Text(
                      ticket.formattedDate,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    if (ticket.hasRelatedBooking) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          ticket.bookingReference!,
                          style: const TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF9CA3AF)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SupportTicketStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status.color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
