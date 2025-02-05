import 'package:flutter/material.dart';
import 'services/encryption_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const EncryptionTestScreen(),
    );
  }
}

class EncryptionTestScreen extends StatefulWidget {
  const EncryptionTestScreen({super.key});

  @override
  State<EncryptionTestScreen> createState() => _EncryptionTestScreenState();
}

class _EncryptionTestScreenState extends State<EncryptionTestScreen> {
  late final EncryptionService _encryptionService;
  final TextEditingController _textController = TextEditingController();
  String _result = '';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    _encryptionService = await EncryptionService.create();
    setState(() {});
  }

  Future<void> _testEncryption() async {
    try {
      final text = _textController.text;

      // Encrypt
      final encrypted = await _encryptionService.encryptText(text);

      // Decrypt
      final decrypted = await _encryptionService.decryptText(
        encryptedData: encrypted,
      );

      setState(() {
        _result = '''
Original: $text
Encrypted: ${encrypted.encryptedContent}
IV: ${encrypted.iv}
Auth Tag: ${encrypted.authTag}
Decrypted: $decrypted
''';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    }
  }

  Future<void> _verifyKeyStorage() async {
    final details = await _encryptionService.getKeyVerificationDetails();
    setState(() {
      _result = details;
    });
  }

  Future<void> _testWithExistingKey() async {
    const storage = FlutterSecureStorage();
    final existingKey = await storage.read(key: 'journal_encryption_key');
    if (existingKey != null) {
      final serviceWithExistingKey = await EncryptionService.create();
      final result =
          await serviceWithExistingKey.encryptText('Test with existing key');
      setState(() {
        _result = '''
Used existing key:
Encrypted: ${result.encryptedContent}
IV: ${result.iv}
Auth Tag: ${result.authTag}
''';
      });
    }
  }

  void _showAllKeys() {
    setState(() {
      _result = _encryptionService.getAllKeysInfo();
    });
  }

  Future<void> _clearAllKeys() async {
    await _encryptionService.clearAllKeys();
    setState(() {
      _result = 'All stored keys cleared. Please restart the app.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encryption Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Text to encrypt',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton(
                  key: const Key('encrypt_button'),
                  onPressed: _testEncryption,
                  child: const Text('Test Encryption'),
                ),
                ElevatedButton(
                  key: const Key('check_key_button'),
                  onPressed: _verifyKeyStorage,
                  child: const Text('Check Stored Key'),
                ),
                ElevatedButton(
                  key: const Key('test_existing_button'),
                  onPressed: _testWithExistingKey,
                  child: const Text('Test Existing Key'),
                ),
                ElevatedButton(
                  key: const Key('show_all_keys_button'),
                  onPressed: _showAllKeys,
                  child: const Text('Show All Keys'),
                ),
                ElevatedButton(
                  key: const Key('clear_keys_button'),
                  onPressed: _clearAllKeys,
                  child: const Text('Clear All Keys'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              _result,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
