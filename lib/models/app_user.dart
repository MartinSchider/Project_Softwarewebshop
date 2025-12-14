// lib/models/app_user.dart
import 'package:flutter/foundation.dart';

/// Represents a registered user in the application.
///
/// This model mirrors the document structure in the 'users' Firestore collection.
/// It is marked as [immutable] to ensure thread safety and predictable state updates.
@immutable
class AppUser {
  /// The unique Firebase Authentication UID.
  final String id;

  /// The user's email address.
  final String? email;

  final String? name;
  final String? surname;
  final String? address;
  final String? postcode;
  final String? city;

  /// Indicates if the user has administrative privileges.
  ///
  /// This field controls access to the Admin Dashboard and management features.
  final bool isAdmin; // <--- New field for Admin access

  const AppUser({
    required this.id,
    this.email,
    this.name,
    this.surname,
    this.address,
    this.postcode,
    this.city,
    this.isAdmin = false, // Default to false for security reasons
  });

  /// Factory constructor to create an [AppUser] from Firestore data.
  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      email: data['email'] as String?,
      name: data['name'] as String?,
      surname: data['surname'] as String?,
      address: data['address'] as String?,
      postcode: data['postcode'] as String?,
      city: data['city'] as String?,
      // Read the admin flag from the database, defaulting to false if missing.
      isAdmin: data['isAdmin'] as bool? ?? false, 
    );
  }

  /// Converts the user instance to a Map for database operations.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'surname': surname,
      'address': address,
      'postcode': postcode,
      'city': city,
      'isAdmin': isAdmin, // Persist the admin status to the DB
    };
  }

  /// Creates a copy of this user with the given fields replaced with new values.
  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? surname,
    String? address,
    String? postcode,
    String? city,
    bool? isAdmin,
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
    );
  }
}