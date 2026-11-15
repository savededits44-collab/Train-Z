import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/chat_service.dart';
import '../../services/trainer_client_service.dart';
import '../../shared/models/booking_model.dart';
import '../../shared/models/trainer_client_model.dart';
import 'trainer_conversation_screen.dart';

const Color _kDark = Color(0xFF111111);
const Color _kBg = Color(0xFFF9FAFB);
const Color _kCardBg = Colors.white;
const Color _kCardSubBg = Color(0xFFF3F4F6);
const Color _kLime = Color(0xFFB2FF59);
const Color _kGrey = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFE5E7EB);
const Color _kGreen = Color(0xFF2E7D32);

/// Detailed Client Profile & Private Training Records Screen for Trainers.
class TrainerClientDetailScreen extends StatefulWidget {
  final TrainerClientModel client;
  final String? trainerId;

  const TrainerClientDetailScreen({
    super.key,
    required this.client,
    this.trainerId,
  });

  @override
  State<TrainerClientDetailScreen> createState() => _TrainerClientDetailScreenState();
}

class _TrainerClientDetailScreenState extends State<TrainerClientDetailScreen> with SingleTickerProviderStateMixin {
  late final String _trainerId;
  late TabController _tabController;
  final TrainerClientService _clientService = TrainerClientService.instance;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openChat() async {
    try {
      final conv = await ChatService.instance.getOrCreateConversation(
        clientId: widget.client.clientId,
        trainerId: _trainerId,
        trainerName: 'Trainer',
        clientName: widget.client.name,
        clientPhotoUrl: widget.client.photoUrl,
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
    final client = widget.client;

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
          'Client Details',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kDark,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Message Client',
            icon: const Icon(Iconsax.message, color: _kDark, size: 22),
            onPressed: _openChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Client Profile Header
          _buildClientHeader(client),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: _kDark,
              indicatorWeight: 3,
              labelColor: _kDark,
              unselectedLabelColor: _kGrey,
              labelStyle: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Iconsax.calendar_tick, size: 18),
                  text: 'Sessions',
                ),
                Tab(
                  icon: Icon(Iconsax.note_2, size: 18),
                  text: 'Notes',
                ),
                Tab(
                  icon: Icon(Iconsax.chart_2, size: 18),
                  text: 'Progress',
                ),
              ],
            ),
          ),

          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSessionsTab(client),
                _buildNotesTab(client),
                _buildProgressTab(client),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────

  Widget _buildClientHeader(TrainerClientModel client) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _kCardSubBg,
            child: Text(
              client.displayInitial,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _kDark,
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _kDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: client.isActive
                            ? _kGreen.withValues(alpha: 0.1)
                            : _kGrey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: client.isActive ? _kGreen : _kGrey,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        client.status.displayName.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: client.isActive ? _kGreen : _kGrey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Client since ${client.formattedMemberSince}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: _kGrey,
                  ),
                ),
                if (client.fitnessGoal != null && client.fitnessGoal!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Iconsax.activity, size: 12, color: _kDark),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          client.fitnessGoal!,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: _kGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Sessions & History ──────────────────────────────────────────────

  Widget _buildSessionsTab(TrainerClientModel client) {
    final upcomingBookings = client.bookings.where((b) {
      return b.status == BookingStatus.confirmed &&
          b.sessionDate.isAfter(DateTime.now().subtract(const Duration(minutes: 60)));
    }).toList();

    final completedBookings = client.bookings.where((b) {
      return b.status == BookingStatus.completed;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Active Package Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Training Package',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kCardSubBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${client.remainingSessions} Sessions Left',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                client.packageSummary,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 12),
              // Session Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: client.totalSessions > 0
                      ? (client.completedSessions / client.totalSessions).clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: _kCardSubBg,
                  valueColor: const AlwaysStoppedAnimation<Color>(_kDark),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${client.completedSessions} of ${client.totalSessions} completed',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: _kGrey,
                    ),
                  ),
                  Text(
                    client.totalSessions > 0
                        ? '${((client.completedSessions / client.totalSessions) * 100).round()}% complete'
                        : '',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Upcoming Sessions Section
        const Text(
          'Upcoming Sessions',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 10),

        if (upcomingBookings.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: const Center(
              child: Text(
                'No upcoming confirmed sessions scheduled.',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: _kGrey),
              ),
            ),
          )
        else
          ...upcomingBookings.map((b) => _buildBookingCard(b, isUpcoming: true)),

        const SizedBox(height: 20),

        // Completed Sessions Section
        const Text(
          'Completed Session History',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 10),

        if (completedBookings.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: const Center(
              child: Text(
                'No completed sessions on record yet.',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: _kGrey),
              ),
            ),
          )
        else
          ...completedBookings.map((b) => _buildBookingCard(b, isUpcoming: false)),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBookingCard(BookingModel b, {required bool isUpcoming}) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${b.sessionDate.day} ${months[b.sessionDate.month - 1]} ${b.sessionDate.year}';
    final timeStr = b.startTime.isNotEmpty ? b.startTime : '60 min session';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isUpcoming ? _kLime.withValues(alpha: 0.25) : _kCardSubBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUpcoming ? Iconsax.calendar_tick : Iconsax.tick_circle,
              color: isUpcoming ? const Color(0xFF15803D) : _kGrey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeStr (60 min) • ${b.packageName ?? "General Session"}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: _kGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUpcoming ? _kGreen.withValues(alpha: 0.1) : _kCardSubBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isUpcoming ? 'CONFIRMED' : 'COMPLETED',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isUpcoming ? _kGreen : _kGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Training Notes ──────────────────────────────────────────────────

  Widget _buildNotesTab(TrainerClientModel client) {
    return StreamBuilder<List<TrainerClientNoteModel>>(
      stream: _clientService.streamNotes(
        trainerId: _trainerId,
        clientId: client.clientId,
      ),
      builder: (context, snapshot) {
        final notes = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Privacy Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Iconsax.lock, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Private training notes are visible exclusively to you. Clients cannot access your notes.',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Non-medical Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kCardSubBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: const Row(
                children: [
                  Icon(Iconsax.info_circle, color: _kGrey, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Coaching observations are for workout and form reference only. Do not record medical diagnoses or advice.',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: _kGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Add Note CTA Button
            ElevatedButton.icon(
              onPressed: () => _showAddNoteDialog(client),
              icon: const Icon(Iconsax.add, color: Colors.white, size: 18),
              label: const Text(
                'Add Private Note',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),

            const SizedBox(height: 20),

            if (notes.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  children: [
                    Icon(Iconsax.note_favorite, size: 40, color: _kGrey.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No Training Notes Yet',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Record exercise observations, form feedback, or coaching pointers for this client.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: _kGrey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...notes.map((n) => _buildNoteCard(n)),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildNoteCard(TrainerClientNoteModel note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kCardSubBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  note.category.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    note.formattedCreatedAt,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: _kGrey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: _kGrey),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showEditNoteDialog(note);
                      } else if (val == 'delete') {
                        _confirmDeleteNote(note);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Iconsax.edit, size: 16, color: _kDark),
                            SizedBox(width: 8),
                            Text('Edit Note', style: TextStyle(color: _kDark, fontFamily: 'Outfit', fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Iconsax.trash, size: 16, color: Color(0xFFEF5350)),
                            SizedBox(width: 8),
                            Text('Delete Note', style: TextStyle(color: Color(0xFFEF5350), fontFamily: 'Outfit', fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.title,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note.content,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Training Progress ───────────────────────────────────────────────

  Widget _buildProgressTab(TrainerClientModel client) {
    return StreamBuilder<List<TrainerClientProgressModel>>(
      stream: _clientService.streamProgress(
        trainerId: _trainerId,
        clientId: client.clientId,
      ),
      builder: (context, snapshot) {
        final progressList = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress Stats Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sessions Done',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: _kGrey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${client.completedSessions}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _kDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Milestones',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: _kGrey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${progressList.length}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _kDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Non-medical Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kCardSubBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: const Row(
                children: [
                  Icon(Iconsax.info_circle, color: _kGrey, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Progress records track coaching achievements and exercise mastery. No medical or health claims are made.',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: _kGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Record Milestone Button
            ElevatedButton.icon(
              onPressed: () => _showAddProgressDialog(client),
              icon: const Icon(Iconsax.award, color: Colors.white, size: 18),
              label: const Text(
                'Record Progress Milestone',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),

            const SizedBox(height: 20),

            if (progressList.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  children: [
                    Icon(Iconsax.cup, size: 40, color: _kGrey.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No Milestones Recorded',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track fitness milestones achieved with this client (e.g. attendance streaks, workout PRs, posture improvements).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: _kGrey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...progressList.map((p) => _buildProgressCard(p)),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildProgressCard(TrainerClientProgressModel progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  progress.category.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    progress.formattedAchievedDate,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: _kGrey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Iconsax.trash, size: 16, color: _kGrey),
                    onPressed: () => _confirmDeleteProgress(progress),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            progress.title,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _kDark,
            ),
          ),
          if (progress.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              progress.notes,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Dialogs & Bottom Sheets ────────────────────────────────────────────────

  void _showAddNoteDialog(TrainerClientModel client) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'Observation';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Private Note',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _kGrey),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Category Selector
                Wrap(
                  spacing: 8,
                  children: ['Observation', 'Session', 'Form & Technique', 'General'].map((cat) {
                    final isSel = category == cat;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSel ? Colors.white : _kDark,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: _kDark,
                      backgroundColor: _kCardSubBg,
                      onSelected: (val) {
                        if (val) setModalState(() => category = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: _kDark, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    labelText: 'Topic / Title',
                    labelStyle: const TextStyle(color: _kGrey, fontFamily: 'Outfit'),
                    hintText: 'e.g. Core stability progress',
                    hintStyle: TextStyle(color: _kGrey.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: _kCardSubBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: _kDark, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    labelText: 'Observation Details *',
                    labelStyle: const TextStyle(color: _kGrey, fontFamily: 'Outfit'),
                    hintText: 'Note details on form, endurance, stamina, or workout focus...',
                    hintStyle: TextStyle(color: _kGrey.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: _kCardSubBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      try {
                        await _clientService.addNote(
                          trainerId: _trainerId,
                          clientId: client.clientId,
                          title: titleCtrl.text,
                          content: contentCtrl.text,
                          category: category,
                        );
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Private note saved successfully.')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: const Color(0xFFEF5350),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Save Note',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditNoteDialog(TrainerClientNoteModel note) {
    final titleCtrl = TextEditingController(text: note.title);
    final contentCtrl = TextEditingController(text: note.content);
    String category = note.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Note',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _kGrey),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Observation', 'Session', 'Form & Technique', 'General'].map((cat) {
                    final isSel = category == cat;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSel ? Colors.white : _kDark,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: _kDark,
                      backgroundColor: _kCardSubBg,
                      onSelected: (val) {
                        if (val) setModalState(() => category = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: _kDark, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    labelText: 'Topic / Title',
                    labelStyle: const TextStyle(color: _kGrey, fontFamily: 'Outfit'),
                    filled: true,
                    fillColor: _kCardSubBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contentCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: _kDark, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    labelText: 'Observation Details *',
                    labelStyle: const TextStyle(color: _kGrey, fontFamily: 'Outfit'),
                    filled: true,
                    fillColor: _kCardSubBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      try {
                        await _clientService.updateNote(
                          noteId: note.id,
                          trainerId: _trainerId,
                          title: titleCtrl.text,
                          content: contentCtrl.text,
                          category: category,
                        );
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Note updated successfully.')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: const Color(0xFFEF5350),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Update Note',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteNote(TrainerClientNoteModel note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Delete Note',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: _kDark),
        ),
        content: const Text(
          'Are you sure you want to permanently delete this private note?',
          style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: _kGrey, fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              try {
                await _clientService.deleteNote(noteId: note.id, trainerId: _trainerId);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Note deleted.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error deleting note: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showAddProgressDialog(TrainerClientModel client) {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Milestone';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Record Milestone',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _kGrey),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Milestone', 'Workout / Exercise', 'Goal Progress', 'Consistency'].map((cat) {
                    final isSel = category == cat;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSel ? Colors.white : _kDark,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: _kDark,
                      backgroundColor: _kCardSubBg,
                      onSelected: (val) {
                        if (val) setModalState(() => category = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: _kDark, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    labelText: 'Milestone Title *',
                    labelStyle: const TextStyle(color: _kGrey, fontFamily: 'Outfit'),
                    hintText: 'e.g. Mastered Deep Squat Technique',
                    hintStyle: TextStyle(color: _kGrey.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: _kCardSubBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: _kDark, fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    labelText: 'Details / Coaching Notes',
                    labelStyle: const TextStyle(color: _kGrey, fontFamily: 'Outfit'),
                    hintText: 'Observed milestones, repetitions, form consistency...',
                    hintStyle: TextStyle(color: _kGrey.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: _kCardSubBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);
                      try {
                        await _clientService.addProgress(
                          trainerId: _trainerId,
                          clientId: client.clientId,
                          title: titleCtrl.text,
                          notes: notesCtrl.text,
                          category: category,
                          achievedDate: selectedDate,
                        );
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Progress milestone recorded.')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: const Color(0xFFEF5350),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Save Milestone',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteProgress(TrainerClientProgressModel progress) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Delete Milestone',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: _kDark),
        ),
        content: const Text(
          'Are you sure you want to delete this recorded milestone?',
          style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: _kGrey, fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              try {
                await _clientService.deleteProgress(progressId: progress.id, trainerId: _trainerId);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Milestone deleted.')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error deleting milestone: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
