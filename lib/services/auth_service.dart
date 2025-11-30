// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/models/app_user.dart';
import 'package:webshop/repositories/user_repository.dart';

/// Handles all authentication-related logic for the application.
///
/// This service acts as a facade over [FirebaseAuth] and coordinates with
/// the [UserRepository] to ensure that every authenticated user has a
/// corresponding profile document in Firestore.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();

  /// Exposes a stream of authentication state changes.
  ///
  /// The UI listens to this stream (usually via a StreamBuilder or Riverpod)
  /// to decide whether to show the Login page or the Home page.
  Stream<User?> get user => _auth.authStateChanges();

  /// Returns the current user's UID if logged in, otherwise null.
  String? get currentUserId => _auth.currentUser?.uid;

  /// Returns the full Firebase [User] object if logged in.
  ///
  /// Useful for synchronously accessing properties like `email` or `displayName`.
  User? get currentUser => _auth.currentUser;

  /// Registers a new user account using an email and password.
  ///
  /// This performs a two-step operation:
  /// 1. Creates the Authentication record in Firebase Auth.
  /// 2. Creates a corresponding document in the 'users' Firestore collection.
  ///
  /// Throws a [FirebaseAuthException] if the email is already in use or weak.
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // CRITICAL: Immediately create the user profile in Firestore.
      // If we skip this, the user would be logged in but accessing the checkout
      // or profile pages would fail because the database document wouldn't exist.
      if (userCredential.user != null) {
        await _userRepository.saveUserProfile(
          userCredential.user!.uid,
          AppUser(
              id: userCredential.user!.uid, email: userCredential.user!.email),
        );
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs in an existing user using email and password.
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Authenticates the user using their Google account (Web compatible).
  ///
  /// Uses [signInWithPopup] to ensure a smooth experience on web browsers
  /// without complex redirect routing logic.
  Future<UserCredential> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // We use signInWithPopup for Web to avoid losing app state (which happens with redirects).
      final UserCredential userCredential =
          await _auth.signInWithPopup(googleProvider);

      // Sync logic: Ensure the user exists in our database.
      // Even if the user already exists in Auth, their Firestore document might be missing
      // (e.g. legacy users or manual deletion). merge: true in the repository handles updates safely.
      if (userCredential.user != null) {
        await _userRepository.saveUserProfile(
          userCredential.user!.uid,
          AppUser(
            id: userCredential.user!.uid,
            email: userCredential.user!.email,
            name: userCredential.user!.displayName,
          ),
        );
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle the specific case where the user closes the popup manually.
      if (e.code == 'popup-closed-by-user') {
        throw Exception('Google sign-in popup closed by user.');
      }
      rethrow;
    } catch (e) {
      throw Exception('Error during Google sign-in: $e');
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
    // Note: GoogleSignIn().signOut() is not strictly required here for the web popup flow,
    // as Firebase Auth handles the session termination effectively.
  }

  /// Returns a stream of the current user's profile data from Firestore.
  ///
  /// Returns a stream of null if the user is not logged in.
  Stream<AppUser?> getAppUserProfileStream() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value(null);
    }
    return _userRepository.getUserProfileStream(userId);
  }

  /// Fetches the current user's profile data once (Future).
  ///
  /// Useful for populating forms (like the Shipping Address page) where
  /// real-time updates are not required.
  Future<AppUser?> getAppUserProfileOnce() async {
    final userId = currentUserId;
    if (userId == null) {
      return null;
    }
    return _userRepository.getUserProfile(userId);
  }

  /// Updates the current user's profile information in Firestore.
  ///
  /// Throws an [Exception] if no user is currently logged in.
  Future<void> saveAppUserProfile(AppUser userProfile) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not logged in.');
    }
    await _userRepository.saveUserProfile(userId, userProfile);
  }
}
