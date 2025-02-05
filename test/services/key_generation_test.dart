import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:encryption_test_project/services/encryption_service.dart';

void main() {
  group('Key Generation Tests', () {
    test('should generate valid key with recovery code', () async {
      final result = await EncryptionService.generateNewKey();

      // Verify encryption key format
      expect(result.encryptionKey, isNotEmpty);
      final keyBytes = base64.decode(result.encryptionKey);
      expect(keyBytes.length, equals(32)); // 256-bit key

      // Verify recovery code format
      expect(result.recoveryCode.length, equals(10));
      expect(int.tryParse(result.recoveryCode), isNotNull);

      // Verify encrypted key format
      expect(result.encryptedKey, isNotEmpty);
      expect(() => base64.decode(result.encryptedKey), returnsNormally);
    });

    test('should generate unique recovery codes', () async {
      final result1 = await EncryptionService.generateNewKey();
      final result2 = await EncryptionService.generateNewKey();

      expect(result1.recoveryCode, isNot(equals(result2.recoveryCode)));
      expect(result1.encryptionKey, isNot(equals(result2.encryptionKey)));
    });
  });
}
