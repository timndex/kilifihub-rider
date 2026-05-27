import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/rider_model.dart';

/// Local storage service for persisting rider data
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Keys
  static const String KEY_AUTH_TOKEN = 'auth_token';
  static const String KEY_REFRESH_TOKEN = 'refresh_token';
  static const String KEY_RIDER_PHONE = 'rider_phone';
  static const String KEY_RIDER_DATA = 'rider_data';
  static const String KEY_IS_ONLINE = 'is_online';
  static const String KEY_ONBOARDING_DONE = 'onboarding_done';
  static const String KEY_FCM_TOKEN = 'fcm_token';
  static const String KEY_LAST_LOCATION_LAT = 'last_location_lat';
  static const String KEY_LAST_LOCATION_LNG = 'last_location_lng';
  static const String KEY_LAST_LOCATION_TIME = 'last_location_time';

  // ============================================================
  // Auth Token
  // ============================================================

  Future<void> saveAuthToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_AUTH_TOKEN, token);
  }

  Future<String?> getAuthToken() async {
    final prefs = await _preferences;
    return prefs.getString(KEY_AUTH_TOKEN);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_REFRESH_TOKEN, token);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _preferences;
    return prefs.getString(KEY_REFRESH_TOKEN);
  }

  Future<void> clearTokens() async {
    final prefs = await _preferences;
    await prefs.remove(KEY_AUTH_TOKEN);
    await prefs.remove(KEY_REFRESH_TOKEN);
  }

  // ============================================================
  // Rider Phone (for auto-login)
  // ============================================================

  Future<void> saveRiderPhone(String phone) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_RIDER_PHONE, phone);
  }

  Future<String?> getRiderPhone() async {
    final prefs = await _preferences;
    return prefs.getString(KEY_RIDER_PHONE);
  }

  // ============================================================
  // Rider Profile
  // ============================================================

  Future<void> saveRiderData(RiderModel rider) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_RIDER_DATA, jsonEncode(rider.toJson()));
  }

  Future<RiderModel?> getRiderData() async {
    final prefs = await _preferences;
    final data = prefs.getString(KEY_RIDER_DATA);
    if (data != null) {
      return RiderModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
    }
    return null;
  }

  // ============================================================
  // Online Status
  // ============================================================

  Future<void> saveIsOnline(bool isOnline) async {
    final prefs = await _preferences;
    await prefs.setBool(KEY_IS_ONLINE, isOnline);
  }

  Future<bool> getIsOnline() async {
    final prefs = await _preferences;
    return prefs.getBool(KEY_IS_ONLINE) ?? false;
  }

  // ============================================================
  // FCM Token
  // ============================================================

  Future<void> saveFcmToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(KEY_FCM_TOKEN, token);
  }

  Future<String?> getFcmToken() async {
    final prefs = await _preferences;
    return prefs.getString(KEY_FCM_TOKEN);
  }

  // ============================================================
  // Last Known Location
  // ============================================================

  Future<void> saveLastLocation(double lat, double lng) async {
    final prefs = await _preferences;
    await prefs.setDouble(KEY_LAST_LOCATION_LAT, lat);
    await prefs.setDouble(KEY_LAST_LOCATION_LNG, lng);
    await prefs.setInt(KEY_LAST_LOCATION_TIME, DateTime.now().millisecondsSinceEpoch);
  }

  Future<Map<String, double>?> getLastLocation() async {
    final prefs = await _preferences;
    final lat = prefs.getDouble(KEY_LAST_LOCATION_LAT);
    final lng = prefs.getDouble(KEY_LAST_LOCATION_LNG);
    if (lat != null && lng != null) {
      return {'latitude': lat, 'longitude': lng};
    }
    return null;
  }

  // ============================================================
  // Onboarding
  // ============================================================

  Future<void> setOnboardingDone() async {
    final prefs = await _preferences;
    await prefs.setBool(KEY_ONBOARDING_DONE, true);
  }

  Future<bool> isOnboardingDone() async {
    final prefs = await _preferences;
    return prefs.getBool(KEY_ONBOARDING_DONE) ?? false;
  }

  // ============================================================
  // Clear All (Logout)
  // ============================================================

  Future<void> clearAll() async {
    final prefs = await _preferences;
    // Keep onboarding status
    final onboardingDone = prefs.getBool(KEY_ONBOARDING_DONE) ?? false;
    await prefs.clear();
    if (onboardingDone) {
      await prefs.setBool(KEY_ONBOARDING_DONE, true);
    }
  }
}
