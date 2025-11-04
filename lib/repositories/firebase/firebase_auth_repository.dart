import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  AuthUser? _mapUser(fb.User? u) {
    if (u == null) return null;
    return AuthUser(
      uid: u.uid,
      email: u.email,
      emailVerified: u.emailVerified,
      displayName: u.displayName,
      photoURL: u.photoURL,
      createdAt: u.metadata.creationTime,
    );
  }

  @override
  Stream<AuthUser?> get authStateChanges => _auth.authStateChanges().map(_mapUser);

  @override
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Future<AuthResult> signUpWithEmail({required String email, required String password}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return AuthResult(success: true, user: _mapUser(cred.user));
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: e.code);
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  @override
  Future<AuthResult> signInWithEmail({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return AuthResult(success: true, user: _mapUser(cred.user));
    } on fb.FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: e.code);
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> sendEmailVerification() async {
    final u = _auth.currentUser;
    if (u != null) {
      await u.sendEmailVerification();
    }
  }

  Future<void> _reauthenticate(String currentPassword) async {
    final u = _auth.currentUser;
    if (u == null) return;
    final email = u.email;
    if (email == null) return;
    final cred = fb.EmailAuthProvider.credential(email: email, password: currentPassword);
    await u.reauthenticateWithCredential(cred);
  }

  @override
  Future<void> updatePassword({required String currentPassword, required String newPassword}) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _reauthenticate(currentPassword);
    await u.updatePassword(newPassword);
  }

  @override
  Future<void> updateEmail({required String currentPassword, required String newEmail}) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _reauthenticate(currentPassword);
    await u.updateEmail(newEmail);
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _reauthenticate(password);
    await u.delete();
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return await u.getIdToken(forceRefresh);
  }

  @override
  Future<Map<String, dynamic>> getCustomClaims() async {
    final u = _auth.currentUser;
    if (u == null) return {};
    final res = await u.getIdTokenResult(true);
    return Map<String, dynamic>.from(res.claims ?? {});
  }
}
