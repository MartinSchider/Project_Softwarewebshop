// lib/repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/app_user.dart';

/// Handles data operations for user profiles in Firestore.
///
/// This repository acts as the Data Layer for user-specific information
/// (e.g., name, address, shipping details). It abstracts the direct Firestore
/// interactions from the Service and UI layers.
class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns a real-time stream of the user's profile data.
  ///
  /// This is useful for keeping the UI in sync if the user updates their profile
  /// from a different device or if an admin modifies their status.
  ///
  /// * [userId]: The unique UID of the user (from Firebase Auth).
  Stream<AppUser?> getUserProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      // Check if the document exists and has data before trying to parse it.
      // If the user just signed up, the document might not exist yet.
      if (snapshot.exists && snapshot.data() != null) {
        return AppUser.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  /// Fetches the user profile data a single time.
  ///
  /// Use this method when you need the current state of the profile but don't
  /// need to listen for future updates (e.g., pre-filling a checkout form).
  ///
  /// * [userId]: The unique UID of the user.
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      // Log error locally or to a monitoring service.
      // We return null so the UI can handle "no profile found" gracefully.
      print("Error fetching user profile: $e");
      return null;
    }
  }

  /// Saves or updates the user's profile information.
  ///
  /// This method writes the [AppUser] data to the `users` collection.
  ///
  /// * [userId]: The unique UID of the user.
  /// * [userProfile]: The data model containing the new values.
  Future<void> saveUserProfile(String userId, AppUser userProfile) async {
    // We use SetOptions(merge: true) to ensure we don't accidentally overwrite
    // fields that might exist in the database but are not present in our AppUser model
    // (e.g., legacy fields or server-side flags like 'isAdmin').
    await _firestore
        .collection('users')
        .doc(userId)
        .set(userProfile.toMap(), SetOptions(merge: true));
  }
}
