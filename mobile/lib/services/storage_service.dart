import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';

/// Secure Firebase Storage service handling profile pictures and private trainer documents.
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int maxProfileImageBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxDocumentBytes = 15 * 1024 * 1024;    // 15 MB

  // ───────────────────────────────────────────────────────────────────────────
  // Profile Pictures
  // ───────────────────────────────────────────────────────────────────────────

  /// Uploads user profile photo to: profile_pictures/{userId}/{fileName}
  /// Accessible publicly to authenticated users.
  Future<String> uploadProfilePicture({
    required String userId,
    required File file,
  }) async {
    final bytes = await file.length();
    if (bytes > maxProfileImageBytes) {
      throw const StorageException(
        'Profile photo exceeds the 5MB size limit.',
        code: 'FILE_TOO_LARGE',
      );
    }

    final ext = file.path.split('.').last.toLowerCase();
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('${FirestoreCollections.storageProfilePictures}/$userId/$fileName');

    final metadata = SettableMetadata(
      contentType: _resolveImageMime(ext),
      customMetadata: {'userId': userId},
    );

    final uploadTask = await ref.putFile(file, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Sync photoUrl to users document
    if (userId.trim().isNotEmpty) {
      await _firestore.collection(FirestoreCollections.users).doc(userId).update({
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return downloadUrl;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Private Trainer Documents (Certifications & ID Verifications)
  // ───────────────────────────────────────────────────────────────────────────

  /// Uploads trainer certification document to:
  /// trainer_documents/{trainerId}/certifications/{fileName}
  /// Strictly restricted: readable ONLY by the trainer owner and ADMIN.
  Future<String> uploadTrainerCertification({
    required String trainerId,
    required File file,
    required String certificateTitle,
  }) async {
    final bytes = await file.length();
    if (bytes > maxDocumentBytes) {
      throw const StorageException(
        'Certification document exceeds the 15MB size limit.',
        code: 'FILE_TOO_LARGE',
      );
    }

    final ext = file.path.split('.').last.toLowerCase();
    final sanitizedTitle = certificateTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = '${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'trainer_documents/$trainerId/certifications/$fileName';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: _resolveDocMime(ext),
      customMetadata: {
        'trainerId': trainerId,
        'docType': 'CERTIFICATION',
        'title': certificateTitle,
      },
    );

    final uploadTask = await ref.putFile(file, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Append to trainer_profiles certificationDocuments array
    if (trainerId.trim().isNotEmpty) {
      await _firestore.collection(FirestoreCollections.trainerProfiles).doc(trainerId).update({
        'certificationDocuments': FieldValue.arrayUnion([downloadUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return downloadUrl;
  }

  /// Uploads trainer verification proof (Govt ID, CPR, Degree) to:
  /// trainer_documents/{trainerId}/verifications/{fileName}
  /// Strictly restricted: readable ONLY by the trainer owner and ADMIN.
  Future<String> uploadTrainerVerificationDoc({
    required String trainerId,
    required File file,
    required String docType, // e.g. 'GOVT_ID', 'CPR_AED', 'DEGREE'
  }) async {
    final bytes = await file.length();
    if (bytes > maxDocumentBytes) {
      throw const StorageException(
        'Verification document exceeds the 15MB size limit.',
        code: 'FILE_TOO_LARGE',
      );
    }

    final ext = file.path.split('.').last.toLowerCase();
    final fileName = '${docType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'trainer_documents/$trainerId/verifications/$fileName';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: _resolveDocMime(ext),
      customMetadata: {
        'trainerId': trainerId,
        'docType': docType,
      },
    );

    final uploadTask = await ref.putFile(file, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Append to trainer_profiles verificationDocuments array
    if (trainerId.trim().isNotEmpty) {
      await _firestore.collection(FirestoreCollections.trainerProfiles).doc(trainerId).update({
        'verificationDocuments': FieldValue.arrayUnion([downloadUrl]),
        'verificationStatus': 'PENDING', // Reset/Set to pending review on new document upload
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return downloadUrl;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MIME type helpers
  // ───────────────────────────────────────────────────────────────────────────

  String _resolveImageMime(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _resolveDocMime(String ext) {
    if (ext == 'pdf') return 'application/pdf';
    return _resolveImageMime(ext);
  }
}

