// lib/repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webshop/models/app_user.dart';

/// Manages data operations for user profiles within the 'users' Firestore collection.
///
/// This repository abstracts the database layer, providing clean methods to:
/// * Retrieve user data (both one-time fetch and real-time streams).
/// * Update user profile information.
/// * Manage the specific logic for the Fidelity/Loyalty program.
class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Provides a real-time stream of a specific user's profile data.
  ///
  /// **Mechanism:**
  /// * Subscribes to the specific document in the `users` collection.
  /// * Emits a new [AppUser] object immediately whenever the document changes
  ///   (e.g., when points are added or profile details are updated).
  /// * Returns `null` if the user document does not exist yet.
  Stream<AppUser?> getUserProfileStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return AppUser.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  /// Fetches the user profile data a single time.
  ///
  /// Unlike [getUserProfileStream], this returns a [Future] and does not
  /// listen for subsequent updates. Useful for initial checks or static views.
  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      // Log the error internally (consider using a logging service in production)
      print("Error fetching user profile: $e");
      return null;
    }
  }

  /// Creates or updates a user's profile in Firestore.
  ///
  /// **Mechanism:**
  /// Uses [SetOptions] with `merge: true`. This ensures that:
  /// 1. If the document doesn't exist, it is created.
  /// 2. If it exists, only the provided fields are updated, leaving others intact.
  Future<void> saveUserProfile(String userId, AppUser userProfile) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .set(userProfile.toMap(), SetOptions(merge: true));
  }

  // ==================================================================
  // FIDELITY PROGRAM METHODS
  // ==================================================================

  /// Activates the loyalty program status for a specific user.
  ///
  /// This updates the `isFidelityActive` flag to true and initializes the
  /// point balance to 0.
  Future<void> activateFidelity(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isFidelityActive': true,
      'fidelityPoints': 0, // Reset or start at 0
    });
  }

  /// Atomically adds loyalty points to the user's balance.
  ///
  /// **Why use [FieldValue.increment]?**
  /// This operation is safe for concurrent transactions. If two separate processes
  /// try to add points at the exact same time, Firestore handles the math
  /// server-side, preventing race conditions (e.g., overwriting a previous write).
  Future<void> addFidelityPoints(String userId, int pointsToAdd) async {
    await _firestore.collection('users').doc(userId).update({
      'fidelityPoints': FieldValue.increment(pointsToAdd),
    });
  }
}