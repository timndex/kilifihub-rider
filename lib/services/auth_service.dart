import 'package:flutter/foundation.dart';
import '../models/rider_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Authentication service - handles login, OTP, session management
class AuthService extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  RiderModel? _rider;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  RiderModel? get rider => _rider;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Check if user has an existing session on app start
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.getAuthToken();
      if (token != null && token.isNotEmpty) {
        // Try to fetch profile with existing token
        final profileData = await _api.getRiderProfile();
        _rider = RiderModel.fromJson(profileData);
        _isLoggedIn = true;
        await _storage.saveRiderData(_rider!);
      }
    } catch (e) {
      // Token expired or invalid - clear session
      await _storage.clearTokens();
      _isLoggedIn = false;
      _rider = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Send OTP to phone number
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.sendOtp(phone);
      _isLoading = false;

      if (response['success'] == true) {
        await _storage.saveRiderPhone(phone);
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to send OTP';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP and complete login
  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.verifyOtp(phone, otp);

      if (response['success'] == true) {
        // Save tokens
        final token = response['token'] as String?;
        final refreshToken = response['refresh_token'] as String?;
        if (token != null) {
          await _storage.saveAuthToken(token);
          if (refreshToken != null) {
            await _storage.saveRefreshToken(refreshToken);
          }
        }

        // Save rider data
        final riderData = response['rider'] as Map<String, dynamic>?;
        if (riderData != null) {
          _rider = RiderModel.fromJson(riderData);
          await _storage.saveRiderData(_rider!);
        } else {
          // Fetch profile if not included in response
          final profileData = await _api.getRiderProfile();
          _rider = RiderModel.fromJson(profileData);
          await _storage.saveRiderData(_rider!);
        }

        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Invalid OTP';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _rider = null;
    _isLoggedIn = false;
    await _storage.clearAll();
    notifyListeners();
  }

  /// Update rider data locally
  void updateRider(RiderModel rider) {
    _rider = rider;
    _storage.saveRiderData(rider);
    notifyListeners();
  }

  /// Extract error message from exception
  String _extractError(dynamic e) {
    if (e.toString().contains('SocketException') ||
        e.toString().contains('Connection refused')) {
      return 'No internet connection. Please check your network.';
    }
    if (e.toString().contains('TimeoutException')) {
      return 'Connection timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
