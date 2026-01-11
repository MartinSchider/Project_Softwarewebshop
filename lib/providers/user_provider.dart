// lib/providers/user_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:webshop/models/app_user.dart';
import 'package:webshop/repositories/user_repository.dart';

/// Provides a real-time stream of the authenticated user's profile data.
///
/// This provider serves as a **reactive data source** for the current user's
/// information stored in Firestore (e.g., fidelity points, membership status, name).
///
/// **Mechanism:**
/// 1. It checks the current `FirebaseAuth` state when initialized.
/// 2. If a user is logged in, it establishes a live Firestore stream for that specific UID.
/// 3. Any change in the database (e.g., points added by a Cloud Function) triggers
///    an immediate update here, causing any listening widgets to rebuild automatically.
///
/// Returns a [Stream] of [AppUser?] (which is `null` if the user is not logged in).
final userProfileProvider = StreamProvider<AppUser?>((ref) {
  // 1. Retrieve the current Firebase Auth user instance.
  final user = FirebaseAuth.instance.currentUser;

  // 2. Handle the Unauthenticated State.
  // If no user is currently logged in, we return a stream emitting 'null'.
  // This allows the UI to handle "guest" states gracefully (e.g., showing a login button).
  if (user == null) {
    return Stream.value(null);
  }

  // 3. Initialize the Repository.
  // This layer handles the low-level communication with Firestore.
  final userRepo = UserRepository();

  // 4. Establish and Return the Data Stream.
  // We subscribe to the 'users/{uid}' document. This ensures that features like
  // the Fidelity Card point balance are always up-to-date without manual refreshes.
  return userRepo.getUserProfileStream(user.uid);
});