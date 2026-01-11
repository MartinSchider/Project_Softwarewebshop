// lib/models/review.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a customer review for a specific product.
///
/// This data model encapsulates the user's feedback, including the numerical
/// rating, textual comment, and associated metadata (who wrote it and when).
class Review {
  /// The unique identifier of the review document in Cloud Firestore.
  final String id;

  /// The unique identifier (UID) of the user who submitted the review.
  final String userId;

  /// The display name of the user at the time the review was written.
  ///
  /// Stored here to avoid fetching the user profile every time a review is displayed.
  final String userName;

  /// The unique identifier of the product being reviewed.
  final String productId;

  /// The numerical score given by the user (typically 1.0 to 5.0).
  final double rating;

  /// The textual content of the feedback.
  final String comment;

  /// The date and time when the review was created.
  final DateTime timestamp;

  /// Creates a [Review] instance.
  Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.productId,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  /// Factory constructor to create a [Review] instance from a Firestore Map.
  ///
  /// This method includes robust error handling and type casting to ensure
  /// the app doesn't crash if database fields are missing or have unexpected types.
  ///
  /// * [data]: The raw key-value map from the Firestore snapshot.
  /// * [id]: The document ID.
  factory Review.fromMap(Map<String, dynamic> data, String id) {
    return Review(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      productId: data['productId'] ?? '',
      // Safe casting: Handles both 'int' and 'double' types from the DB.
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      comment: data['comment'] ?? '',
      // Safe casting: Converts Firestore Timestamp to Dart DateTime.
      // Defaults to current time if the field is null (e.g., immediate local optimistic update).
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts the [Review] instance to a JSON-compatible Map.
  ///
  /// This method is used when writing data to Cloud Firestore.
  ///
  /// **Note:** The `timestamp` field uses [FieldValue.serverTimestamp()] to ensure
  /// consistency based on the server's time, rather than the client device's time.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'productId': productId,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}