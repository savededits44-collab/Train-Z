import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with Email and Password
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required bool isTrainer,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(name.trim());

      // Save initial profile in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'role': isTrainer ? 'trainer' : 'client',
        'createdAt': FieldValue.serverTimestamp(),
        'onboarded': false,
      }, SetOptions(merge: true));
    }

    return credential;
  }

  /// Sign in with Email and Password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Continue / Sign in with Google
  Future<UserCredential?> signInWithGoogle({required bool isTrainer}) async {
    // Trigger Google Authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      // If document doesn't exist, create initial record
      if (!doc.exists) {
        await docRef.set({
          'uid': user.uid,
          'name': user.displayName ?? googleUser.displayName ?? '',
          'email': user.email ?? googleUser.email,
          'photoUrl': user.photoURL,
          'role': isTrainer ? 'trainer' : 'client',
          'createdAt': FieldValue.serverTimestamp(),
          'onboarded': false,
        });
      }
    }

    return userCredential;
  }

  /// Fetch user document to check role and onboarding status
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Update client onboarding preferences
  Future<void> saveClientOnboarding({
    required String goal,
    required String fitnessLevel,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set({
      'goal': goal,
      'fitnessLevel': fitnessLevel,
      'onboarded': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update trainer onboarding credentials
  Future<void> saveTrainerOnboarding({
    required List<String> specialties,
    required String experience,
    required String bio,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set({
      'specialties': specialties,
      'experience': experience,
      'bio': bio,
      'onboarded': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
