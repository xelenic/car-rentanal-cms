import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers which hires the driver has marked "Pickup" — the step between an
/// untouched hire and pressing Start. Kept on the phone: the server's hire
/// status (pending → started → completed) is unchanged, so this works
/// against any server version.
abstract class PickupStore {
  Future<bool> isPickedUp(int hireId);
  Future<void> markPickedUp(int hireId);
  Future<void> clear(int hireId);
}

class SecurePickupStore implements PickupStore {
  static const _key = 'picked_up_hire_ids';

  final FlutterSecureStorage _storage;

  const SecurePickupStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<bool> isPickedUp(int hireId) async => (await _read()).contains(hireId);

  @override
  Future<void> markPickedUp(int hireId) async {
    final ids = await _read()
      ..add(hireId);
    await _write(ids);
  }

  @override
  Future<void> clear(int hireId) async {
    final ids = await _read();
    if (ids.remove(hireId)) await _write(ids);
  }

  // A storage hiccup must never block the driver: reading falls back to
  // "not picked up yet" and a failed write only means tapping Pickup again.
  Future<Set<int>> _read() async {
    try {
      final raw = await _storage.read(key: _key) ?? '';
      return raw.split(',').map(int.tryParse).whereType<int>().toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<void> _write(Set<int> ids) async {
    try {
      await _storage.write(key: _key, value: ids.join(','));
    } catch (_) {}
  }
}
