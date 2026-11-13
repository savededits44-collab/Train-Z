import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/conversation_model.dart';

/// Exception thrown when an unauthorized user attempts to access or create a conversation.
class MessagingPermissionException implements Exception {
  final String message;
  const MessagingPermissionException(this.message);

  @override
  String toString() => 'MessagingPermissionException: $message';
}

/// Real-time chat service for TRAIN Z.
/// Manages 1-on-1 private messaging between clients and their booked trainers,
/// strictly enforcing that communication is permitted ONLY between parties
/// legitimately connected through TRAIN Z bookings.
class ChatService {
  static final ChatService instance = ChatService._internal();
  factory ChatService() => instance;
  ChatService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  // ── In-Memory Testing Support ──────────────────────────────────────────────
  bool _isTestMode = false;
  final List<ConversationModel> _testConversations = [];
  final Map<String, List<ChatMessageModel>> _testMessages = {};
  final Set<String> _testConnectedPairs = {};
  final StreamController<List<ConversationModel>> _convsStreamController =
      StreamController<List<ConversationModel>>.broadcast();
  final Map<String, StreamController<List<ChatMessageModel>>> _messagesControllers = {};

  @visibleForTesting
  void resetForTest() {
    _isTestMode = true;
    _testConversations.clear();
    _testMessages.clear();
    _testConnectedPairs.clear();
  }

  @visibleForTesting
  void setTestConversations(List<ConversationModel> convs) {
    _isTestMode = true;
    _testConversations
      ..clear()
      ..addAll(convs);
    _convsStreamController.add(List.unmodifiable(_testConversations));
  }

  @visibleForTesting
  void setTestBookingConnection(String clientId, String trainerId, bool connected) {
    _isTestMode = true;
    final pair = '${clientId}_$trainerId';
    if (connected) {
      _testConnectedPairs.add(pair);
    } else {
      _testConnectedPairs.remove(pair);
    }
  }

  @visibleForTesting
  void setTestMessages(String conversationId, List<ChatMessageModel> messages) {
    _isTestMode = true;
    _testMessages[conversationId] = List.from(messages);
    _getOrCreateMessageController(conversationId).add(List.unmodifiable(messages));
  }

  StreamController<List<ChatMessageModel>> _getOrCreateMessageController(String convId) {
    return _messagesControllers.putIfAbsent(convId, () => StreamController<List<ChatMessageModel>>.broadcast());
  }

  /// Verifies whether a client is legitimately connected to a trainer via at least one booking.
  Future<bool> hasLegitimateBookingConnection({
    required String clientId,
    required String trainerId,
  }) async {
    if (clientId.trim().isEmpty || trainerId.trim().isEmpty) return false;

    if (_isTestMode) {
      final pair = '${clientId}_$trainerId';
      if (_testConnectedPairs.contains(pair)) return true;
      return _testConversations.any((c) => c.clientId == clientId && c.trainerId == trainerId);
    }

    if (_firestore == null) return false;

    try {
      final snap = await _firestore!
          .collection(FirestoreCollections.bookings)
          .where('clientId', isEqualTo: clientId)
          .where('trainerId', isEqualTo: trainerId)
          .limit(1)
          .get();

      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking booking connection: $e');
      return false;
    }
  }

  /// Retrieves an existing conversation or creates one if a legitimate booking exists.
  /// Throws [MessagingPermissionException] if no booking connection exists.
  Future<ConversationModel> getOrCreateConversation({
    required String clientId,
    required String trainerId,
    required String trainerName,
    String? trainerPhotoUrl,
    required String clientName,
    String? clientPhotoUrl,
    String? bookingId,
  }) async {
    if (clientId.trim().isEmpty || trainerId.trim().isEmpty) {
      throw const MessagingPermissionException('Invalid client or trainer ID.');
    }

    // Permission enforcement: verify legitimate booking connection
    final isConnected = await hasLegitimateBookingConnection(
      clientId: clientId,
      trainerId: trainerId,
    );

    if (!isConnected) {
      throw const MessagingPermissionException(
        'Messaging is restricted to trainers you have legitimately booked on TRAIN Z.',
      );
    }

    final convId = ConversationModel.generateId(clientId, trainerId);
    if (_isTestMode) {
      final existingIndex = _testConversations.indexWhere((c) => c.id == convId);
      if (existingIndex >= 0) {
        return _testConversations[existingIndex];
      }
      final newConv = ConversationModel(
        id: convId,
        clientId: clientId,
        trainerId: trainerId,
        bookingId: bookingId ?? '',
        trainerName: trainerName,
        trainerPhotoUrl: trainerPhotoUrl,
        clientName: clientName,
        clientPhotoUrl: clientPhotoUrl,
        lastMessage: '',
        lastMessageSenderId: '',
        lastMessageAt: DateTime.now(),
        clientUnreadCount: 0,
        trainerUnreadCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _testConversations.add(newConv);
      _convsStreamController.add(List.unmodifiable(_testConversations));
      return newConv;
    }

    if (_firestore == null) {
      return ConversationModel(
        id: convId,
        clientId: clientId,
        trainerId: trainerId,
        bookingId: bookingId ?? '',
        trainerName: trainerName,
        trainerPhotoUrl: trainerPhotoUrl,
        clientName: clientName,
        clientPhotoUrl: clientPhotoUrl,
      );
    }

    final convRef = _firestore!.collection(FirestoreCollections.conversations).doc(convId);
    final snap = await convRef.get();

    if (snap.exists) {
      final existing = ConversationModel.fromDocument(snap);
      // Update names or photos if updated
      final needsUpdate = existing.trainerName != trainerName ||
          existing.trainerPhotoUrl != trainerPhotoUrl ||
          existing.clientName != clientName ||
          existing.clientPhotoUrl != clientPhotoUrl;

      if (needsUpdate) {
        await convRef.update({
          'trainerName': trainerName,
          'trainerPhotoUrl': trainerPhotoUrl,
          'clientName': clientName,
          'clientPhotoUrl': clientPhotoUrl,
          if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
        });
      }
      return existing.copyWith(
        trainerName: trainerName,
        trainerPhotoUrl: trainerPhotoUrl,
        clientName: clientName,
        clientPhotoUrl: clientPhotoUrl,
        bookingId: (bookingId != null && bookingId.isNotEmpty) ? bookingId : existing.bookingId,
      );
    }

    // Create new conversation
    final newConv = ConversationModel(
      id: convId,
      clientId: clientId,
      trainerId: trainerId,
      bookingId: bookingId ?? '',
      trainerName: trainerName,
      trainerPhotoUrl: trainerPhotoUrl,
      clientName: clientName,
      clientPhotoUrl: clientPhotoUrl,
      lastMessage: '',
      lastMessageSenderId: '',
      lastMessageAt: DateTime.now(),
      clientUnreadCount: 0,
      trainerUnreadCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await convRef.set(newConv.toMap());
    return newConv;
  }

  /// Streams real-time conversations for a specific client.
  Stream<List<ConversationModel>> streamClientConversations(String clientId) {
    if (_firestore == null || clientId.trim().isEmpty) {
      return Stream.value([]);
    }

    return _firestore!
        .collection(FirestoreCollections.conversations)
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => ConversationModel.fromDocument(d)).toList();
      // Sort in memory by updatedAt / lastMessageAt descending
      list.sort((a, b) {
        final aTime = a.updatedAt ?? a.lastMessageAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? b.lastMessageAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Streams real-time conversations for a specific trainer.
  Stream<List<ConversationModel>> streamTrainerConversations(String trainerId) {
    if (_isTestMode) {
      final list = _testConversations.where((c) => c.trainerId == trainerId).toList();
      list.sort((a, b) {
        final aTime = a.updatedAt ?? a.lastMessageAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? b.lastMessageAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return Stream.value(List.unmodifiable(list));
    }

    if (_firestore == null || trainerId.trim().isEmpty) {
      return Stream.value([]);
    }

    return _firestore!
        .collection(FirestoreCollections.conversations)
        .where('trainerId', isEqualTo: trainerId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => ConversationModel.fromDocument(d)).toList();
      list.sort((a, b) {
        final aTime = a.updatedAt ?? a.lastMessageAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? b.lastMessageAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Streams real-time messages within a conversation.
  Stream<List<ChatMessageModel>> streamMessages(String conversationId, {int limit = 50}) {
    if (_isTestMode) {
      final msgs = _testMessages[conversationId] ?? [];
      final limited = msgs.length > limit ? msgs.sublist(msgs.length - limit) : msgs;
      return Stream.value(List.unmodifiable(limited));
    }

    if (_firestore == null || conversationId.trim().isEmpty) {
      return Stream.value([]);
    }

    return _firestore!
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.messages)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => ChatMessageModel.fromDocument(d)).toList();
    });
  }

  /// Fetches older messages before a specific timestamp for pagination.
  Future<List<ChatMessageModel>> fetchOlderMessages(
    String conversationId, {
    required DateTime beforeDate,
    int limit = 20,
  }) async {
    if (_isTestMode) {
      final msgs = _testMessages[conversationId] ?? [];
      final older = msgs.where((m) => m.createdAt != null && m.createdAt!.isBefore(beforeDate)).toList();
      return older.length > limit ? older.sublist(older.length - limit) : older;
    }

    if (_firestore == null || conversationId.trim().isEmpty) {
      return [];
    }

    try {
      final snap = await _firestore!
          .collection(FirestoreCollections.conversations)
          .doc(conversationId)
          .collection(FirestoreCollections.messages)
          .where('createdAt', isLessThan: Timestamp.fromDate(beforeDate))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final list = snap.docs.map((d) => ChatMessageModel.fromDocument(d)).toList();
      return list.reversed.toList();
    } catch (e) {
      debugPrint('Error fetching older messages: $e');
      return [];
    }
  }

  /// Streams the total unread message count for a client.
  Stream<int> streamClientTotalUnreadCount(String clientId) {
    return streamClientConversations(clientId).map((conversations) {
      return conversations.fold<int>(0, (total, conv) => total + conv.clientUnreadCount);
    });
  }

  /// Streams the total unread message count for a trainer across all active client conversations.
  Stream<int> streamTrainerTotalUnreadCount(String trainerId) {
    return streamTrainerConversations(trainerId).map((conversations) {
      return conversations.fold<int>(0, (total, conv) => total + conv.trainerUnreadCount);
    });
  }

  /// Filters conversations by client name or latest message text.
  List<ConversationModel> filterConversations(
    List<ConversationModel> list, {
    String query = '',
  }) {
    if (query.trim().isEmpty) return list;
    final q = query.trim().toLowerCase();
    return list.where((c) {
      final nameMatch = c.clientName.toLowerCase().contains(q);
      final msgMatch = c.lastMessage.toLowerCase().contains(q);
      return nameMatch || msgMatch;
    }).toList();
  }

  /// Sends a new message in the conversation.
  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String receiverId,
    required String text,
    bool isClient = true,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw ArgumentError('Message text cannot be empty.');
    }

    final now = DateTime.now();
    final msgRef = _firestore
        ?.collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.messages)
        .doc();

    final msgId = msgRef?.id ?? 'msg_${now.millisecondsSinceEpoch}';
    final chatMsg = ChatMessageModel(
      id: msgId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      text: cleanText,
      isRead: false,
      createdAt: now,
    );

    if (_isTestMode) {
      _testMessages.putIfAbsent(conversationId, () => []).add(chatMsg);
      final convIndex = _testConversations.indexWhere((c) => c.id == conversationId);
      if (convIndex >= 0) {
        final existing = _testConversations[convIndex];
        _testConversations[convIndex] = existing.copyWith(
          lastMessage: cleanText,
          lastMessageSenderId: senderId,
          lastMessageAt: now,
          updatedAt: now,
          clientUnreadCount: isClient ? existing.clientUnreadCount : existing.clientUnreadCount + 1,
          trainerUnreadCount: isClient ? existing.trainerUnreadCount + 1 : existing.trainerUnreadCount,
        );
        _convsStreamController.add(List.unmodifiable(_testConversations));
      }
      _getOrCreateMessageController(conversationId).add(List.unmodifiable(_testMessages[conversationId]!));
      return chatMsg;
    }

    if (_firestore != null && msgRef != null) {
      final batch = _firestore!.batch();
      batch.set(msgRef, chatMsg.toMap());

      // Update parent conversation
      final convRef = _firestore!.collection(FirestoreCollections.conversations).doc(conversationId);
      final updateData = <String, dynamic>{
        'lastMessage': cleanText,
        'lastMessageSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isClient) {
        updateData['trainerUnreadCount'] = FieldValue.increment(1);
      } else {
        updateData['clientUnreadCount'] = FieldValue.increment(1);
      }

      batch.update(convRef, updateData);
      await batch.commit();
    }

    return chatMsg;
  }

  /// Marks a conversation and its messages as read for the current user.
  Future<void> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
    required bool isClient,
  }) async {
    if (_isTestMode) {
      final convIndex = _testConversations.indexWhere((c) => c.id == conversationId);
      if (convIndex >= 0) {
        final existing = _testConversations[convIndex];
        _testConversations[convIndex] = existing.copyWith(
          clientUnreadCount: isClient ? 0 : existing.clientUnreadCount,
          trainerUnreadCount: isClient ? existing.trainerUnreadCount : 0,
        );
        _convsStreamController.add(List.unmodifiable(_testConversations));
      }
      final msgs = _testMessages[conversationId] ?? [];
      for (int i = 0; i < msgs.length; i++) {
        if (msgs[i].receiverId == currentUserId && !msgs[i].isRead) {
          msgs[i] = msgs[i].copyWith(isRead: true, readAt: DateTime.now());
        }
      }
      _getOrCreateMessageController(conversationId).add(List.unmodifiable(msgs));
      return;
    }

    if (_firestore == null || conversationId.trim().isEmpty) return;

    try {
      final convRef = _firestore!.collection(FirestoreCollections.conversations).doc(conversationId);
      await convRef.update({
        if (isClient) 'clientUnreadCount': 0 else 'trainerUnreadCount': 0,
      });

      // Mark unread messages delivered to this user as read
      final unreadSnap = await convRef
          .collection(FirestoreCollections.messages)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadSnap.docs.isNotEmpty) {
        final batch = _firestore!.batch();
        for (final doc in unreadSnap.docs) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking conversation read: $e');
    }
  }
}
