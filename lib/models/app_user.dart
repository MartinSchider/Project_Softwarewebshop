// lib/models/app_user.dart
import 'package:flutter/foundation.dart';

/// Represents a user profile within the application.
///
/// This data model maps directly to documents stored in the 'users' collection
/// in Cloud Firestore. It encapsulates:
/// * **Identity**: Unique ID and email.
/// * **Personal Info**: Name and shipping address details.
/// * **Permissions**: Role-based access control (Admin status).
/// * **Loyalty Program**: Status and points balance for the Fidelity Card.
///
/// The class is marked as `@immutable`, meaning its fields cannot be changed
/// once instantiated. To modify data, use the [copyWith] method.
@immutable
class AppUser {
  /// The unique identifier for the user (typically corresponds to the Firebase Auth UID).
  final String id;

  /// The email address associated with the account.
  final String? email;

  /// The user's first name.
  final String? name;

  /// The user's last name.
  final String? surname;

  /// The primary shipping address line.
  final String? address;

  /// The postal/zip code.
  final String? postcode;

  /// The city of residence.
  final String? city;

  /// Indicates if the user has administrative privileges.
  ///
  /// If `true`, the user can access the Admin Dashboard and modify products.
  final bool isAdmin;

  // ==================================================================
  // FIDELITY PROGRAM FIELDS
  // ==================================================================

  /// Indicates if the user has activated the digital Fidelity Card.
  final bool isFidelityActive;

  /// The current balance of loyalty points accumulated by the user.
  final int fidelityPoints;

  /// Creates a constant instance of [AppUser].
  const AppUser({
    required this.id,
    this.email,
    this.name,
    this.surname,
    this.address,
    this.postcode,
    this.city,
    this.isAdmin = false,
    this.isFidelityActive = false, // Defaults to inactive
    this.fidelityPoints = 0,       // Defaults to 0 points
  });

  /// Factory constructor to create an [AppUser] from a Firestore Map.
  ///
  /// This method handles:
  /// 1. **Deserialization**: extracting values from the `Map<String, dynamic>`.
  /// 2. **Type Safety**: casting dynamic types to strong types (e.g., `as String?`).
  /// 3. **Null Handling**: providing default values (e.g., `false` for booleans)
  ///    if the field is missing or null in the database.
  ///
  /// * [data]: The map containing the raw data (usually `snapshot.data()`).
  /// * [id]: The document ID from Firestore.
  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      email: data['email'] as String?,
      name: data['name'] as String?,
      surname: data['surname'] as String?,
      address: data['address'] as String?,
      postcode: data['postcode'] as String?,
      city: data['city'] as String?,
      isAdmin: data['isAdmin'] as bool? ?? false,
      
      // Reading Fidelity Program fields with safe defaults
      isFidelityActive: data['isFidelityActive'] as bool? ?? false,
      fidelityPoints: (data['fidelityPoints'] as num?)?.toInt() ?? 0,
    );
  }

  /// Converts the [AppUser] instance into a JSON-compatible Map.
  ///
  /// This is used when saving or updating the user profile in Cloud Firestore.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'surname': surname,
      'address': address,
      'postcode': postcode,
      'city': city,
      'isAdmin': isAdmin,
      'isFidelityActive': isFidelityActive,
      'fidelityPoints': fidelityPoints,
    };
  }

  /// Creates a copy of this [AppUser] but with the given fields replaced with new values.
  ///
  /// Since the class is immutable, this method is the standard way to "modify"
  /// a user state. For example, updating the address or adding points results
  /// in a new [AppUser] object, leaving the original unchanged.
  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? surname,
    String? address,
    String? postcode,
    String? city,
    bool? isAdmin,
    bool? isFidelityActive,
    int? fidelityPoints,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      address: address ?? this.address,
      postcode: postcode ?? this.postcode,
      city: city ?? this.city,
      isAdmin: isAdmin ?? this.isAdmin,
      isFidelityActive: isFidelityActive ?? this.isFidelityActive,
      fidelityPoints: fidelityPoints ?? this.fidelityPoints,
    );
  }
}