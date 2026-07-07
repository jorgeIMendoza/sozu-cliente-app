import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Almacenamiento de la sesión de Supabase en secure storage
/// (Keychain iOS / Keystore Android; en web cae a storage cifrado del
/// navegador — limitación de plataforma).
///
/// supabase_flutter usa SharedPreferences por defecto: NO cumple la regla de
/// seguridad SOZU (tokens SIEMPRE en secure storage). Este adapter la cumple.
class SecureSessionStorage extends LocalStorage {
  static const _key = 'sozu_supabase_session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: _key)) != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}
