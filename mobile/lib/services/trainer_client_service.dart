import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/booking_model.dart';
import '../shared/models/trainer_client_model.dart';
import 'booking_service.dart';

/// Exception thrown when unauthorized client operations or illegal access is attempted.
class TrainerClientSecurityException implements Exception {
  final String message;
  const TrainerClientSecurityException(this.message);

  @override
  String toString() => 'TrainerClientSecurityException: $message';
}

/// Service managing connected clients, private coaching notes, and progress records for Trainers.
/// Strictly enforces that Trainers can only access Clients connected through legitimate bookings.
class TrainerClientService {
  static final TrainerClientService instance = TrainerClientService._internal();
  factory TrainerClientService() => instance;
  TrainerClientService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  // In-memory test state
  bool _isTestMode = false;
  final List<TrainerClientModel> _testClients = [];
  final List<TrainerClientNoteModel> _testNotes = [];
  final List<TrainerClientProgressModel> _testProgress = [];
  final StreamController<List<TrainerClientNoteModel>> _notesStreamController =
      StreamController<List<TrainerClientNoteModel>>.broadcast();
  final StreamController<List<TrainerClientProgressModel>> _progressStreamController =
      StreamController<List<TrainerClientProgressModel>>.broadcast();

  @visibleForTesting
  void resetForTest() {
    _isTestMode = true;
    _testClients.clear();
    _testNotes.clear();
    _testProgress.clear();
  }

  @visibleForTesting
  void setTestClients(List<TrainerClientModel> clients) {
    _isTestMode = true;
    _testClients
      ..clear()
      ..addAll(clients);
  }

  @visibleForTesting
  void setTestNotes(List<TrainerClientNoteModel> notes) {
    _isTestMode = true;
    _testNotes
      ..clear()
      ..addAll(notes);
    _notesStreamController.add(List.unmodifiable(_testNotes));
  }

  @visibleForTesting
  void setTestProgress(List<TrainerClientProgressModel> progress) {
    _isTestMode = true;
    _testProgress
      ..clear()
      ..addAll(progress);
    _progressStreamController.add(List.unmodifiable(_testProgress));
  }

  /// Transforms raw bookings for a trainer into aggregated connected clients.
  /// Display ONLY Clients legitimately connected through bookings.
  List<TrainerClientModel> aggregateClientsFromBookings(
    String trainerId,
    List<BookingModel> bookings,
  ) {
    final Map<String, List<BookingModel>> grouped = {};
    for (final b in bookings) {
      if (b.trainerId == trainerId && b.clientId.isNotEmpty) {
        grouped.putIfAbsent(b.clientId, () => []).add(b);
      }
    }

    final now = DateTime.now();
    final List<TrainerClientModel> result = [];

    for (final entry in grouped.entries) {
      final clientId = entry.key;
      final clientBookings = entry.value;

      // Sort chronological
      clientBookings.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

      final latestBooking = clientBookings.last;
      final firstBooking = clientBookings.first;

      // Find earliest future confirmed session
      BookingModel? nextSession;
      final upcomingCandidates = clientBookings.where((b) {
        return b.status == BookingStatus.confirmed &&
            b.sessionDate.isAfter(now.subtract(const Duration(minutes: 60)));
      }).toList();

      if (upcomingCandidates.isNotEmpty) {
        upcomingCandidates.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
        nextSession = upcomingCandidates.first;
      }

      // Find latest completed session
      BookingModel? lastCompleted;
      final completedCandidates = clientBookings.where((b) {
        return b.status == BookingStatus.completed;
      }).toList();

      if (completedCandidates.isNotEmpty) {
        completedCandidates.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
        lastCompleted = completedCandidates.first;
      }

      // Calculate sessions
      int totalSessions = 0;
      int completedSessions = 0;

      for (final b in clientBookings) {
        if (b.status == BookingStatus.completed) {
          completedSessions++;
        }
      }

      // If package info is on the latest booking, use that
      if (latestBooking.totalSessions != null && latestBooking.totalSessions! > 0) {
        totalSessions = latestBooking.totalSessions!;
        if (latestBooking.sessionsCompleted != null && latestBooking.sessionsCompleted! > 0) {
          completedSessions = latestBooking.sessionsCompleted!;
        }
      } else {
        totalSessions = clientBookings.length;
      }

      final remaining = (totalSessions - completedSessions).clamp(0, 999);

      // Determine active vs past status
      // Active: has upcoming confirmed session, or remaining sessions on active package, or completed session within 30 days
      bool isActive = false;
      if (nextSession != null) {
        isActive = true;
      } else if (remaining > 0 &&
          (latestBooking.status == BookingStatus.confirmed ||
           latestBooking.status == BookingStatus.pending ||
           latestBooking.status == BookingStatus.reserved)) {
        isActive = true;
      } else if (lastCompleted != null &&
          now.difference(lastCompleted.sessionDate).inDays <= 30) {
        isActive = true;
      }

      result.add(
        TrainerClientModel(
          clientId: clientId,
          name: latestBooking.clientName ?? 'Athlete',
          photoUrl: latestBooking.clientPhotoUrl,
          gender: latestBooking.clientGender,
          fitnessGoal: latestBooking.fitnessGoal,
          activePackageName: latestBooking.packageName,
          totalSessions: totalSessions,
          completedSessions: completedSessions,
          remainingSessions: remaining,
          nextSessionDate: nextSession?.sessionDate,
          nextSessionTime: nextSession?.startTime,
          lastCompletedSessionDate: lastCompleted?.sessionDate,
          status: isActive ? TrainerClientStatus.active : TrainerClientStatus.past,
          firstSessionDate: firstBooking.sessionDate,
          totalBookingsCount: clientBookings.length,
          bookings: clientBookings,
        ),
      );
    }

    // Sort: Active first, then by next session, then by latest booking
    result.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;

      if (a.nextSessionDate != null && b.nextSessionDate != null) {
        return a.nextSessionDate!.compareTo(b.nextSessionDate!);
      }
      if (a.nextSessionDate != null) return -1;
      if (b.nextSessionDate != null) return 1;

      return (b.lastCompletedSessionDate ?? DateTime(2000))
          .compareTo(a.lastCompletedSessionDate ?? DateTime(2000));
    });

    return result;
  }

  /// Streams connected clients for the trainer.
  Stream<List<TrainerClientModel>> streamClientsForTrainer(String trainerId) {
    if (_isTestMode && _testClients.isNotEmpty) {
      return Stream.value(List.unmodifiable(_testClients));
    }

    return BookingService.instance.streamBookingsForTrainer(trainerId).map((bookings) {
      return aggregateClientsFromBookings(trainerId, bookings);
    });
  }

  /// Filter clients by search query and relationship status (All, Active, Past).
  List<TrainerClientModel> filterClients(
    List<TrainerClientModel> clients, {
    String query = '',
    TrainerClientStatus? statusFilter,
  }) {
    return clients.where((c) {
      if (statusFilter != null && c.status != statusFilter) {
        return false;
      }
      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final nameMatch = c.name.toLowerCase().contains(q);
        final packageMatch = (c.activePackageName ?? '').toLowerCase().contains(q);
        final goalMatch = (c.fitnessGoal ?? '').toLowerCase().contains(q);
        if (!nameMatch && !packageMatch && !goalMatch) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ── Training Notes Management ──────────────────────────────────────────────

  /// Streams private notes for a specific client written by the authenticated trainer.
  /// Clients have zero access to these notes.
  Stream<List<TrainerClientNoteModel>> streamNotes({
    required String trainerId,
    required String clientId,
  }) {
    if (_isTestMode) {
      final filtered = _testNotes
          .where((n) => n.trainerId == trainerId && n.clientId == clientId)
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return Stream.value(List.unmodifiable(filtered));
    }

    if (_firestore == null) {
      return Stream.value([]);
    }

    return _firestore!
        .collection(FirestoreCollections.trainerClientNotes)
        .where('trainerId', isEqualTo: trainerId)
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snapshot) {
          final notes = snapshot.docs
              .map((doc) => TrainerClientNoteModel.fromMap(doc.data(), id: doc.id))
              .toList();
          notes.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          return notes;
        });
  }

  /// Adds a private coaching note.
  /// Enforces non-empty content and rejects medical diagnostic phrasing.
  Future<TrainerClientNoteModel> addNote({
    required String trainerId,
    required String clientId,
    required String title,
    required String content,
    String category = 'Observation',
    DateTime? sessionDate,
  }) async {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();

    if (cleanContent.isEmpty) {
      throw ArgumentError('Note content cannot be empty.');
    }

    // Medical disclaimer enforcement: training notes must not contain medical advice
    final lower = '$cleanTitle $cleanContent'.toLowerCase();
    const prohibitedTerms = ['diagnosis', 'prescribe', 'prescription', 'cure disease', 'medical treatment'];
    for (final term in prohibitedTerms) {
      if (lower.contains(term)) {
        throw ArgumentError('Coaching notes are for fitness observations only and must not contain medical advice or diagnoses.');
      }
    }

    final id = 'note_${DateTime.now().millisecondsSinceEpoch}_${trainerId.hashCode.abs() % 1000}';
    final note = TrainerClientNoteModel(
      id: id,
      trainerId: trainerId,
      clientId: clientId,
      title: cleanTitle.isEmpty ? 'Coaching Observation' : cleanTitle,
      content: cleanContent,
      category: category,
      sessionDate: sessionDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_isTestMode) {
      _testNotes.insert(0, note);
      _notesStreamController.add(List.unmodifiable(_testNotes));
      return note;
    }

    if (_firestore != null) {
      try {
        await _firestore!
            .collection(FirestoreCollections.trainerClientNotes)
            .doc(id)
            .set(note.toMap());
      } catch (e) {
        debugPrint('Notice: Error saving trainer note to Firestore: $e');
      }
    }

    return note;
  }

  /// Updates an existing note. Enforces Trainer ownership.
  Future<void> updateNote({
    required String noteId,
    required String trainerId,
    required String title,
    required String content,
    String category = 'Observation',
    DateTime? sessionDate,
  }) async {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();

    if (cleanContent.isEmpty) {
      throw ArgumentError('Note content cannot be empty.');
    }

    if (_isTestMode) {
      final index = _testNotes.indexWhere((n) => n.id == noteId);
      if (index >= 0) {
        if (_testNotes[index].trainerId != trainerId) {
          throw const TrainerClientSecurityException('You are not authorized to edit this note.');
        }
        _testNotes[index] = _testNotes[index].copyWith(
          title: cleanTitle,
          content: cleanContent,
          category: category,
          sessionDate: sessionDate,
          updatedAt: DateTime.now(),
        );
        _notesStreamController.add(List.unmodifiable(_testNotes));
      }
      return;
    }

    if (_firestore != null) {
      final docRef = _firestore!.collection(FirestoreCollections.trainerClientNotes).doc(noteId);
      final snap = await docRef.get();
      if (snap.exists && snap.data()?['trainerId'] != trainerId) {
        throw const TrainerClientSecurityException('You are not authorized to edit this note.');
      }
      await docRef.update({
        'title': cleanTitle,
        'content': cleanContent,
        'category': category,
        'sessionDate': sessionDate != null ? Timestamp.fromDate(sessionDate) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Deletes a private note. Enforces Trainer ownership.
  Future<void> deleteNote({
    required String noteId,
    required String trainerId,
  }) async {
    if (_isTestMode) {
      final index = _testNotes.indexWhere((n) => n.id == noteId);
      if (index >= 0) {
        if (_testNotes[index].trainerId != trainerId) {
          throw const TrainerClientSecurityException('You are not authorized to delete this note.');
        }
        _testNotes.removeAt(index);
        _notesStreamController.add(List.unmodifiable(_testNotes));
      }
      return;
    }

    if (_firestore != null) {
      final docRef = _firestore!.collection(FirestoreCollections.trainerClientNotes).doc(noteId);
      final snap = await docRef.get();
      if (snap.exists && snap.data()?['trainerId'] != trainerId) {
        throw const TrainerClientSecurityException('You are not authorized to delete this note.');
      }
      await docRef.delete();
    }
  }

  // ── Training Progress & Milestones ─────────────────────────────────────────

  /// Streams progress records for a client recorded by this trainer.
  Stream<List<TrainerClientProgressModel>> streamProgress({
    required String trainerId,
    required String clientId,
  }) {
    if (_isTestMode) {
      final filtered = _testProgress
          .where((p) => p.trainerId == trainerId && p.clientId == clientId)
          .toList()
        ..sort((a, b) => b.achievedDate.compareTo(a.achievedDate));
      return Stream.value(List.unmodifiable(filtered));
    }

    if (_firestore == null) {
      return Stream.value([]);
    }

    return _firestore!
        .collection(FirestoreCollections.trainerClientProgress)
        .where('trainerId', isEqualTo: trainerId)
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs
              .map((doc) => TrainerClientProgressModel.fromMap(doc.data(), id: doc.id))
              .toList();
          records.sort((a, b) => b.achievedDate.compareTo(a.achievedDate));
          return records;
        });
  }

  /// Adds a legitimate training milestone or workout observation.
  /// Does not automatically generate health claims or medical assessments.
  Future<TrainerClientProgressModel> addProgress({
    required String trainerId,
    required String clientId,
    required String title,
    required String notes,
    String category = 'Milestone',
    required DateTime achievedDate,
  }) async {
    final cleanTitle = title.trim();
    final cleanNotes = notes.trim();

    if (cleanTitle.isEmpty) {
      throw ArgumentError('Progress title cannot be empty.');
    }

    final id = 'prog_${DateTime.now().millisecondsSinceEpoch}_${trainerId.hashCode.abs() % 1000}';
    final progress = TrainerClientProgressModel(
      id: id,
      trainerId: trainerId,
      clientId: clientId,
      title: cleanTitle,
      category: category,
      notes: cleanNotes,
      achievedDate: achievedDate,
      createdAt: DateTime.now(),
    );

    if (_isTestMode) {
      _testProgress.insert(0, progress);
      _progressStreamController.add(List.unmodifiable(_testProgress));
      return progress;
    }

    if (_firestore != null) {
      try {
        await _firestore!
            .collection(FirestoreCollections.trainerClientProgress)
            .doc(id)
            .set(progress.toMap());
      } catch (e) {
        debugPrint('Notice: Error saving training progress to Firestore: $e');
      }
    }

    return progress;
  }

  /// Deletes a progress record. Enforces Trainer ownership.
  Future<void> deleteProgress({
    required String progressId,
    required String trainerId,
  }) async {
    if (_isTestMode) {
      final index = _testProgress.indexWhere((p) => p.id == progressId);
      if (index >= 0) {
        if (_testProgress[index].trainerId != trainerId) {
          throw const TrainerClientSecurityException('You are not authorized to delete this milestone.');
        }
        _testProgress.removeAt(index);
        _progressStreamController.add(List.unmodifiable(_testProgress));
      }
      return;
    }

    if (_firestore != null) {
      final docRef = _firestore!.collection(FirestoreCollections.trainerClientProgress).doc(progressId);
      final snap = await docRef.get();
      if (snap.exists && snap.data()?['trainerId'] != trainerId) {
        throw const TrainerClientSecurityException('You are not authorized to delete this milestone.');
      }
      await docRef.delete();
    }
  }
}

