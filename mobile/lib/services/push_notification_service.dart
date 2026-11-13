import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../core/constants/firestore_collections.dart';
import '../features/client/presentation/screens/client_account_security_screen.dart';
import '../features/client/presentation/screens/client_booking_detail_screen.dart';
import '../features/client/presentation/screens/client_chat_screen.dart';
import '../features/client/presentation/screens/client_notifications_screen.dart';
import '../features/client/presentation/screens/client_payment_history_screen.dart';
import '../features/client/presentation/screens/client_support_tickets_screen.dart';
import '../shared/models/conversation_model.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

/// Top-level background message handler for FCM.
/// Must be outside of any class and annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId} - ${message.data}');
}

/// Centralized Push Notification Service for TRAIN Z.
/// Manages FCM token registration, permission requests, and deep-link routing
/// across foreground, background, and terminated application states.
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();
  factory PushNotificationService() => instance;
  PushNotificationService._internal();

  /// Global navigator key for notification tap routing
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging? get _messaging {
    try {
      _messagingInstance ??= FirebaseMessaging.instance;
      return _messagingInstance;
    } catch (e) {
      debugPrint('FCM instance unavailable: $e');
      return null;
    }
  }

  bool _initialized = false;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  String? get currentToken => _currentToken;

  /// Initializes FCM listeners, requests permissions, and handles cold-launch taps.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final fcm = _messaging;
    if (fcm == null) return;

    try {
      // Set background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request notification permissions
      final settings = await fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM authorization status: ${settings.authorizationStatus}');

      // Enable foreground display options
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Modern FCM registration
      _tokenRefreshSub = fcm.onRegistered.listen((newToken) {
        _currentToken = newToken;
        _syncTokenWithCurrentUser(newToken);
      });
      await fcm.register();

      // Fallback for environments where register() has completed
      // ignore: deprecated_member_use
      _currentToken ??= await fcm.getToken();
      if (_currentToken != null) {
        debugPrint('FCM Device Token retrieved: $_currentToken');
        _syncTokenWithCurrentUser(_currentToken!);
      }

      // Handle foreground notifications
      _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // Handle tap on notification when app was in background
      _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        handleNotificationNavigation(message.data);
      });

      // Handle tap on notification when app was terminated (cold launch)
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        // Small delay to ensure the widget tree is mounted
        Future.delayed(const Duration(milliseconds: 600), () {
          handleNotificationNavigation(initialMessage.data);
        });
      }
    } catch (e) {
      debugPrint('FCM initialization notice: $e');
    }
  }

  /// Syncs the device token to the currently signed-in user's Firestore record.
  Future<void> _syncTokenWithCurrentUser(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await registerDeviceToken(user.uid, token: token);
      }
    } catch (e) {
      debugPrint('Error syncing FCM token with user: $e');
    }
  }

  /// Public API to register a device token under `users/{uid}`
  Future<void> registerDeviceToken(String uid, {String? token}) async {
    if (uid.trim().isEmpty) return;
    // ignore: deprecated_member_use
    final fcmToken = token ?? _currentToken ?? await _messaging?.getToken();
    if (fcmToken == null || fcmToken.isEmpty) return;

    try {
      final userRef = FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(uid);
      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([fcmToken]),
        'fcmToken': fcmToken,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FCM token registered for user: $uid');
    } catch (e) {
      debugPrint('Error writing FCM token to Firestore: $e');
    }
  }

  /// Removes a token on logout
  Future<void> unregisterDeviceToken(String uid) async {
    if (uid.trim().isEmpty || _currentToken == null) return;
    try {
      final userRef = FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(uid);
      await userRef.update({
        'fcmTokens': FieldValue.arrayRemove([_currentToken]),
      });
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }
  }

  /// Handles a message received while the app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground FCM received: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Add to in-app NotificationService so the notification centre updates immediately
    NotificationService.instance.sendNotification(
      userId: currentUid,
      title: notification.title ?? 'TRAIN Z Update',
      body: notification.body ?? '',
      type: data['type'] as String? ?? 'GENERAL',
      data: data,
    );

    // If context is available, show an in-app banner/snackBar
    final navContext = navigatorKey.currentContext;
    if (navContext != null) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title ?? 'New Notification',
                style: const TextStyle(
                  fontFamily: 'Syne',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (notification.body != null)
                Text(
                  notification.body!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
          backgroundColor: const Color(0xFF0D1117),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: const Color(0xFFCCFF00),
            onPressed: () => handleNotificationNavigation(data),
          ),
        ),
      );
    }
  }

  /// Routes to the relevant screen based on the notification data payload
  Future<void> handleNotificationNavigation(Map<String, dynamic> data) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final type = data['type'] as String? ?? '';
    final bookingId = data['bookingId'] as String? ?? data['relatedId'] as String?;
    final conversationId = data['conversationId'] as String?;

    // 1. Chat Message routing
    if (type == 'CHAT_MESSAGE' || (conversationId != null && conversationId.isNotEmpty)) {
      final convId = conversationId ?? '';
      final trainerId = data['trainerId'] as String? ?? '';
      final trainerName = data['trainerName'] as String? ?? 'Trainer';
      final trainerPhotoUrl = data['trainerPhotoUrl'] as String?;
      final clientUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      nav.push(
        MaterialPageRoute(
          builder: (_) => ClientChatScreen(
            conversation: ConversationModel(
              id: convId.isNotEmpty ? convId : ConversationModel.generateId(clientUid, trainerId),
              clientId: clientUid,
              trainerId: trainerId,
              trainerName: trainerName,
              trainerPhotoUrl: trainerPhotoUrl,
              clientName: FirebaseAuth.instance.currentUser?.displayName ?? 'Athlete',
            ),
          ),
        ),
      );
      return;
    }

    // 2. Booking related routing
    if (bookingId != null && bookingId.isNotEmpty) {
      try {
        final booking = await FirestoreService().getBooking(bookingId);
        if (booking != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => ClientBookingDetailScreen(booking: booking),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Error navigating to booking: $e');
      }
    }

    // 3. Support ticket routing
    final ticketId = data['ticketId'] as String? ?? data['supportTicketId'] as String?;
    if (type.startsWith('SUPPORT_') || ticketId != null) {
      final user = FirebaseAuth.instance.currentUser;
      final currentUid = user?.uid ?? '';
      final clientName = user?.displayName ?? 'Athlete';
      final clientEmail = user?.email;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ClientSupportTicketsScreen(
            clientId: currentUid,
            clientName: clientName,
            clientEmail: clientEmail,
          ),
        ),
      );
      return;
    }

    // 4. Payment / package routing
    final paymentId = data['paymentId'] as String?;
    if (type.startsWith('PAYMENT_') || type.startsWith('PACKAGE_') || paymentId != null) {
      final user = FirebaseAuth.instance.currentUser;
      final currentUid = user?.uid ?? '';
      nav.push(
        MaterialPageRoute(
          builder: (_) => ClientPaymentHistoryScreen(clientId: currentUid),
        ),
      );
      return;
    }

    // 5. Account security routing
    if (type.contains('SECURITY')) {
      final user = FirebaseAuth.instance.currentUser;
      final currentUid = user?.uid ?? '';
      final clientEmail = user?.email ?? '';
      final isEmailVerified = user?.emailVerified ?? false;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ClientAccountSecurityScreen(
            clientId: currentUid,
            userEmail: clientEmail,
            isEmailVerified: isEmailVerified,
          ),
        ),
      );
      return;
    }

    // 6. Fallback: navigate to Notification Centre
    nav.push(
      MaterialPageRoute(
        builder: (_) => const ClientNotificationsScreen(),
      ),
    );
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _messageOpenedSub?.cancel();
  }
}
