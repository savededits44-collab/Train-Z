import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/chat_service.dart';
import '../../services/trainer_client_service.dart';
import '../../shared/models/trainer_client_model.dart';
import 'trainer_client_detail_screen.dart';
import 'trainer_conversation_screen.dart';

const Color _kDark = Color(0xFF111111);
const Color _kBg = Color(0xFFF9FAFB);
const Color _kCardBg = Colors.white;
const Color _kCardSubBg = Color(0xFFF3F4F6);
const Color _kGrey = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kGreen = Color(0xFF15803D);

enum ClientFilterTab { all, active, past }

/// Dedicated My Clients Management Screen for Trainers.
class TrainerClientsScreen extends StatefulWidget {
  final String? trainerId;
  final bool showAppBar;

  const TrainerClientsScreen({
    super.key,
    this.trainerId,
    this.showAppBar = true,
  });

  @override
  State<TrainerClientsScreen> createState() => _TrainerClientsScreenState();
}

class _TrainerClientsScreenState extends State<TrainerClientsScreen> {
  late final String _trainerId;
  final TrainerClientService _clientService = TrainerClientService.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  ClientFilterTab _selectedTab = ClientFilterTab.all;
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

  Future<void> _openChat(TrainerClientModel client) async {
    try {
      final conv = await ChatService.instance.getOrCreateConversation(
        clientId: client.clientId,
        trainerId: _trainerId,
        trainerName: 'Trainer',
        clientName: client.name,
        clientPhotoUrl: client.photoUrl,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainerConversationScreen(
            conversation: conv,
            trainerId: _trainerId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open conversation: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: _kDark, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'My Clients',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
            )
          : null,
      body: StreamBuilder<List<TrainerClientModel>>(
        stream: _clientService.streamClientsForTrainer(_trainerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _kDark),
            );
          }

          final allClients = snapshot.data ?? [];

          // Metrics calculation
          final activeCount = allClients.where((c) => c.isActive).length;
          final totalCompletedSessions = allClients.fold<int>(0, (sum, c) => sum + c.completedSessions);

          // Filtering
          TrainerClientStatus? statusFilter;
          if (_selectedTab == ClientFilterTab.active) {
            statusFilter = TrainerClientStatus.active;
          } else if (_selectedTab == ClientFilterTab.past) {
            statusFilter = TrainerClientStatus.past;
          }

          final filteredClients = _clientService.filterClients(
            allClients,
            query: _searchQuery,
            statusFilter: statusFilter,
          );

          return SafeArea(
            top: !widget.showAppBar,
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
                          _buildStatCard(
                            label: 'Total Athletes',
                            value: '${allClients.length}',
                            icon: Iconsax.people,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            label: 'Active Athletes',
                            value: '$activeCount',
                            icon: Iconsax.user_tick,
                            highlight: true,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            label: 'Sessions Done',
                            value: '$totalCompletedSessions',
                            icon: Iconsax.calendar_tick,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Search Field
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(color: _kDark, fontFamily: 'Outfit', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search by athlete name, package, or goal...',
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          prefixIcon: const Icon(Iconsax.search_normal, color: Color(0xFF9CA3AF), size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 18),
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

                      const SizedBox(height: 10),

                      // Filter Segment Tabs
                      Row(
                        children: [
                          _buildFilterTab(
                            title: 'All Athletes (${allClients.length})',
                            tab: ClientFilterTab.all,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterTab(
                            title: 'Active ($activeCount)',
                            tab: ClientFilterTab.active,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterTab(
                            title: 'Past (${allClients.length - activeCount})',
                            tab: ClientFilterTab.past,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Client List / Empty State
                Expanded(
                  child: filteredClients.isEmpty
                      ? _buildEmptyState(allClients.isEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];
                            return _buildClientCard(client);
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

  // ── Stat Card ──────────────────────────────────────────────────────────────

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlight ? const Color(0xFFBBF7D0) : _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: highlight ? _kGreen : _kGrey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      color: highlight ? _kGreen : _kGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: highlight ? _kGreen : _kDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter Tab ─────────────────────────────────────────────────────────────

  Widget _buildFilterTab({
    required String title,
    required ClientFilterTab tab,
  }) {
    final isSelected = _selectedTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _kDark : _kCardSubBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? _kDark : _kBorder),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : _kDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // ── Client Card ────────────────────────────────────────────────────────────

  Widget _buildClientCard(TrainerClientModel client) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
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
          // Header Row: Avatar, Name, Status Pill, Chat Shortcut
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _kCardSubBg,
                child: Text(
                  client.displayInitial,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            client.name,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: client.isActive
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            client.status.displayName.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: client.isActive ? _kGreen : _kGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.packageSummary,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: _kGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Message Client shortcut
              IconButton(
                tooltip: 'Message Client',
                icon: const Icon(Iconsax.message, color: _kDark, size: 20),
                onPressed: () => _openChat(client),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Details Box: Next Session & Last Session
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.calendar_tick, size: 14, color: _kDark),
                    const SizedBox(width: 8),
                    const Text(
                      'Next Session:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: _kGrey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        client.formattedNextSession,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: client.hasUpcomingSession ? _kDark : _kGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Iconsax.tick_circle, size: 14, color: _kGrey),
                    const SizedBox(width: 8),
                    const Text(
                      'Last Completed:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: _kGrey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        client.formattedLastSession,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (client.remainingSessions > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${client.remainingSessions} Left',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Primary Action: View Details & Notes
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrainerClientDetailScreen(
                      client: client,
                      trainerId: _trainerId,
                    ),
                  ),
                );
              },
              icon: const Icon(Iconsax.profile_circle, size: 16, color: Colors.white),
              label: const Text(
                'View Profile, Notes & Milestones',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDark,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool noClientsOverall) {
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
              child: const Icon(Iconsax.people, size: 48, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 18),
            Text(
              noClientsOverall ? 'No Connected Athletes Yet' : 'No Matching Athletes',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              noClientsOverall
                  ? 'Athletes with active or past confirmed bookings will appear here automatically.'
                  : 'Try adjusting your search query or switching filters between Active and Past.',
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
