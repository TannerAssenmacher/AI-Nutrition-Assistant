import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

@riverpod
FirebaseAuth firebaseAuth(Ref ref) {
  return FirebaseAuth.instance;
}

@riverpod
Stream<User?> authStateChanges(Ref ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
}

@riverpod
class AuthService extends _$AuthService {
  @override
  User? build() {
    final authState = ref.watch(authStateChangesProvider);
    // Distinguish between the stream still loading (Firebase hydrating from
    // storage – use the synchronous cache as a best-effort value) and the
    // stream having explicitly emitted null (user signed out).  Collapsing
    // both to `currentUser` caused the home screen to show a permanent spinner
    // when Firebase briefly emitted null during the post-verification token
    // refresh on web.
    return authState.when(
      loading: () => FirebaseAuth.instance.currentUser,
      data: (user) => user,
      error: (_, __) => FirebaseAuth.instance.currentUser,
    );
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = credential.user;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<void> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = credential.user;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    state = null;
  }
}
