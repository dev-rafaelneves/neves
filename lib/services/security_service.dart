import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _keySecurePinHash = 'neves_pin_sha256';
  static const String _keySecurePinSalt = 'neves_pin_salt';
  static const String _keyFailedAttempts = 'neves_failed_pin_attempts';
  static const String _keyLockoutUntil = 'neves_lockout_until_iso';
  static const String _keyBiometricsEnabled = 'neves_biometrics_enabled';
  static const String _keyBlockScreenshots = 'neves_block_screenshots';

  static const MethodChannel _securityChannel =
      MethodChannel('com.rafaelneves.neves/security');

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static final LocalAuthentication _localAuth = LocalAuthentication();

  @visibleForTesting
  static final Map<String, String> inMemorySecureStore = {};

  static bool get isTestEnvironment {
    try {
      return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hashPin(String pin, String salt) {
    final input = '$salt:$pin';
    return sha256.convert(utf8.encode(input)).toString();
  }

  static Future<void> saveSecurePin(String pin) async {
    final salt = generateSalt();
    final hashed = hashPin(pin, salt);

    inMemorySecureStore[_keySecurePinSalt] = salt;
    inMemorySecureStore[_keySecurePinHash] = hashed;

    if (isTestEnvironment) return;

    try {
      await _secureStorage
          .write(key: _keySecurePinSalt, value: salt)
          .timeout(const Duration(milliseconds: 500));
      await _secureStorage
          .write(key: _keySecurePinHash, value: hashed)
          .timeout(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Aviso ao salvar no FlutterSecureStorage: $e');
    }
  }

  static Future<void> removeSecurePin() async {
    inMemorySecureStore.remove(_keySecurePinSalt);
    inMemorySecureStore.remove(_keySecurePinHash);

    if (isTestEnvironment) return;

    try {
      await _secureStorage
          .delete(key: _keySecurePinSalt)
          .timeout(const Duration(milliseconds: 500));
      await _secureStorage
          .delete(key: _keySecurePinHash)
          .timeout(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Aviso ao deletar do FlutterSecureStorage: $e');
    }
  }

  static Future<bool> hasSecurePin() async {
    if (inMemorySecureStore.containsKey(_keySecurePinHash)) return true;
    if (isTestEnvironment) return false;

    try {
      final hash = await _secureStorage
          .read(key: _keySecurePinHash)
          .timeout(const Duration(milliseconds: 500));
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifyPin(String candidatePin) async {
    String? salt = inMemorySecureStore[_keySecurePinSalt];
    String? storedHash = inMemorySecureStore[_keySecurePinHash];

    if ((salt == null || storedHash == null) && !isTestEnvironment) {
      try {
        salt = await _secureStorage
            .read(key: _keySecurePinSalt)
            .timeout(const Duration(milliseconds: 500));
        storedHash = await _secureStorage
            .read(key: _keySecurePinHash)
            .timeout(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('Erro ao ler PIN do secure storage: $e');
      }
    }

    if (salt == null || storedHash == null) return false;

    final candidateHash = hashPin(candidatePin.trim(), salt);
    return candidateHash == storedHash;
  }

  static int calculateLockoutSeconds(int attempts) {
    if (attempts < 5) return 0;
    if (attempts == 5) return 30;
    if (attempts == 6) return 60;
    return 300;
  }

  static Future<DateTime?> recordFailedAttempt(SharedPreferences? prefs) async {
    final currentAttempts = (prefs?.getInt(_keyFailedAttempts) ?? 0) + 1;
    await prefs?.setInt(_keyFailedAttempts, currentAttempts);

    final lockoutSeconds = calculateLockoutSeconds(currentAttempts);
    if (lockoutSeconds > 0) {
      final lockoutUntil =
          DateTime.now().add(Duration(seconds: lockoutSeconds));
      await prefs?.setString(_keyLockoutUntil, lockoutUntil.toIso8601String());
      return lockoutUntil;
    }
    return null;
  }

  static Future<void> resetFailedAttempts(SharedPreferences? prefs) async {
    await prefs?.remove(_keyFailedAttempts);
    await prefs?.remove(_keyLockoutUntil);
  }

  static int getFailedAttempts(SharedPreferences? prefs) {
    return prefs?.getInt(_keyFailedAttempts) ?? 0;
  }

  static DateTime? getLockoutUntil(SharedPreferences? prefs) {
    final raw = prefs?.getString(_keyLockoutUntil);
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw);
      if (dt.isAfter(DateTime.now())) {
        return dt;
      }
    } catch (_) {}
    return null;
  }

  static int getRemainingLockoutSeconds(DateTime? lockoutUntil) {
    if (lockoutUntil == null) return 0;
    final diff = lockoutUntil.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  static Future<bool> canAuthenticateWithBiometrics() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateBiometric({
    String localizedReason = 'Confirme sua biometria para acessar o Neves',
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Aviso de erro na autenticação biométrica: $e');
      return false;
    }
  }

  static Future<void> setFlagSecure(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _securityChannel
          .invokeMethod('setFlagSecure', {'enabled': enabled});
    } catch (_) {}
  }

  static bool isBiometricsEnabled(SharedPreferences? prefs) {
    return prefs?.getBool(_keyBiometricsEnabled) ?? true;
  }

  static Future<void> setBiometricsEnabled(
    SharedPreferences? prefs,
    bool enabled,
  ) async {
    await prefs?.setBool(_keyBiometricsEnabled, enabled);
  }

  static bool isBlockScreenshotsEnabled(SharedPreferences? prefs) {
    return prefs?.getBool(_keyBlockScreenshots) ?? true;
  }

  static Future<void> setBlockScreenshotsEnabled(
    SharedPreferences? prefs,
    bool enabled,
  ) async {
    await prefs?.setBool(_keyBlockScreenshots, enabled);
    await setFlagSecure(enabled);
  }
}
