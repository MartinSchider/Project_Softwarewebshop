import 'package:flutter_test/flutter_test.dart';
import 'package:webshop/models/app_user.dart';

void main() {
  group('AppUser Model Tests', () {
    test('AppUser should be created with valid data', () {
      final user = AppUser(
        id: 'user-1',
        email: 'test@example.com',
        name: 'Max',
        surname: 'Mustermann',
        address: 'Musterstraße 1',
        postcode: '12345',
        city: 'Musterstadt',
        isAdmin: false,
        isFidelityActive: true,
        fidelityPoints: 100,
      );
      expect(user.id, 'user-1');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Max');
      expect(user.surname, 'Mustermann');
      expect(user.address, 'Musterstraße 1');
      expect(user.postcode, '12345');
      expect(user.city, 'Musterstadt');
      expect(user.isAdmin, false);
      expect(user.isFidelityActive, true);
      expect(user.fidelityPoints, 100);
    });

    test('AppUser copyWith should update fields', () {
      final user = AppUser(
        id: 'user-2',
        email: 'a@b.de',
        name: 'Anna',
        surname: 'Beispiel',
        address: 'Straße 2',
        postcode: '54321',
        city: 'Beispielstadt',
        isAdmin: false,
        isFidelityActive: false,
        fidelityPoints: 0,
      );
      final updated = user.copyWith(email: 'neu@b.de', fidelityPoints: 50);
      expect(updated.email, 'neu@b.de');
      expect(updated.fidelityPoints, 50);
      expect(updated.name, 'Anna');
    });
  });
}
