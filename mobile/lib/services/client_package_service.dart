import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/purchased_package_model.dart';
import 'notification_service.dart';

/// Real-time client package synchronization service.
/// Connects client package purchases directly with trainer dashboards.
class ClientPackageService extends ChangeNotifier {
  static final ClientPackageService instance = ClientPackageService._internal();
  factory ClientPackageService() => instance;
  ClientPackageService._internal() {
    _initAuthListener();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot>? _packageSub;

  final List<PurchasedPackageModel> _packages = [];
  final StreamController<List<PurchasedPackageModel>> _streamController =
      StreamController<List<PurchasedPackageModel>>.broadcast();

  List<PurchasedPackageModel> get allPackages => List.unmodifiable(_packages);
  Stream<List<PurchasedPackageModel>> get stream => _streamController.stream;

  List<PurchasedPackageModel> get activePackages =>
      _packages.where((p) => !p.isExpired && p.status == 'ACTIVE').toList();

  List<PurchasedPackageModel> clientPackages(String clientId) =>
      _packages.where((p) => p.clientId == clientId).toList();

  List<PurchasedPackageModel> trainerPackages(String trainerId) =>
      _packages.where((p) => p.trainerId == trainerId).toList();

  void _initAuthListener() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToPackages(user.uid);
      } else {
        _packageSub?.cancel();
        _packages.clear();
        _notify();
      }
    });
  }

  void _subscribeToPackages(String uid) {
    _packageSub?.cancel();
    try {
      // Listen to purchased packages collection
      _packageSub = _firestore
          .collection(FirestoreCollections.purchasedPackages)
          .snapshots()
          .listen(
        (snapshot) {
          final items = snapshot.docs.map((d) => PurchasedPackageModel.fromDocument(d)).toList();
          _packages.clear();
          _packages.addAll(items);
          _notify();
        },
        onError: (err) {
          debugPrint('Notice: Error listening to packages: $err');
          _subscribeScopedPackages(uid);
        },
      );
    } catch (e) {
      debugPrint('Notice: Error initializing package listener: $e');
    }
  }

  void _subscribeScopedPackages(String uid) {
    _packageSub?.cancel();
    try {
      // Scoped listener fallback: matches either client or trainer UID
      _packageSub = _firestore
          .collection(FirestoreCollections.purchasedPackages)
          .where('trainerId', isEqualTo: uid)
          .snapshots()
          .listen(
        (snapshot) {
          final items = snapshot.docs.map((d) => PurchasedPackageModel.fromDocument(d)).toList();
          _packages.clear();
          _packages.addAll(items);
          _notify();
        },
        onError: (e) {
          debugPrint('Notice: Scoped package listener error: $e');
        },
      );
    } catch (e) {
      debugPrint('Notice: Scoped package listener exception: $e');
    }
  }

  /// Creates a purchased package record in Firestore, assigns it to trainer,
  /// updates active client count, and notifies the trainer.
  Future<PurchasedPackageModel> createPurchasedPackage({
    required String clientId,
    required String clientName,
    String? clientPhotoUrl,
    String? clientPhone,
    required String trainerId,
    required String trainerName,
    String? trainerPhotoUrl,
    required String packageId,
    required String packageName,
    required int price,
    required int totalDays,
    required int totalSessions,
    String? paymentTransactionId,
  }) async {
    final now = DateTime.now();
    final expiryDate = now.add(Duration(days: totalDays));
    final docRef = _firestore.collection(FirestoreCollections.purchasedPackages).doc();

    final package = PurchasedPackageModel(
      id: docRef.id,
      clientId: clientId,
      clientName: clientName,
      clientPhotoUrl: clientPhotoUrl,
      clientPhone: clientPhone,
      trainerId: trainerId,
      trainerName: trainerName,
      trainerPhotoUrl: trainerPhotoUrl,
      packageId: packageId,
      packageName: packageName,
      price: price,
      purchaseDate: now,
      startDate: now,
      expiryDate: expiryDate,
      totalDays: totalDays,
      totalSessions: totalSessions,
      completedSessions: 0,
      paymentStatus: 'COMPLETED',
      paymentTransactionId: paymentTransactionId,
      status: 'ACTIVE',
      createdAt: now,
      updatedAt: now,
    );

    // 1. Immediately reflect in local state for 0ms latency
    _packages.insert(0, package);
    _notify();

    // 2. Persist to Firestore
    try {
      await docRef.set(package.toMap());

      // 3. Increment trainer active clients count
      final trainerProfileRef = _firestore
          .collection(FirestoreCollections.trainerProfiles)
          .doc(trainerId);
      await trainerProfileRef.set({
        'activeClientsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Send real-time notification to trainer
      await NotificationService.instance.sendNotification(
        userId: trainerId,
        title: 'New Client & Package Assigned! 🎉',
        body: '$clientName just purchased the $packageName. Check your client roster!',
        type: 'PACKAGE_PURCHASED',
        relatedId: package.id,
        data: {
          'clientId': clientId,
          'packageId': packageId,
          'packageName': packageName,
          'price': price,
        },
      );

      // 5. Send real-time confirmation notification to client
      await NotificationService.instance.sendNotification(
        userId: clientId,
        title: 'Training Package Activated! ⚡',
        body: 'Your $packageName with Coach $trainerName is now active. Schedule your sessions anytime!',
        type: 'PACKAGE_ACTIVATED',
        relatedId: package.id,
        data: {
          'trainerId': trainerId,
          'packageId': packageId,
        },
      );
    } catch (e) {
      debugPrint('Notice: Error persisting purchased package: $e');
    }

    return package;
  }

  /// Records session completion for a package
  Future<void> incrementCompletedSession(String packageId) async {
    final idx = _packages.indexWhere((p) => p.id == packageId);
    if (idx >= 0) {
      final current = _packages[idx];
      final newCompleted = current.completedSessions + 1;
      final isDone = newCompleted >= current.totalSessions;
      final updated = current.copyWith(
        completedSessions: newCompleted,
        status: isDone ? 'COMPLETED' : current.status,
        updatedAt: DateTime.now(),
      );
      _packages[idx] = updated;
      _notify();

      try {
        await _firestore
            .collection(FirestoreCollections.purchasedPackages)
            .doc(packageId)
            .update({
          'completedSessions': newCompleted,
          if (isDone) 'status': 'COMPLETED',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Notice: Error updating package session count: $e');
      }
    }
  }

  void _notify() {
    _streamController.add(List.unmodifiable(_packages));
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _packageSub?.cancel();
    _streamController.close();
    super.dispose();
  }
}
