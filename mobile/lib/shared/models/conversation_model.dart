import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a 1-on-1 private messaging conversation between a Client and their booked Trainer.
class ConversationModel {
  final String id;
  final String clientId;
  final String trainerId;
  final String bookingId;
  final String trainerName;
  final String? trainerPhotoUrl;
  final String clientName;
  final String? clientPhotoUrl;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime? lastMessageAt;
  final int clientUnreadCount;
  final int trainerUnreadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConversationModel({
    required this.id,
    required this.clientId,
    required this.trainerId,
    this.bookingId = '',
    required this.trainerName,
    this.trainerPhotoUrl,
    required this.clientName,
    this.clientPhotoUrl,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    this.lastMessageAt,
    this.clientUnreadCount = 0,
    this.trainerUnreadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Deterministic conversation ID for a client-trainer pair
  static String generateId(String clientId, String trainerId) {
    return '${clientId}_$trainerId';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'trainerId': trainerId,
      'bookingId': bookingId,
      'trainerName': trainerName,
      'trainerPhotoUrl': trainerPhotoUrl,
      'clientName': clientName,
      'clientPhotoUrl': clientPhotoUrl,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : FieldValue.serverTimestamp(),
      'clientUnreadCount': clientUnreadCount,
      'trainerUnreadCount': trainerUnreadCount,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ConversationModel(
      id: id,
      clientId: map['clientId'] as String? ?? '',
      trainerId: map['trainerId'] as String? ?? '',
      bookingId: map['bookingId'] as String? ?? '',
      trainerName: map['trainerName'] as String? ?? 'Trainer',
      trainerPhotoUrl: map['trainerPhotoUrl'] as String?,
      clientName: map['clientName'] as String? ?? 'Client',
      clientPhotoUrl: map['clientPhotoUrl'] as String?,
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] as String? ?? '',
      lastMessageAt: parseTimestamp(map['lastMessageAt']),
      clientUnreadCount: (map['clientUnreadCount'] as num?)?.toInt() ?? 0,
      trainerUnreadCount: (map['trainerUnreadCount'] as num?)?.toInt() ?? 0,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory ConversationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ConversationModel.fromMap(data, id: doc.id);
  }

  ConversationModel copyWith({
    String? id,
    String? clientId,
    String? trainerId,
    String? bookingId,
    String? trainerName,
    String? trainerPhotoUrl,
    String? clientName,
    String? clientPhotoUrl,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    int? clientUnreadCount,
    int? trainerUnreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      bookingId: bookingId ?? this.bookingId,
      trainerName: trainerName ?? this.trainerName,
      trainerPhotoUrl: trainerPhotoUrl ?? this.trainerPhotoUrl,
      clientName: clientName ?? this.clientName,
      clientPhotoUrl: clientPhotoUrl ?? this.clientPhotoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      clientUnreadCount: clientUnreadCount ?? this.clientUnreadCount,
      trainerUnreadCount: trainerUnreadCount ?? this.trainerUnreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents an individual chat message within a conversation.
class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String text;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.text,
    this.isRead = false,
    this.readAt,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'text': text,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ChatMessageModel(
      id: id,
      conversationId: map['conversationId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      readAt: parseTimestamp(map['readAt']),
      createdAt: parseTimestamp(map['createdAt']),
    );
  }

  factory ChatMessageModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessageModel.fromMap(data, id: doc.id);
  }

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? text,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

