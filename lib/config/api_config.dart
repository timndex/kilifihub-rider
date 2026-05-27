/// API Configuration for KilifiHub WordPress Backend
///
/// Update BASE_URL to match your WordPress site URL.
/// All endpoints are relative to BASE_URL.
class ApiConfig {
  // ============================================================
  // IMPORTANT: Change this to your actual WordPress site URL
  // ============================================================
  static const String BASE_URL = 'https://kilifihub.co.ke';

  // REST API prefix
  static const String API_PREFIX = '/wp-json/kilifi/v1';

  // WooCommerce REST API prefix
  static const String WC_API_PREFIX = '/wp-json/wc/v3';

  // WordPress AJAX endpoint
  static const String AJAX_URL = '/wp-admin/admin-ajax.php';

  // ============================================================
  // Auth Endpoints
  // ============================================================
  static const String SEND_OTP = '$API_PREFIX/auth/send-otp';
  static const String VERIFY_OTP = '$API_PREFIX/auth/verify-otp';
  static const String REFRESH_TOKEN = '$API_PREFIX/auth/refresh-token';

  // ============================================================
  // Rider Endpoints
  // ============================================================
  static const String RIDER_PROFILE = '$API_PREFIX/rider/profile';
  static const String RIDER_GO_LIVE = '$API_PREFIX/rider/go-live';
  static const String RIDER_GO_OFFLINE = '$API_PREFIX/rider/go-offline';
  static const String RIDER_UPDATE_LOCATION = '$API_PREFIX/rider/update-location';
  static const String RIDER_EARNINGS = '$API_PREFIX/rider/earnings';
  static const String RIDER_REGISTER_TOKEN = '$API_PREFIX/rider/register-device-token';

  // ============================================================
  // Order Endpoints
  // ============================================================
  static const String RIDER_ORDERS = '$API_PREFIX/rider/orders';
  static const String ORDER_DETAIL = '$API_PREFIX/rider/orders';
  static const String ACCEPT_ORDER = '$API_PREFIX/rider/orders';
  static const String PICKUP_ORDER = '$API_PREFIX/rider/orders';
  static const String COMPLETE_DELIVERY = '$API_PREFIX/rider/orders';

  // ============================================================
  // Rating Endpoints
  // ============================================================
  static const String RATE_RIDER = '$API_PREFIX/rate-rider';

  // ============================================================
  // Timeout Settings (milliseconds)
  // ============================================================
  static const int CONNECT_TIMEOUT = 15000;
  static const int RECEIVE_TIMEOUT = 15000;
  static const int SEND_TIMEOUT = 10000;

  // ============================================================
  // GPS Settings
  // ============================================================
  static const int GPS_UPDATE_INTERVAL_SECONDS = 10;
  static const int GPS_DISTANCE_FILTER_METERS = 5;

  // ============================================================
  // Order Settings
  // ============================================================
  static const int ORDER_ACCEPT_TIMEOUT_SECONDS = 30;
  static const int MAX_CONCURRENT_ORDERS = 10;

  // Helper to build full URL
  static String fullUrl(String endpoint) => '$BASE_URL$endpoint';
}
