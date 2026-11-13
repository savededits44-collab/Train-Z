import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/notification_model.dart';
import '../shared/models/notification_preferences_model.dart';

/// Real-time in-app notification service for Train-Z.
/// Synchronizes notifications between clients and trainers via Cloud Firestore.
class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal() {
    _initAuthListener();
  }

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot>? _firestoreSub;

  final List<NotificationModel> _notifications = [];
  final StreamController<List<NotificationModel>> _streamController =
      StreamController<List<NotificationModel>>.broadcast();

  // Deduplication cache: key = "$userId:$type:$relatedId", value = timestamp
  final Map<String, DateTime> _recentNotificationCache = {};

  // Notification category preferences per user
  final Map<String, NotificationPreferencesModel> _userPreferences = {};

  void setUserPreferences(String userId, NotificationPreferencesModel prefs) {
    _userPreferences[userId] = prefs;
  }

  NotificationPreferencesModel getUserPreferences(String userId) {
    return _userPreferences[userId] ?? const NotificationPreferencesModel();
  }

  /// Completely purges cached notifications and user preferences on logout
  void clearCache() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    _notifications.clear();
    _userPreferences.clear();
    _recentNotificationCache.clear();
    _notify();
  }

  // Testing support
  bool _isTestMode = false;
  final List<NotificationModel> _testNotifications = [];

  List<NotificationModel> get notifications => List.unmodifiable(_isTestMode ? _testNotifications : _notifications);
  Stream<List<NotificationModel>> get stream => _streamController.stream;
  int get unreadCount => (_isTestMode ? _testNotifications : _notifications).where((n) => !n.isRead).length;

  @visibleForTesting
  void resetForTest() {
    _isTestMode = true;
    _testNotifications.clear();
    _recentNotificationCache.clear();
  }

  @visibleForTesting
  void setTestNotifications(List<NotificationModel> items) {
    _isTestMode = true;
    _testNotifications
      ..clear()
      ..addAll(items);
    _streamController.add(List.unmodifiable(_testNotifications));
    notifyListeners();
  }

  /// Streams notifications specifically for a trainer.
  Stream<List<NotificationModel>> streamNotificationsForTrainer(String trainerId) async* {
    if (_isTestMode) {
      List<NotificationModel> getList() {
        final list = _testNotifications.where((n) => n.userId == trainerId).toList();
        list.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return List.unmodifiable(list);
      }

      yield getList();
      await for (final _ in _streamController.stream) {
        yield getList();
      }
      return;
    }

    if (_firestore == null || trainerId.trim().isEmpty) {
      yield notifications.where((n) => n.userId == trainerId).toList();
      await for (final _ in _streamController.stream) {
        yield notifications.where((n) => n.userId == trainerId).toList();
      }
      return;
    }

    yield* _firestore!
        .collection(FirestoreCollections.notifications)
        .where('userId', isEqualTo: trainerId)
        .snapshots()
        .map((snap) {
      final items = snap.docs.map((d) => NotificationModel.fromDocument(d)).toList();
      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return items;
    });
  }

  /// Filters a notification list by category.
  List<NotificationModel> filterByCategory(
    List<NotificationModel> list,
    NotificationCategory category,
  ) {
    if (category == NotificationCategory.all) return list;
    return list.where((n) => n.categoryEnum == category).toList();
  }

  /// Deletes a single notification.
  Future<void> deleteNotification(String notificationId) async {
    if (_isTestMode) {
      _testNotifications.removeWhere((n) => n.id == notificationId);
      _streamController.add(List.unmodifiable(_testNotifications));
      notifyListeners();
      return;
    }

    _notifications.removeWhere((n) => n.id == notificationId);
    _notify();

    try {
      await _firestore
          ?.collection(FirestoreCollections.notifications)
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Notice: Error deleting notification: $e');
    }
  }

  void _initAuthListener() {
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _subscribeToNotifications(user.uid);
        } else {
          _firestoreSub?.cancel();
          _notifications.clear();
          _notify();
        }
      });
    } catch (e) {
      debugPrint('Notice: FirebaseAuth inactive in tests: $e');
    }
  }

  void _subscribeToNotifications(String uid) {
    if (_firestore == null) return;
    _firestoreSub?.cancel();
    try {
      _firestoreSub = _firestore!
          .collection(FirestoreCollections.notifications)
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen(
        (snapshot) {
          final items = snapshot.docs.map((d) => NotificationModel.fromDocument(d)).toList();
          // Sort descending by creation date
          items.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          _notifications.clear();
          _notifications.addAll(items);
          _notify();
        },
        onError: (err) {
          debugPrint('Notice: Notification stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Notice: Error subscribing to notifications: $e');
    }
  }

  /// Sends a real-time notification to a specific user with automatic deduplication
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    if (userId.trim().isEmpty) return;

    // Deduplication check: prevent identical notification within 30 seconds
    final cacheKey = '$userId:$type:${relatedId ?? ""}';
    final now = DateTime.now();
    if (_recentNotificationCache.containsKey(cacheKey)) {
      final lastSent = _recentNotificationCache[cacheKey]!;
      if (now.difference(lastSent).inSeconds < 30) {
        debugPrint('Deduplication: suppressing duplicate notification $cacheKey');
        return;
      }
    }
    _recentNotificationCache[cacheKey] = now;

    // Category preferences check: respect client disabled categories (security is never disabled)
    final userPrefs = _userPreferences[userId];
    if (userPrefs != null && !userPrefs.isCategoryEnabled(type)) {
      debugPrint('Notification suppressed by user preference: type=$type, userId=$userId');
      return;
    }

    final docRef = _firestore?.collection(FirestoreCollections.notifications).doc();
    final docId = docRef?.id ?? 'notif_${now.millisecondsSinceEpoch}';
    final notif = NotificationModel(
      id: docId,
      userId: userId,
      title: title,
      body: body,
      type: type,
      isRead: false,
      data: {
        ...?data,
        ...?relatedId != null ? {'relatedId': relatedId} : null,
      },
      createdAt: now,
    );

    // If recipient is current user (or offline/testing without Firestore), update memory immediately for 0ms latency
    String? currentUid;
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    if (currentUid == userId || _firestore == null) {
      _notifications.insert(0, notif);
      _notify();
    }

    try {
      if (docRef != null) {
        await docRef.set(notif.toMap());
      }
    } catch (e) {
      debugPrint('Notice: Error saving notification to Firestore: $e');
    }
  }

  /// Marks a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    if (_isTestMode) {
      final idx = _testNotifications.indexWhere((n) => n.id == notificationId);
      if (idx >= 0) {
        _testNotifications[idx] = _testNotifications[idx].copyWith(isRead: true);
        _streamController.add(List.unmodifiable(_testNotifications));
        notifyListeners();
      }
      return;
    }

    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      final current = _notifications[idx];
      _notifications[idx] = NotificationModel(
        id: current.id,
        userId: current.userId,
        title: current.title,
        body: current.body,
        type: current.type,
        isRead: true,
        data: current.data,
        createdAt: current.createdAt,
      );
      _notify();
    }

    try {
      await _firestore
          ?.collection(FirestoreCollections.notifications)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Notice: Error updating notification read state: $e');
    }
  }

  /// Marks all unread notifications as read
  Future<void> markAllAsRead() async {
    if (_isTestMode) {
      for (int i = 0; i < _testNotifications.length; i++) {
        _testNotifications[i] = _testNotifications[i].copyWith(isRead: true);
      }
      _streamController.add(List.unmodifiable(_testNotifications));
      notifyListeners();
      return;
    }

    final unread = _notifications.where((n) => !n.isRead).toList();
    for (int i = 0; i < _notifications.length; i++) {
      final current = _notifications[i];
      if (!current.isRead) {
        _notifications[i] = NotificationModel(
          id: current.id,
          userId: current.userId,
          title: current.title,
          body: current.body,
          type: current.type,
          isRead: true,
          data: current.data,
          createdAt: current.createdAt,
        );
      }
    }
    _notify();

    if (_firestore != null) {
      final batch = _firestore!.batch();
      for (final notif in unread) {
        batch.update(
          _firestore!.collection(FirestoreCollections.notifications).doc(notif.id),
          {'isRead': true},
        );
      }
      try {
        await batch.commit();
      } catch (e) {
        debugPrint('Notice: Error batch-updating notifications: $e');
      }
    }
  }

  void _notify() {
    _streamController.add(List.unmodifiable(_notifications));
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _firestoreSub?.cancel();
    _streamController.close();
    super.dispose();
  }
}
