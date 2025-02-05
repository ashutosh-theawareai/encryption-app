# Chakravyuh Encryption Service(CES)

## Overview
This project implements a secure encryption system using AES-256-GCM for text encryption with key recovery capabilities. The implementation follows cryptographic best practices and provides secure key storage using Flutter's secure storage mechanisms.

## Core Components

### 1. Encryption Service (`EncryptionService` class)
The main service that handles all encryption operations, including:
- Key generation and management
- Text encryption and decryption
- Key recovery system
- Secure storage integration

### 2. Key Management System
- **Key Type**: AES-256 (32 bytes)
- **Storage**: Flutter Secure Storage
- **Recovery System**: 10-digit numeric recovery code
- **Key Protection**: Keys are encrypted before storage
- **Storage Keys**:
  - `journal_encryption_key`: Main encryption key
  - `journal_recovery_code`: Recovery code
  - `journal_encrypted_key`: Encrypted version of the main key

## Technical Specifications

### Encryption Details
- **Algorithm**: AES-256-GCM (Galois/Counter Mode)
- **IV (Initialization Vector)**: 16 bytes, randomly generated for each encryption
- **Key Size**: 32 bytes (256 bits)
- **Authentication Tag**: HMAC-SHA256 (64 characters)
- **Key Format**: Base64 encoded for storage

### Constraints and Limitations

#### Text Length
1. **Input Text Size**:
   - Theoretical maximum: No hard limit from AES encryption
   - Practical recommendations:
     - Single encryption: < 10MB for optimal performance
     - Large texts: Should be split into smaller chunks
   - Base64 encoding increases output size by ~33%

2. **Output Characteristics**:
   - Encrypted text will always be longer than input text due to:
     - Base64 encoding (33% increase)
     - IV (16 bytes)
     - Authentication tag (32 bytes)
     - Formula: `output_length ≈ (input_length * 1.33) + 64 bytes`

3. **Performance Considerations**:
   - < 1KB: Near instant encryption/decryption
   - 1MB: ~10ms processing time
   - 10MB: ~100ms processing time
   - > 10MB: Consider chunking data

4. **Memory Usage**:
   - Runtime memory: ~3x input size during encryption
   - Temporary storage: ~2x input size

- **Recovery Code Format**: 10 digits numeric (e.g., "1234567890")
- **Key Storage Space**: Approximately 100 bytes per key set
- **Minimum Android SDK**: 23 (Android 6.0)

### Security Features
1. **Encryption**:
   - AES-256-GCM for authenticated encryption
   - Random IV generation for each encryption
   - Authentication tag verification
   
2. **Key Protection**:
   - PBKDF2 key derivation (100,000 iterations)
   - Secure random number generation
   - Platform-specific secure storage

## Usage Guide

### 1. Service Initialization

```dart
final encryptionService = await EncryptionService.create();
```


### 2. Text Encryption

```dart
final encrypted = await encryptionService.encryptText('Hello, world!');
```



### 3. Decrypt text

```dart
// Decrypt text
final decryptedText = await encryptionService.decryptText(
encryptedData: encryptedData,
);
```


### 4. Key Information


```dart
// Get current key information
final keyInfo = encryptionService.getCurrentKeyInfo();
print('Encryption Key: ${keyInfo.encryptionKey}');
print('Recovery Code: ${keyInfo.recoveryCode}');
```


### 5. Key Recovery

```dart
// Decrypt key using recovery code
final decryptedKey = EncryptionService.decryptKeyWithRecoveryCode(
encryptedKey,
recoveryCode,
);
```



## Security Considerations

### Key Storage Security
- Keys are never stored in plaintext
- Secure storage uses platform-specific encryption:
  - iOS: Keychain
  - Android: EncryptedSharedPreferences
  - Web: localStorage with additional encryption

### Recovery System Security
- Recovery codes use PBKDF2 for key derivation
- Separate storage of encrypted key and recovery code
- Built-in authentication prevents tampering
- Rate limiting recommended for recovery attempts

### Best Practices
1. Clear keys when application is backgrounded
2. Always verify authentication tags
3. Use secure random number generation
4. Implement rate limiting for recovery attempts
5. Regular key rotation (recommended every 90 days)
6. Backup encrypted keys securely

## Error Handling

### Common Errors and Solutions

1. **Authentication Failed**
   - Cause: Data tampering or corruption
   - Solution: Re-encrypt data with fresh IV

2. **Decryption Failed**
   - Cause: Wrong key or corrupted data
   - Solution: Verify key and data integrity

3. **Invalid Recovery Code**
   - Cause: Incorrect format or digits
   - Solution: Verify 10-digit numeric format

4. **Storage Access Failed**
   - Cause: Platform security issues
   - Solution: Check permissions and platform support

## Testing
The project includes comprehensive tests covering:
- Key generation and format validation
- Encryption and decryption operations
- Recovery code system
- Storage integration
- Error handling

## Dependencies

```yaml
dependencies:
encrypt: ^5.0.3
flutter_secure_storage: ^10.0.0-beta.4
crypto: ^3.0.3
pointycastle: ^3.7.3
```

## Platform Support

### iOS
- Full support with Keychain integration
- Secure enclave usage where available
- Background data protection

### Android
- Full support with EncryptedSharedPreferences
- Minimum SDK 23 required
- Hardware security module support where available

### Web
- Limited secure storage support
- Additional encryption layer for localStorage
- Not recommended for highly sensitive data

## Implementation Notes

### Key Generation Process
1. Generate random 32-byte key
2. Generate random 10-digit recovery code
3. Encrypt key with recovery code using PBKDF2
4. Store encrypted key and recovery code separately

### Encryption Process
1. Generate random 16-byte IV
2. Encrypt data using AES-256-GCM
3. Generate authentication tag
4. Combine IV, ciphertext, and tag

### Recovery Process
1. Input recovery code
2. Derive key using PBKDF2
3. Decrypt stored encrypted key
4. Verify key integrity

## Performance Considerations
- Key generation: ~100ms
- Encryption: ~10ms per MB
- Decryption: ~10ms per MB
- Recovery code verification: ~200ms
