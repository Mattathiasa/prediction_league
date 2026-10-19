import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _db;

  UserModel? _userModel;
  bool _initialized = false;
  bool _isLoading = false;
  String? _error;
  bool _isAdmin = false;
  bool _adminChecked = false;
  String? _startupError;

  UserModel? get userModel => _userModel;
  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;
  bool get isAdmin => _isAdmin;
  bool get adminChecked => _adminChecked;

  /// Set when the app could not establish who is signed in — almost always a
  /// network failure at cold start. The root widget shows a retry affordance
  /// rather than spinning forever.
  String? get startupError => _startupError;

  User? get _firebaseUser => _auth.currentUser;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _db = db ?? FirebaseFirestore.instance {
    _auth.authStateChanges().listen(_handleAuthChange);
  }

  Future<void> _handleAuthChange(User? firebaseUser) async {
    // Every await below can throw offline. Without this guard the listener
    // died before `_initialized` was ever set, leaving the app on a spinner
    // with no way out — launching without a connection bricked it.
    try {
      _startupError = null;

      if (firebaseUser != null) {
        await firebaseUser.reload();
        if (firebaseUser.emailVerified) {
          await _fetchUserModel(firebaseUser.uid);
          await _checkAdmin(firebaseUser.uid);
        } else {
          _clearSession();
        }
      } else {
        _clearSession();
      }
    } catch (e) {
      _startupError = 'Could not reach the server. Check your connection.';
      _clearSession();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  void _clearSession() {
    _userModel = null;
    _isAdmin = false;
    _adminChecked = false;
  }

  /// Re-runs startup after a [startupError]. Safe to call repeatedly.
  Future<void> retryStartup() async {
    _initialized = false;
    _startupError = null;
    notifyListeners();
    await _handleAuthChange(_auth.currentUser);
  }

  Future<void> _checkAdmin(String uid) async {
    try {
      final doc = await _db.collection('admin_roles').doc(uid).get();
      _isAdmin = doc.data()?['isAdmin'] == true;
    } catch (e) {
      // Admin is a UI affordance only — every privileged write re-verifies
      // this same document via firestore.rules — so a failure here degrades
      // to "not an admin" rather than blocking sign-in.
      _isAdmin = false;
    }
    _adminChecked = true;
  }

  Future<void> _fetchUserModel(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (snap.exists) {
      _userModel = UserModel.fromFirestore(snap.data()!, uid);
    } else {
      // Authenticated but no profile document: signing in again would loop, so
      // surface it instead of silently bouncing back to the auth screen.
      _userModel = null;
      _startupError = 'Your profile could not be loaded. Try signing in again.';
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user!;

      if (!firebaseUser.emailVerified) {
        await firebaseUser.sendEmailVerification();
      }

      await _createUserIfNew(firebaseUser);
      await _fetchUserModel(firebaseUser.uid);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Only creates the Firestore doc on first login. Also creates the matching
  // /publicProfiles projection in the same batch — there is no Cloud Function
  // trigger to do that for us on the Spark plan, so every writer of /users
  // mirrors into /publicProfiles itself. See firestore.rules.
  Future<void> _createUserIfNew(User firebaseUser) async {
    final docRef = _db.collection('users').doc(firebaseUser.uid);
    final snap = await docRef.get();
    if (snap.exists) return;

    final newUser = UserModel(
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'Anonymous',
      photoUrl: firebaseUser.photoURL ?? '',
    );
    final batch = _db.batch();
    batch.set(docRef, newUser.toMap());
    batch.set(
      _db.collection('publicProfiles').doc(firebaseUser.uid),
      newUser.toPublicProfileMap(),
    );
    await batch.commit();
  }

  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      _auth.signOut(),
    ]);
    _userModel = null;
    notifyListeners();
  }
}
