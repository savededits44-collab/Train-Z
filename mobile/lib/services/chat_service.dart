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

  /// Verifies whether a client is legitimately connected to a trainer via at least one booking.
  Future<bool> hasLegitimateBookingConnection({
    required String clientId,
    required String trainerId,
  }) async {
    if (clientId.trim().isEmpty || trainerId.trim().isEmpty) return false;
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
  Stream<List<ChatMessageModel>> streamMessages(String conversationId) {
    if (_firestore == null || conversationId.trim().isEmpty) {
      return Stream.value([]);
    }

    return _firestore!
        .collection(FirestoreCollections.conversations)
        .doc(conversationId)
        .collection(FirestoreCollections.messages)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => ChatMessageModel.fromDocument(d)).toList();
    });
  }

  /// Streams the total unread message count for a client.
  Stream<int> streamClientTotalUnreadCount(String clientId) {
    return streamClientConversations(clientId).map((conversations) {
      return conversations.fold<int>(0, (total, conv) => total + conv.clientUnreadCount);
    });
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
