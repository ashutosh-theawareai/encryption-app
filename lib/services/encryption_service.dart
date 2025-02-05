import 'dart:convert';
import 'dart:math';
import 'dart:typed_data' show Uint8List;

import 'package:encrypt/encrypt.dart' as encryption;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';

/// Represents encrypted data with its associated metadata
class EncryptedData {
  final String encryptedContent;
  final String iv;
  final String authTag;

  EncryptedData({
    required this.encryptedContent,
    required this.iv,
    required this.authTag,
  });

  Map<String, String> toMap() {
    return {
      'encryptedContent': encryptedContent,
      'iv': iv,
      'authTag': authTag,
    };
  }

  factory EncryptedData.fromMap(Map<String, String> map) {
    return EncryptedData(
      encryptedContent: map['encryptedContent']!,
      iv: map['iv']!,
      authTag: map['authTag']!,
    );
  }
}

/// Result of key generation containing both the key and recovery code
class KeyGenerationResult {
  final String encryptionKey;
  final String recoveryCode;
  final String encryptedKey;

  KeyGenerationResult({
    required this.encryptionKey,
    required this.recoveryCode,
    required this.encryptedKey,
  });
}

/// Service responsible for handling message encryption and decryption
/// using AES-256-GCM encryption standard
class EncryptionService {
  static const String _keyAlias = 'journal_encryption_key';
  static const String _recoveryCodeAlias = 'journal_recovery_code';
  static const String _encryptedKeyAlias = 'journal_encrypted_key';

  final FlutterSecureStorage _secureStorage;
  late final encryption.Key _encryptionKey;
  late final KeyGenerationResult _currentKeyInfo;

  EncryptionService._({
    required FlutterSecureStorage secureStorage,
    required encryption.Key encryptionKey,
    required KeyGenerationResult keyInfo,
  })  : _secureStorage = secureStorage,
        _encryptionKey = encryptionKey,
        _currentKeyInfo = keyInfo;

  static Future<EncryptionService> create({
    FlutterSecureStorage? secureStorage,
  }) async {
    final storage = secureStorage ?? const FlutterSecureStorage();

    // Check if we already have stored keys
    final existingKey = await storage.read(key: _keyAlias);
    final recoveryCode = await storage.read(key: _recoveryCodeAlias);
    final encryptedKey = await storage.read(key: _encryptedKeyAlias);

    if (existingKey != null && recoveryCode != null && encryptedKey != null) {
      final keyInfo = KeyGenerationResult(
        encryptionKey: existingKey,
        recoveryCode: recoveryCode,
        encryptedKey: encryptedKey,
      );
      return EncryptionService._(
        secureStorage: storage,
        encryptionKey: encryption.Key(base64.decode(existingKey)),
        keyInfo: keyInfo,
      );
    }

    // Generate new keys if any are missing
    final keyGenResult = await generateNewKey();
    await storage.write(key: _keyAlias, value: keyGenResult.encryptionKey);
    await storage.write(
        key: _recoveryCodeAlias, value: keyGenResult.recoveryCode);
    await storage.write(
        key: _encryptedKeyAlias, value: keyGenResult.encryptedKey);

    return EncryptionService._(
      secureStorage: storage,
      encryptionKey: encryption.Key(base64.decode(keyGenResult.encryptionKey)),
      keyInfo: keyGenResult,
    );
  }

  /// Get current key information
  KeyGenerationResult getCurrentKeyInfo() {
    return _currentKeyInfo;
  }

  /// Verify if stored key matches current key
  Future<bool> verifyKeyConsistency() async {
    final storedKey = await _secureStorage.read(key: _keyAlias);
    return storedKey == _currentKeyInfo.encryptionKey;
  }

  /// Get all stored key information
  Future<KeyGenerationResult?> getStoredKeyInfo() async {
    final encryptionKey = await _secureStorage.read(key: _keyAlias);
    final recoveryCode = await _secureStorage.read(key: _recoveryCodeAlias);
    final encryptedKey = await _secureStorage.read(key: _encryptedKeyAlias);

    if (encryptionKey != null && recoveryCode != null && encryptedKey != null) {
      return KeyGenerationResult(
        encryptionKey: encryptionKey,
        recoveryCode: recoveryCode,
        encryptedKey: encryptedKey,
      );
    }
    return null;
  }

  /// Clear all stored keys
  Future<void> clearAllKeys() async {
    await _secureStorage.deleteAll();
  }

  /// Generates a new encryption key with recovery code
  static Future<KeyGenerationResult> generateNewKey() async {
    // Generate a random 32-byte key
    final key = encryption.Key.fromSecureRandom(32);
    final keyBase64 = base64.encode(key.bytes);

    // Generate a 10-digit recovery code
    final recoveryCode = generateRecoveryCode();

    // Encrypt the key using the recovery code
    final encryptedKey = _encryptKeyWithRecoveryCode(keyBase64, recoveryCode);

    return KeyGenerationResult(
      encryptionKey: keyBase64,
      recoveryCode: recoveryCode,
      encryptedKey: encryptedKey,
    );
  }

  /// Generate a random 10-digit recovery code
  static String generateRecoveryCode() {
    final random = Random.secure();
    const chars = '0123456789';
    return List.generate(10, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// Encrypt the key using the recovery code
  static String _encryptKeyWithRecoveryCode(String key, String recoveryCode) {
    // Create a key from the recovery code using PBKDF2
    final salt = Uint8List.fromList(
        List<int>.generate(16, (i) => Random.secure().nextInt(256)));
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, 100000, 32)); // 32 bytes = 256 bits
    final derivedKey =
        pbkdf2.process(Uint8List.fromList(recoveryCode.codeUnits));

    // Encrypt the key using AES
    final encrypter = encryption.Encrypter(
      encryption.AES(encryption.Key(derivedKey)),
    );

    final iv = encryption.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(key, iv: iv);

    // Combine salt, IV, and encrypted data
    final combined = {
      'salt': base64.encode(salt),
      'iv': base64.encode(iv.bytes),
      'data': encrypted.base64,
    };

    return base64.encode(utf8.encode(json.encode(combined)));
  }

  /// Encrypts the given text and returns an instance of EncryptedData
  Future<EncryptedData> encryptText(String text) async {
    final iv = encryption.IV.fromSecureRandom(16);

    print('Debug: Encrypting text length: ${text.length}');
    print('Debug: IV length: ${iv.bytes.length}');

    final encrypter = encryption.Encrypter(
      encryption.AES(_encryptionKey, mode: encryption.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(
      text,
      iv: iv,
    );

    // Generate authentication tag using HMAC-SHA256
    final hmac = Hmac(sha256, _encryptionKey.bytes);
    final authTag = hmac
        .convert(
          encrypted.bytes + iv.bytes,
        )
        .toString();

    print('Debug: Auth tag length: ${authTag.length}');

    return EncryptedData(
      encryptedContent: encrypted.base64,
      iv: base64.encode(iv.bytes),
      authTag: authTag,
    );
  }

  /// Decrypts the given encrypted content using the provided IV and authentication tag
  ///
  /// Throws an exception if decryption fails or authentication fails
  Future<String> decryptText({
    required EncryptedData encryptedData,
  }) async {
    try {
      final iv = encryption.IV.fromBase64(encryptedData.iv);
      final encrypted =
          encryption.Encrypted(base64.decode(encryptedData.encryptedContent));

      // Verify authentication tag
      final hmac = Hmac(sha256, _encryptionKey.bytes);
      final computedAuthTag = hmac
          .convert(
            encrypted.bytes + iv.bytes,
          )
          .toString();

      if (computedAuthTag != encryptedData.authTag) {
        throw Exception(
            'Authentication tag mismatch - data may be corrupted or tampered');
      }

      final encrypter = encryption.Encrypter(
        encryption.AES(_encryptionKey, mode: encryption.AESMode.gcm),
      );

      // Decrypt with the same IV used for encryption
      return encrypter.decrypt(
        encrypted,
        iv: iv,
      );
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Decrypt the key using the recovery code
  static String decryptKeyWithRecoveryCode(
      String encryptedKey, String recoveryCode) {
    // Decode the combined data
    final combined = json.decode(utf8.decode(base64.decode(encryptedKey)))
        as Map<String, dynamic>;

    // Extract salt, IV and encrypted data
    final salt = base64.decode(combined['salt']);
    final iv = encryption.IV.fromBase64(combined['iv']);
    final encryptedData = combined['data'];

    // Recreate the key from recovery code using PBKDF2
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(Uint8List.fromList(salt), 100000, 32));
    final derivedKey =
        pbkdf2.process(Uint8List.fromList(recoveryCode.codeUnits));

    // Decrypt the key using AES
    final encrypter = encryption.Encrypter(
      encryption.AES(encryption.Key(derivedKey)),
    );

    return encrypter.decrypt64(encryptedData, iv: iv);
  }

  /// Get detailed key verification information
  Future<String> getKeyVerificationDetails() async {
    final storedKey = await _secureStorage.read(key: _keyAlias);
    return '''
=== Storage Check ===
Stored Key: ${storedKey ?? "No key found"}
Current Key: ${_currentKeyInfo.encryptionKey}
Keys Match: ${storedKey == _currentKeyInfo.encryptionKey ? 'Yes ✓' : 'No ✗'}
''';
  }

  /// Get all key information (synchronous, no delay)
  String getAllKeysInfo() {
    return '''
=== Encryption Key Information ===
Original Encryption Key: ${_currentKeyInfo.encryptionKey}
Recovery Code: ${_currentKeyInfo.recoveryCode}
Encrypted Key: ${_currentKeyInfo.encryptedKey}
Decrypted Key: ${decryptKeyWithRecoveryCode(
      _currentKeyInfo.encryptedKey,
      _currentKeyInfo.recoveryCode,
    )}

=== Verification ===
Keys Match: ${_currentKeyInfo.encryptionKey == decryptKeyWithRecoveryCode(
              _currentKeyInfo.encryptedKey,
              _currentKeyInfo.recoveryCode,
            ) ? 'Yes ✓' : 'No ✗'}
''';
  }
}
