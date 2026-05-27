import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

/// Centralized API service for all WordPress backend communication
class ApiService {
  static ApiService? _instance;
  late final Dio _dio;
  final StorageService _storage = StorageService();

  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.BASE_URL,
      connectTimeout: Duration(milliseconds: ApiConfig.CONNECT_TIMEOUT),
      receiveTimeout: Duration(milliseconds: ApiConfig.RECEIVE_TIMEOUT),
      sendTimeout: Duration(milliseconds: ApiConfig.SEND_TIMEOUT),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add auth token interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 - token expired
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the request with new token
            final token = await _storage.getAuthToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        handler.next(error);
      },
    ));

    // Add logging in debug mode
    _dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      compact: true,
    ));
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  Dio get dio => _dio;

  /// Attempt to refresh the JWT token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post(
        ApiConfig.REFRESH_TOKEN,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newToken = response.data['token'] as String?;
        final newRefresh = response.data['refresh_token'] as String?;
        if (newToken != null) {
          await _storage.saveAuthToken(newToken);
          if (newRefresh != null) {
            await _storage.saveRefreshToken(newRefresh);
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // AUTH ENDPOINTS
  // ============================================================

  /// Send OTP to rider's phone number
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await _dio.post(
      ApiConfig.SEND_OTP,
      data: {'phone': phone},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Verify OTP and login
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await _dio.post(
      ApiConfig.VERIFY_OTP,
      data: {'phone': phone, 'otp': otp},
    );
    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // RIDER ENDPOINTS
  // ============================================================

  /// Get rider profile
  Future<Map<String, dynamic>> getRiderProfile() async {
    final response = await _dio.get(ApiConfig.RIDER_PROFILE);
    return response.data as Map<String, dynamic>;
  }

  /// Set rider as online (go live)
  Future<Map<String, dynamic>> goLive() async {
    final response = await _dio.post(ApiConfig.RIDER_GO_LIVE);
    return response.data as Map<String, dynamic>;
  }

  /// Set rider as offline
  Future<Map<String, dynamic>> goOffline() async {
    final response = await _dio.post(ApiConfig.RIDER_GO_OFFLINE);
    return response.data as Map<String, dynamic>;
  }

  /// Update rider GPS location
  Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
  }) async {
    final response = await _dio.post(
      ApiConfig.RIDER_UPDATE_LOCATION,
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null) 'speed': speed,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get rider earnings
  Future<Map<String, dynamic>> getEarnings({String? period}) async {
    final response = await _dio.get(
      ApiConfig.RIDER_EARNINGS,
      queryParameters: {if (period != null) 'period': period},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Register FCM device token
  Future<Map<String, dynamic>> registerDeviceToken(String token) async {
    final response = await _dio.post(
      ApiConfig.RIDER_REGISTER_TOKEN,
      data: {'device_token': token, 'platform': 'android'},
    );
    return response.data as Map<String, dynamic>;
  }

  // ============================================================
  // ORDER ENDPOINTS
  // ============================================================

  /// Get rider's active orders
  Future<List<Map<String, dynamic>>> getOrders({String? status}) async {
    final response = await _dio.get(
      ApiConfig.RIDER_ORDERS,
      queryParameters: {if (status != null) 'status': status},
    );
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Get single order detail
  Future<Map<String, dynamic>> getOrderDetail(int orderId) async {
    final response = await _dio.get('${ApiConfig.ORDER_DETAIL}/$orderId');
    return response.data as Map<String, dynamic>;
  }

  /// Accept an order
  Future<Map<String, dynamic>> acceptOrder(int orderId) async {
    final response = await _dio.post(
      '${ApiConfig.ACCEPT_ORDER}/$orderId/accept',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Mark order as picked up
  Future<Map<String, dynamic>> pickUpOrder(int orderId) async {
    final response = await _dio.post(
      '${ApiConfig.PICKUP_ORDER}/$orderId/pickup',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Mark order as delivered
  Future<Map<String, dynamic>> completeDelivery(int orderId) async {
    final response = await _dio.post(
      '${ApiConfig.COMPLETE_DELIVERY}/$orderId/complete',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Decline an order
  Future<Map<String, dynamic>> declineOrder(int orderId) async {
    final response = await _dio.post(
      '${ApiConfig.ACCEPT_ORDER}/$orderId/decline',
    );
    return response.data as Map<String, dynamic>;
  }
}
