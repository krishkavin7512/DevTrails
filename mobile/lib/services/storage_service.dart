import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async =>
      _prefs?.setString('auth_token', token);

  Future<String?> getToken() async => _prefs?.getString('auth_token');

  Future<void> clearToken() async => _prefs?.remove('auth_token');

  // ── Rider ID ──────────────────────────────────────────────────────────────

  Future<void> saveRiderId(String id) async =>
      _prefs?.setString('rider_id', id);

  Future<String?> getRiderId() async => _prefs?.getString('rider_id');

  Future<void> clearRiderId() async => _prefs?.remove('rider_id');

  // ── Onboarding ────────────────────────────────────────────────────────────

  Future<void> setOnboardingDone() async =>
      _prefs?.setBool('onboarding_done', true);

  Future<bool> isOnboardingDone() async =>
      _prefs?.getBool('onboarding_done') ?? false;

  // ── Raw prefs access (for services that need key/value storage) ──────────

  Future<SharedPreferences> getPrefsInstance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Clear all ─────────────────────────────────────────────────────────────

  Future<void> clearAll() async => _prefs?.clear();
}
