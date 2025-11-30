// lib/models/app_user.dart
import 'package:flutter/foundation.dart';

/// Represents the user profile data within the application.
///
/// This class is marked as [immutable] to ensure thread safety and consistent state
/// management (e.g., when used with Riverpod). To modify a user's data,
/// use the [copyWith] method to create a new instance.
@immutable
class AppUser {
  /// The unique identifier for the user (usually matches the Firebase Auth UID).
  final String id;

  /// The user's email address. Nullable if the user registered via other methods.
  final String? email;

  /// The user's first name.
  final String? name;

  /// The user's last name.
  final String? surname;

  /// The physical shipping address.
  final String? address;

  /// The postal or zip code.
  final String? postcode;

  /// The city of residence.
  final String? city;

  /// Creates a constant instance of [AppUser].
  ///
  /// Only [id] is required to identify the user; other profile details
  /// can be populated later during the checkout or profile editing process.
  const AppUser({
    required this.id,
    this.email,
    this.name,
    this.surname,
    this.address,
    this.postcode,
    this.city,
  });

  /// Factory constructor to create an [AppUser] instance from a key-value map.
  ///
  /// This is typically used when parsing data retrieved from Firestore.
  ///
  /// * [data]: The map containing the user data (e.g., `document.data()`).
  /// * [id]: The unique document ID, passed separately as it is not usually stored inside the data map.
  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      // We use explicit casting (as String?) to prevent runtime errors
      // if the database field is missing (null) or of an unexpected type.
      email: data['email'] as String?,
      name: data['name'] as String?,
      surname: data['surname'] as String?,
      address: data['address'] as String?,
      postcode: data['postcode'] as String?,
      city: data['city'] as String?,
    );
  }

  /// Converts the [AppUser] instance into a [Map] for database persistence.
  ///
  /// This method prepares the data to be written to Firestore.
  Map<String, dynamic> toMap() {
    return {
      // We intentionally exclude 'id' from the map because in Firestore,
      // the ID is the key of the document itself, not a field within it.
      'email': email,
      'name': name,
      'surname': surname,
      'address': address,
      'postcode': postcode,
      'city': city,
    };
  }

  /// Creates a copy of this [AppUser] but with the given fields replaced with the new values.
  ///
  /// Since the class is immutable, we cannot change fields directly.
  /// This method allows us to "update" the user state by returning a new object
  /// with the desired changes, preserving the values of unchanged fields.
  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? surname,
    String? address,
    String? postcode,
    String? city,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      address: address ?? this.address,
      postcode: postcode ?? this.postcode,
      city: city ?? this.city,
    );
  }
}
