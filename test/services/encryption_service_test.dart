import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:encryption_test_project/services/encryption_service.dart';
import 'dart:convert';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late EncryptionService encryptionService;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    when(() => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) => Future.value());
  });

  group('EncryptionService', () {
    test('should encrypt and decrypt text successfully', () async {
      encryptionService = await EncryptionService.create(
        secureStorage: mockSecureStorage,
      );

      const originalText = 'Hello, World!';
      final encrypted = await encryptionService.encryptText(originalText);

      expect(encrypted.encryptedContent, isNotNull);
      expect(encrypted.iv, isNotNull);
      expect(encrypted.authTag, isNotNull);

      final decrypted = await encryptionService.decryptText(
        encryptedData: encrypted,
      );

      expect(decrypted, equals(originalText));
    });

    test('should throw exception for tampered content', () async {
      encryptionService = await EncryptionService.create(
        secureStorage: mockSecureStorage,
      );

      const originalText = 'Hello, World!';
      final encrypted = await encryptionService.encryptText(originalText);
      final tamperedData = EncryptedData(
        encryptedContent: '${encrypted.encryptedContent}tampered',
        iv: encrypted.iv,
        authTag: encrypted.authTag,
      );

      expect(
        () => encryptionService.decryptText(
          encryptedData: tamperedData,
        ),
        throwsException,
      );
    });

    test('should use existing key without storing when provided', () async {
      base64.encode(List<int>.filled(32, 1));

      encryptionService = await EncryptionService.create(
        secureStorage: mockSecureStorage,
      );

      verifyNever(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ));

      const originalText = 'Test with existing key';
      final encrypted = await encryptionService.encryptText(originalText);
      final decrypted = await encryptionService.decryptText(
        encryptedData: encrypted,
      );

      expect(decrypted, equals(originalText));
    });
  });
}
