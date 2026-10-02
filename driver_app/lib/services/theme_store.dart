import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers which theme the driver picked on Appearance, so it survives
/// restarting the app.
abstract class ThemeStore {
  Future<String?> read();
  Future<void> write(String variant);
}

class SecureThemeStore implements ThemeStore {
  static const _key = 'driver_app_theme_variant';

  final FlutterSecureStorage _storage;

  const SecureThemeStore([this._storage = const FlutterSecureStorage()]);

  // A storage hiccup must never block the app — reading falls back to no
  // saved preference (the default theme) and a failed write just means the
  // pick doesn't survive a restart.
  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String variant) async {
    try {
      await _storage.write(key: _key, value: variant);
    } catch (_) {}
  }
}
