import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  User? get firebaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
    } else {
      await _fetchUserData(firebaseUser.uid);
    }
    notifyListeners();
  }

  Future<void> _fetchUserData(String uid) async {
  try {
    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();

    debugPrint("Fetching user for UID: $uid");
    debugPrint("Document exists: ${doc.exists}");

    if (doc.exists) {
      _currentUser = AppUser.fromMap(doc.data()!, uid);
    } else {
      // 🔥 AUTO CREATE USER (IMPORTANT FIX)
      final firebaseUser = _auth.currentUser!;

      final newUser = AppUser(
        uid: uid,
        name: firebaseUser.email ?? 'User',
        email: firebaseUser.email ?? '',
        phone: '',
        role: UserRole.user,
        createdAt: DateTime.now(),
      );

      await docRef.set(newUser.toMap());
      _currentUser = newUser;
    }

    debugPrint("User loaded: ${_currentUser?.email}");
  } catch (e) {
    debugPrint('Error fetching user data: $e');
  }
}

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    UserRole role = UserRole.user,
    String? ngoName,
    String? ngoAddress,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = AppUser(
        uid: credential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        ngoName: ngoName,
        ngoAddress: ngoAddress,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toMap());

      _currentUser = user;
      return null;
    } on FirebaseAuthException catch (e) {
  print("FIREBASE ERROR CODE: ${e.code}");
  print("FIREBASE ERROR MESSAGE: ${e.message}");
  return e.message;
} catch (e) {
  print("UNKNOWN ERROR: $e");
  return e.toString();
}
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<String?> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      if (_currentUser == null) return 'Not logged in';

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updates);

      _currentUser = _currentUser!.copyWith(
        name: name,
        phone: phone,
        photoUrl: photoUrl,
      );
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> updateUserLocation(double lat, double lng) async {
    if (_currentUser == null) return;
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'location': GeoPoint(lat, lng),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}