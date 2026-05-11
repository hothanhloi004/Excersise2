import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum Status { uninitialized, authenticated, authenticating, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  Status _status = Status.uninitialized;
  User? _user;

  Status get status => _status;
  User? get user => _user;

  AuthProvider()
      : _firebaseAuth = FirebaseAuth.instance,
        _googleSignIn = GoogleSignIn(
          clientId: kIsWeb
              ? '849073044719-0auo4b053gai94g975t3f52e53orkaf2.apps.googleusercontent.com'
              : null,
        ),
        _firestore = FirebaseFirestore.instance {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _status = Status.unauthenticated;
    } else {
      _user = user;
      _status = Status.authenticated;
    }
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    try {
      _status = Status.authenticating;
      notifyListeners();

      User? user;

      if (kIsWeb) {
        // Trên Web: Dùng trực tiếp signInWithPopup để tránh lỗi People API (403 Forbidden)
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential =
            await _firebaseAuth.signInWithPopup(googleProvider);
        user = userCredential.user;
      } else {
        // Trên Mobile: Dùng GoogleSignIn như cũ
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          _status = Status.unauthenticated;
          notifyListeners();
          return false;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
            await _firebaseAuth.signInWithCredential(credential);
        user = userCredential.user;
      }

      if (user == null) {
        _status = Status.unauthenticated;
        notifyListeners();
        return false;
      }

      // Lưu thông tin user lên Firestore
      try {
        await _saveUserToFirestore(user);
      } catch (e) {
        print('Error saving user to Firestore: $e');
        // Vẫn tiếp tục nếu lỗi Firestore để user có thể vào được App
      }

      // Lưu thông tin local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', user.uid);
      await prefs.setString('displayName', user.displayName ?? '');
      await prefs.setString('photoUrl', user.photoURL ?? '');
      await prefs.setString('email', user.email ?? '');

      _user = user;
      _status = Status.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      print('Login error: $e');
      _status = Status.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();

      if (!doc.exists) {
        await userRef.set({
          'id': user.uid,
          'displayName': user.displayName ?? '',
          'photoUrl': user.photoURL ?? '',
          'email': user.email ?? '',
          'aboutMe': 'Hey there! I am using Flutter Chat.',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Firestore error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _status = Status.unauthenticated;
    _user = null;
    notifyListeners();
  }

  String? getCurrentUserId() => _firebaseAuth.currentUser?.uid;
}
