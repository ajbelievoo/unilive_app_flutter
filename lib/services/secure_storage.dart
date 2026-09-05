import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/log.dart';

/// Secure storage for sensitive data like auth tokens.
///
/// Uses XOR-based obfuscation with a device-specific key derived from
/// a random salt stored alongside the data. This is not as strong as
/// platform keychain/keystore but provides better protection than
/// plain text in SharedPreferences.
///
/// For production, consider migrating to `flutter_secure_storage` which
/// uses platform Keychain (iOS) / KeyStore (Android).
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const String _tag = 'SecureStorage';
  static const String _saltKey = '_ss_salt';
  static const String _prefix = '_enc_';

  Future<void> write(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salt = await _getOrCreateSalt(prefs);
      final encrypted = _obfuscate(value, salt);
      await prefs.setString('$_prefix$key', encrypted);
    } catch (e, s) {
      Log.e(_tag, 'write failed for key: $key', e, s);
    }
  }

  Future<String?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('$_prefix$key');
      if (encrypted == null) return null;
      final salt = await _getOrCreateSalt(prefs);
      return _deobfuscate(encrypted, salt);
    } catch (e, s) {
      Log.e(_tag, 'read failed for key: $key', e, s);
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (e) {
      Log.e(_tag, 'delete failed for key: $key', e);
    }
  }

  Future<String> _getOrCreateSalt(SharedPreferences prefs) async {
    var salt = prefs.getString(_saltKey);
    if (salt == null || salt.isEmpty) {
      final random = Random.secure();
      final bytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        bytes[i] = random.nextInt(256);
      }
      salt = base64.encode(bytes);
      await prefs.setString(_saltKey, salt);
    }
    return salt;
  }

  String _obfuscate(String plaintext, String salt) {
    final saltBytes = Uint8List.fromList(utf8.encode(salt));
    final plainBytes = Uint8List.fromList(utf8.encode(plaintext));
    final result = Uint8List(plainBytes.length);

    for (int i = 0; i < plainBytes.length; i++) {
      result[i] = plainBytes[i] ^ saltBytes[i % saltBytes.length];
    }

    return base64.encode(result);
  }

  String _deobfuscate(String ciphertext, String salt) {
    final saltBytes = Uint8List.fromList(utf8.encode(salt));
    final cipherBytes = base64.decode(ciphertext);
    final result = Uint8List(cipherBytes.length);

    for (int i = 0; i < cipherBytes.length; i++) {
      result[i] = cipherBytes[i] ^ saltBytes[i % saltBytes.length];
    }

    return utf8.decode(result);
  }
}
