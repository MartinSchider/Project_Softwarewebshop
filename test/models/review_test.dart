import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/review.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Review Model Tests', () {
    test('Review should be created with valid data', () {
      final now = DateTime.now();
      final review = Review(
        id: 'rev-1',
        userId: 'user-1',
        userName: 'Max',
        productId: 'prod-1',
        rating: 4.5,
        comment: 'Sehr gutes Produkt!',
        timestamp: now,
      );
      expect(review.id, 'rev-1');
      expect(review.userId, 'user-1');
      expect(review.userName, 'Max');
      expect(review.productId, 'prod-1');
      expect(review.rating, 4.5);
      expect(review.comment, 'Sehr gutes Produkt!');
      expect(review.timestamp, now);
    });

    test('Review.fromMap should correctly deserialize data', () {
      final ts = Timestamp.fromDate(DateTime(2023, 1, 1));
      final map = {
        'userId': 'user-2',
        'userName': 'Anna',
        'productId': 'prod-2',
        'rating': 5,
        'comment': 'Top!',
        'timestamp': ts,
      };
      final review = Review.fromMap(map, 'rev-2');
      expect(review.id, 'rev-2');
      expect(review.userId, 'user-2');
      expect(review.userName, 'Anna');
      expect(review.productId, 'prod-2');
      expect(review.rating, 5.0);
      expect(review.comment, 'Top!');
      expect(review.timestamp, DateTime(2023, 1, 1));
    });
  });
}
