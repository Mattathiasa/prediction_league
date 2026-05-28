import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserModel? _userModel;
  bool _initialized = false;
  bool _isLoading = false;

  UserModel? get userModel => _userModel;
  bool get initialized => _initialized;
  bool get isLoading => _isLoading;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  AuthService() {
    _auth.authStateChanges().listen(_handleAuthChange);
  }

  Future<void> _handleAuthChange(User? firebaseUser) async {
    if (firebaseUser != null) {
      await _fetchUserModel(firebaseUser.uid);
    } else {
      _userModel = null;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _fetchUserModel(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (snap.exists) {
      _userModel = UserModel.fromFirestore(snap.data()!, uid);
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // user cancelled the picker
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

      await _createUserIfNew(firebaseUser);
      await _fetchUserModel(firebaseUser.uid);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Only creates the Firestore doc on first login
  Future<void> _createUserIfNew(User firebaseUser) async {
    final docRef = _db.collection('users').doc(firebaseUser.uid);
    final snap = await docRef.get();
    if (snap.exists) return;

    final newUser = UserModel(
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'Anonymous',
      photoUrl: firebaseUser.photoURL ?? '',
    );
    await docRef.set(newUser.toMap());
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
