import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserModel? _userModel;
  bool _initialized = false;
  bool _isLoading = false;
  String? _error;
  bool _isAdmin = false;
  bool _adminChecked = false;

  UserModel? get userModel => _userModel;
  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;
  bool get isAdmin => _isAdmin;
  bool get adminChecked => _adminChecked;

  User? get _firebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  AuthService() {
    _auth.authStateChanges().listen(_handleAuthChange);
  }

  Future<void> _handleAuthChange(User? firebaseUser) async {
    if (firebaseUser != null) {
      await firebaseUser.reload();
      if (firebaseUser.emailVerified) {
        await _fetchUserModel(firebaseUser.uid);
        _checkAdmin();
      } else {
        _userModel = null;
        _isAdmin = false;
        _adminChecked = false;
      }
    } else {
      _userModel = null;
      _isAdmin = false;
      _adminChecked = false;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _checkAdmin() async {
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('checkAdmin')();
      _isAdmin = result.data['isAdmin'] as bool? ?? false;
    } catch (e) {
      _isAdmin = false;
    }
    _adminChecked = true;
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
