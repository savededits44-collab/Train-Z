import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../shared/models/support_ticket_model.dart';
import 'notification_service.dart';

/// Dedicated service for Client Support, Complaints, Ticket Tracking,
/// and Ticket Conversations for TRAIN Z.
class SupportService {
  SupportService._internal();
  static final SupportService instance = SupportService._internal();
  factory SupportService() => instance;

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      if (_firestoreInstance != null) return _firestoreInstance;
      if (Firebase.apps.isEmpty) return null;
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String? get _currentAuthUid {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  void setFirestoreForTesting(FirebaseFirestore? firestore) {
    _firestoreInstance = firestore;
  }

  // ── In-Memory Mock Store for Offline Mode and Unit Tests ──
  final Map<String, SupportTicketModel> _mockTickets = {};
  final Map<String, List<SupportMessageModel>> _mockMessages = {};

  void setMockTicket(SupportTicketModel ticket) {
    _mockTickets[ticket.id] = ticket;
    _mockTickets[ticket.ticketNumber] = ticket;
  }

  SupportTicketModel? getMockTicket(String ticketIdOrNumber) => _mockTickets[ticketIdOrNumber];

  void resetMockTickets() {
    _mockTickets.clear();
    _mockMessages.clear();
  }

  static int _ticketCounter = 0;

  // ── Ticket Generation & Formatting Helpers ──
  String generateTicketNumber() {
    _ticketCounter++;
    final now = DateTime.now();
    final millisPart = now.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final pad = millisPart.padLeft(6, '0');
    final suffix = pad.substring(pad.length > 5 ? pad.length - 5 : 0);
    final countPart = (_ticketCounter % 1000).toString().padLeft(3, '0');
    return 'TKT-$suffix$countPart';
  }

  // ── 1. Create a Support Request / Complaint ──
  Future<SupportTicketModel> createTicket({
    required String clientId,
    required String clientName,
    String? clientEmail,
    required SupportTicketCategory category,
    required String subject,
    required String description,
    String? bookingId,
    String? bookingReference,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    if (clientId.trim().isEmpty) {
      throw const SupportException('User must be authenticated to submit a support request.');
    }

    final trimmedSubject = subject.trim();
    if (trimmedSubject.length < 3) {
      throw const SupportException('Subject must be at least 3 characters long.');
    }

    final trimmedDesc = description.trim();
    if (trimmedDesc.length < 10) {
      throw const SupportException('Detailed description must be at least 10 characters long.');
    }

    _ticketCounter++;
    final ticketNumber = generateTicketNumber();
    final micros = DateTime.now().microsecondsSinceEpoch;
    final sanitizedClient = clientId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final ticketId = 'tkt_${micros}_${sanitizedClient}_$_ticketCounter';
    final now = DateTime.now();

    final ticket = SupportTicketModel(
      id: ticketId,
      ticketNumber: ticketNumber,
      clientId: clientId,
      clientName: clientName.trim().isNotEmpty ? clientName.trim() : 'Athlete',
      clientEmail: clientEmail?.trim(),
      category: category,
      subject: trimmedSubject,
      description: trimmedDesc,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      bookingId: bookingId?.trim(),
      bookingReference: bookingReference?.trim(),
      status: SupportTicketStatus.submitted,
      lastMessage: trimmedDesc,
      lastMessageSender: 'CLIENT',
      createdAt: now,
      updatedAt: now,
    );

    final initialMessage = SupportMessageModel(
      id: 'msg_${micros}_$_ticketCounter',
      ticketId: ticketId,
      senderId: clientId,
      senderType: 'CLIENT',
      senderName: ticket.clientName,
      message: trimmedDesc,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      createdAt: now,
      isRead: true,
    );

    // Persist in mock store
    _mockTickets[ticketId] = ticket;
    _mockTickets[ticketNumber] = ticket;
    _mockMessages[ticketId] = [initialMessage];

    // Persist to Firestore if available
    final fs = _firestore;
    if (fs != null) {
      try {
        final batch = fs.batch();
        final ticketRef = fs.collection(FirestoreCollections.supportTickets).doc(ticketId);
        batch.set(ticketRef, ticket.toMap());

        final msgRef = ticketRef.collection(FirestoreCollections.supportMessages).doc(initialMessage.id);
        batch.set(msgRef, initialMessage.toMap());

        await batch.commit();
      } catch (_) {}
    }

    // Send in-app notification confirming receipt
    try {
      await NotificationService.instance.sendNotification(
        userId: clientId,
        title: 'Support Request Received',
        body: 'Ticket #$ticketNumber has been received. Our team will review it shortly.',
        type: 'SUPPORT_TICKET_UPDATE',
        relatedId: ticketId,
        data: {
          'ticketId': ticketId,
          'ticketNumber': ticketNumber,
          'status': 'SUBMITTED',
        },
      );
    } catch (_) {}

    return ticket;
  }

  // ── 2. Stream Client's Tickets (Enforces Ownership) ──
  Stream<List<SupportTicketModel>> streamClientTickets(String clientId) {
    if (clientId.trim().isEmpty) return Stream.value([]);
    final currentUid = _currentAuthUid;
    if (currentUid != null && currentUid.isNotEmpty && currentUid != clientId) {
      return Stream.value([]);
    }
    final fs = _firestore;
    if (fs == null) {
      final list = _mockTickets.values
          .where((t) => t.clientId == clientId)
          .toSet()
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return Stream.value(list);
    }

    try {
      return fs
          .collection(FirestoreCollections.supportTickets)
          .where('clientId', isEqualTo: clientId)
          .snapshots()
          .map((snap) {
            final tickets = snap.docs.map((d) => SupportTicketModel.fromDocument(d)).toList();
            if (tickets.isEmpty) {
              final mockList = _mockTickets.values
                  .where((t) => t.clientId == clientId)
                  .toSet()
                  .toList()
                ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
              return mockList;
            }
            tickets.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
            return tickets;
          })
          .handleError((_) {
            final list = _mockTickets.values
                .where((t) => t.clientId == clientId)
                .toSet()
                .toList()
              ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
            return list;
          });
    } catch (_) {
      final list = _mockTickets.values
          .where((t) => t.clientId == clientId)
          .toSet()
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return Stream.value(list);
    }
  }

  // ── 3. Get Single Ticket with Ownership Guard ──
  Future<SupportTicketModel> getTicketById(String ticketId, String clientId) async {
    if (ticketId.trim().isEmpty || clientId.trim().isEmpty) {
      throw const SupportException('Invalid ticket or client identifier.');
    }

    final currentUid = _currentAuthUid;
    if (currentUid != null && currentUid.isNotEmpty && currentUid != clientId) {
      throw const SupportException('You do not have permission to view this support ticket.');
    }

    final fs = _firestore;
    SupportTicketModel? ticket;

    if (fs != null) {
      try {
        final doc = await fs.collection(FirestoreCollections.supportTickets).doc(ticketId).get();
        if (doc.exists) {
          ticket = SupportTicketModel.fromDocument(doc);
        }
      } catch (_) {}
    }

    ticket ??= _mockTickets[ticketId];

    if (ticket == null) {
      throw const SupportException('Support ticket not found.');
    }

    // Strict access control: clients cannot access other users' tickets
    if (ticket.clientId != clientId) {
      throw const SupportException('You do not have permission to view this support ticket.');
    }

    return ticket;
  }

  // ── 4. Stream Messages for a Ticket ──
  Stream<List<SupportMessageModel>> streamTicketMessages(String ticketId, String clientId) {
    if (ticketId.trim().isEmpty || clientId.trim().isEmpty) {
      return Stream.value([]);
    }

    final currentUid = _currentAuthUid;
    if (currentUid != null && currentUid.isNotEmpty && currentUid != clientId) {
      return Stream.error(const SupportException('Unauthorized access to ticket conversation.'));
    }

    // Verify ticket ownership before streaming
    final mock = _mockTickets[ticketId];
    if (mock != null && mock.clientId != clientId) {
      return Stream.error(const SupportException('Unauthorized access to ticket conversation.'));
    }

    final fs = _firestore;
    if (fs == null) {
      final messages = List<SupportMessageModel>.from(_mockMessages[ticketId] ?? [])
        ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
      return Stream.value(messages);
    }

    try {
      return fs
          .collection(FirestoreCollections.supportTickets)
          .doc(ticketId)
          .collection(FirestoreCollections.supportMessages)
          .snapshots()
          .map((snap) {
            final list = snap.docs.map((d) => SupportMessageModel.fromDocument(d)).toList();
            if (list.isEmpty) {
              final messages = List<SupportMessageModel>.from(_mockMessages[ticketId] ?? [])
                ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
              return messages;
            }
            list.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
            return list;
          })
          .handleError((_) {
            final messages = List<SupportMessageModel>.from(_mockMessages[ticketId] ?? [])
              ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
            return messages;
          });
    } catch (_) {
      final messages = List<SupportMessageModel>.from(_mockMessages[ticketId] ?? [])
        ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
      return Stream.value(messages);
    }
  }

  // ── 5. Send Follow-up Message from Client ──
  Future<SupportMessageModel> sendFollowUpMessage({
    required String ticketId,
    required String clientId,
    required String senderName,
    required String message,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty && (attachmentUrl == null || attachmentUrl.isEmpty)) {
      throw const SupportException('Message text or attachment is required.');
    }

    // Verify ticket ownership and active status
    final ticket = await getTicketById(ticketId, clientId);

    if (ticket.isClosed) {
      throw const SupportException(
        'This ticket is closed. Please submit a new support request if you require further assistance.',
      );
    }

    final now = DateTime.now();
    final msgId = 'msg_${now.millisecondsSinceEpoch}';

    final newMessage = SupportMessageModel(
      id: msgId,
      ticketId: ticketId,
      senderId: clientId,
      senderType: 'CLIENT',
      senderName: senderName.trim().isNotEmpty ? senderName.trim() : 'Athlete',
      message: trimmed,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      createdAt: now,
      isRead: true,
    );

    // Update in mock store
    _mockMessages.putIfAbsent(ticketId, () => []).add(newMessage);
    final updatedTicket = ticket.copyWith(
      lastMessage: trimmed.isNotEmpty ? trimmed : 'Sent an attachment',
      lastMessageSender: 'CLIENT',
      updatedAt: now,
      status: ticket.status == SupportTicketStatus.resolved
          ? SupportTicketStatus.inProgress
          : ticket.status,
    );
    _mockTickets[ticketId] = updatedTicket;
    _mockTickets[updatedTicket.ticketNumber] = updatedTicket;

    // Update Firestore if available
    final fs = _firestore;
    if (fs != null) {
      try {
        final ticketRef = fs.collection(FirestoreCollections.supportTickets).doc(ticketId);
        final msgRef = ticketRef.collection(FirestoreCollections.supportMessages).doc(msgId);

        final batch = fs.batch();
        batch.set(msgRef, newMessage.toMap());
        batch.update(ticketRef, {
          'lastMessage': newMessage.message.isNotEmpty ? newMessage.message : 'Sent an attachment',
          'lastMessageSender': 'CLIENT',
          'updatedAt': FieldValue.serverTimestamp(),
          if (ticket.status == SupportTicketStatus.resolved) 'status': 'IN_PROGRESS',
        });

        await batch.commit();
      } catch (_) {}
    }

    return newMessage;
  }

  // ── 6. Client Closes Ticket ──
  Future<bool> closeTicket({
    required String ticketId,
    required String clientId,
  }) async {
    final ticket = await getTicketById(ticketId, clientId);
    final now = DateTime.now();

    final closed = ticket.copyWith(
      status: SupportTicketStatus.closed,
      closedAt: now,
      updatedAt: now,
    );
    _mockTickets[ticketId] = closed;
    _mockTickets[closed.ticketNumber] = closed;

    final fs = _firestore;
    if (fs != null) {
      try {
        await fs.collection(FirestoreCollections.supportTickets).doc(ticketId).update({
          'status': 'CLOSED',
          'closedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    return true;
  }

  // ── 7. Support / Admin Status Update Helper ──
  Future<void> updateTicketStatus({
    required String ticketId,
    required SupportTicketStatus newStatus,
    String? supportNote,
    String supportAgentName = 'TRAIN Z Support Specialist',
  }) async {
    final ticket = _mockTickets[ticketId];
    final now = DateTime.now();

    if (ticket != null) {
      final updated = ticket.copyWith(
        status: newStatus,
        updatedAt: now,
        resolvedAt: newStatus == SupportTicketStatus.resolved ? now : ticket.resolvedAt,
        closedAt: newStatus == SupportTicketStatus.closed ? now : ticket.closedAt,
        lastMessage: supportNote != null && supportNote.trim().isNotEmpty
            ? supportNote.trim()
            : 'Status updated to ${newStatus.label}',
        lastMessageSender: 'SUPPORT',
      );
      _mockTickets[ticketId] = updated;
      _mockTickets[updated.ticketNumber] = updated;

      if (supportNote != null && supportNote.trim().isNotEmpty) {
        final msg = SupportMessageModel(
          id: 'msg_${now.millisecondsSinceEpoch}',
          ticketId: ticketId,
          senderId: 'support_admin',
          senderType: 'SUPPORT',
          senderName: supportAgentName,
          message: supportNote.trim(),
          createdAt: now,
        );
        _mockMessages.putIfAbsent(ticketId, () => []).add(msg);
      }

      // Notify the client of status update
      try {
        await NotificationService.instance.sendNotification(
          userId: ticket.clientId,
          title: 'Support Ticket #${ticket.ticketNumber} Update',
          body: 'Status has been updated to "${newStatus.label}".',
          type: 'SUPPORT_TICKET_UPDATE',
          relatedId: ticketId,
          data: {
            'ticketId': ticketId,
            'ticketNumber': ticket.ticketNumber,
            'status': newStatus.firestoreValue,
          },
        );
      } catch (_) {}
    }

    final fs = _firestore;
    if (fs != null) {
      try {
        final ticketRef = fs.collection(FirestoreCollections.supportTickets).doc(ticketId);
        final batch = fs.batch();

        final updateData = <String, dynamic>{
          'status': newStatus.firestoreValue,
          'updatedAt': FieldValue.serverTimestamp(),
          if (newStatus == SupportTicketStatus.resolved) 'resolvedAt': FieldValue.serverTimestamp(),
          if (newStatus == SupportTicketStatus.closed) 'closedAt': FieldValue.serverTimestamp(),
        };

        if (supportNote != null && supportNote.trim().isNotEmpty) {
          final msgRef = ticketRef.collection(FirestoreCollections.supportMessages).doc();
          batch.set(msgRef, {
            'id': msgRef.id,
            'ticketId': ticketId,
            'senderId': 'support_admin',
            'senderType': 'SUPPORT',
            'senderName': supportAgentName,
            'message': supportNote.trim(),
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          updateData['lastMessage'] = supportNote.trim();
          updateData['lastMessageSender'] = 'SUPPORT';
        }

        batch.update(ticketRef, updateData);
        await batch.commit();
      } catch (_) {}
    }
  }

  // ── 8. Attachment Validation Helper ──
  void validateAttachmentFile(File file) {
    final length = file.lengthSync();
    if (length > 5 * 1024 * 1024) {
      throw const SupportException('Attachment exceeds the 5MB maximum file size limit.');
    }

    final ext = file.path.split('.').last.toLowerCase();
    const allowed = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
    if (!allowed.contains(ext)) {
      throw const SupportException(
        'Invalid attachment format. Only JPG, PNG, WebP, and PDF documents are supported.',
      );
    }
  }
}
