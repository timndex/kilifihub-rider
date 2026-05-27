import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../config/api_config.dart';
import '../config/app_config.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Background location tracking service
///
/// Uses flutter_background_service to keep GPS tracking alive
/// even when the phone is locked or the app is minimized.
class LocationService {
  static LocationService? _instance;
  final ApiService _api = ApiService.instance;
  final StorageService _storage = StorageService.instance;

  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  LocationService._();

  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  bool get isTracking => _isTracking;

  /// Initialize the background service
  static Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConfig.NOTIFICATION_CHANNEL_ID,
        initialNotificationTitle: AppConfig.BACKGROUND_SERVICE_TITLE,
        initialNotificationContent: AppConfig.BACKGROUND_SERVICE_TEXT,
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter_background_service
    DartPluginRegistrant.ensureInitialized();

    // Location tracking in background
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: ApiConfig.GPS_DISTANCE_FILTER_METERS.toInt(),
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        // Send location to server
        try {
          final storage = StorageService.instance;
          final api = ApiService.instance;

          final token = await storage.getAuthToken();
          if (token != null) {
            await api.updateLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              speed: position.speed,
            );
            await storage.saveLastLocation(position.latitude, position.longitude);
          }
        } catch (e) {
          // Silently fail in background - will retry on next position update
          debugPrint('Background location update failed: $e');
        }
      },
    );

    // Listen for stop command
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  /// Start foreground location tracking
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    // Check and request permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Start the background service
    final service = FlutterBackgroundService();
    await service.startService();

    // Also start foreground stream for in-app map display
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: ApiConfig.GPS_DISTANCE_FILTER_METERS.toInt(),
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      // Send to server
      try {
        await _api.updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
        );
        await _storage.saveLastLocation(position.latitude, position.longitude);
      } catch (e) {
        debugPrint('Foreground location update failed: $e');
      }
    });

    _isTracking = true;
    return true;
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;

    // Stop background service
    final service = FlutterBackgroundService();
    service.invoke('stopService');

    _isTracking = false;
  }

  /// Get current position once
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if location permissions are granted
  Future<bool> hasLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Open device location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
