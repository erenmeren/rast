import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over [SharedPreferences] so notifiers can be tested with an
/// in-memory instance and so the storage backend can be swapped later.
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  Set<String> get keys => _prefs.getKeys();

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  List<String>? getStringList(String key) => _prefs.getStringList(key);
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Overridden at bootstrap with the loaded instance.
extension PreferencesStoreKeys on PreferencesStore {
  Future<void> removeWhere(bool Function(String key) test) async {
    for (final k in keys.where(test).toList()) {
      await remove(k);
    }
  }
}

final preferencesStoreProvider = Provider<PreferencesStore>((ref) {
  throw UnimplementedError('preferencesStoreProvider must be overridden');
});
