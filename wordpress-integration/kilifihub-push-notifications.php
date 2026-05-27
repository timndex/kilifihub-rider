<?php
/**
 * KilifiHub Rider App - WordPress Server-Side Push Notification Integration
 *
 * This file adds Firebase Cloud Messaging (FCM) push notification support
 * to your WordPress backend so the Flutter rider app can receive
 * notifications even when the phone is locked.
 *
 * INSTALLATION:
 * 1. Add this code to your theme's functions.php or create a separate plugin
 * 2. Set your Firebase Server Key below
 * 3. The Flutter app will register device tokens automatically
 *
 * @package KilifiHub
 * @version 1.0.0
 */

// ============================================================
// CONFIGURATION - Firebase Service Account
// ============================================================
//
// HOW TO SET UP:
// 1. Go to Firebase Console → Project Settings → Service Accounts
// 2. Click "Generate new private key" → Download JSON file
// 3. Upload that JSON file to your server (outside public_html for security)
// 4. Set the path below to where you saved the file
//
// SECURITY: Keep the JSON file OUT of the public web directory!
// Good location: /home/youruser/firebase-service-account.json
// Bad location: /public_html/firebase-service-account.json

if (!defined('KILIFIHUB_FIREBASE_CREDENTIALS_PATH')) {
    // UPDATE THIS PATH to where you saved the Firebase private key JSON file
    define('KILIFIHUB_FIREBASE_CREDENTIALS_PATH', '/home/youruser/kilifihub-rider-firebase.json');
}

// Firebase project ID (auto-detected from credentials file)
if (!defined('KILIFIHUB_FIREBASE_PROJECT_ID')) {
    define('KILIFIHUB_FIREBASE_PROJECT_ID', 'kilifihub-rider');
}

// FCM v1 API endpoint
if (!defined('KILIFIHUB_FCM_V1_ENDPOINT')) {
    define('KILIFIHUB_FCM_V1_ENDPOINT', 'https://fcm.googleapis.com/v1/projects/' . KILIFIHUB_FIREBASE_PROJECT_ID . '/messages:send');
}

// Google OAuth2 token endpoint
if (!defined('KILIFIHUB_GOOGLE_TOKEN_ENDPOINT')) {
    define('KILIFIHUB_GOOGLE_TOKEN_ENDPOINT', 'https://oauth2.googleapis.com/token');
}

// Cache access token for 50 minutes (tokens last 60 min)
if (!defined('KILIFIHUB_FCM_TOKEN_CACHE_KEY')) {
    define('KILIFIHUB_FCM_TOKEN_CACHE_KEY', 'kilifihub_fcm_access_token');
}

// ============================================================
// 1. REST API ROUTES FOR THE FLUTTER APP
// ============================================================

/**
 * Register all REST API routes for the rider app
 */
add_action('rest_api_init', function () {

    // Rider profile
    register_rest_route('kilifi/v1', '/rider/profile', [
        'methods'             => 'GET',
        'callback'            => 'kilifihub_rest_rider_profile',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Go live
    register_rest_route('kilifi/v1', '/rider/go-live', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_rider_go_live',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Go offline
    register_rest_route('kilifi/v1', '/rider/go-offline', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_rider_go_offline',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Update location
    register_rest_route('kilifi/v1', '/rider/update-location', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_rider_update_location',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Register device token (for push notifications)
    register_rest_route('kilifi/v1', '/rider/register-device-token', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_register_device_token',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Get rider orders
    register_rest_route('kilifi/v1', '/rider/orders', [
        'methods'             => 'GET',
        'callback'            => 'kilifihub_rest_rider_orders',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Get single order detail
    register_rest_route('kilifi/v1', '/rider/orders/(?P<order_id>\d+)', [
        'methods'             => 'GET',
        'callback'            => 'kilifihub_rest_rider_order_detail',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Accept order
    register_rest_route('kilifi/v1', '/rider/orders/(?P<order_id>\d+)/accept', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_accept_order',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Pick up order
    register_rest_route('kilifi/v1', '/rider/orders/(?P<order_id>\d+)/pickup', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_pickup_order',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Complete delivery
    register_rest_route('kilifi/v1', '/rider/orders/(?P<order_id>\d+)/complete', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_complete_delivery',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Decline order
    register_rest_route('kilifi/v1', '/rider/orders/(?P<order_id>\d+)/decline', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_decline_order',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // Rider earnings
    register_rest_route('kilifi/v1', '/rider/earnings', [
        'methods'             => 'GET',
        'callback'            => 'kilifihub_rest_rider_earnings',
        'permission_callback' => 'kilifihub_rest_rider_auth',
    ]);

    // OTP authentication
    register_rest_route('kilifi/v1', '/auth/send-otp', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_send_otp',
        'permission_callback' => '__return_true',
    ]);

    register_rest_route('kilifi/v1', '/auth/verify-otp', [
        'methods'             => 'POST',
        'callback'            => 'kilifihub_rest_verify_otp',
        'permission_callback' => '__return_true',
    ]);
});

// ============================================================
// 2. AUTHENTICATION HELPERS
// ============================================================

/**
 * Check if the current request is from an authenticated rider
 * Uses JWT token from the Authorization header
 */
function kilifihub_rest_rider_auth(WP_REST_Request $request) {
    $auth_header = $request->get_header('authorization');

    if (!$auth_header || strpos($auth_header, 'Bearer ') !== 0) {
        return new WP_Error(
            'rest_forbidden',
            'Authentication required. Please login.',
            ['status' => 401]
        );
    }

    $token = substr($auth_header, 7);

    // If JWT Auth plugin is active, validate the token
    if (class_exists('Jwt_Auth')) {
        $user_id = kilifihub_validate_jwt_token($token);
        if (!$user_id) {
            return new WP_Error(
                'rest_forbidden',
                'Invalid or expired token.',
                ['status' => 401]
            );
        }

        $user = get_user_by('id', $user_id);
        if (!$user || !in_array('kilifi_rider', $user->roles)) {
            return new WP_Error(
                'rest_forbidden',
                'Access denied. Rider account required.',
                ['status' => 403]
            );
        }

        return true;
    }

    // Fallback: check WordPress nonce/cookie auth
    if (!is_user_logged_in()) {
        return new WP_Error(
            'rest_forbidden',
            'Authentication required.',
            ['status' => 401]
        );
    }

    $user = wp_get_current_user();
    if (!in_array('kilifi_rider', $user->roles)) {
        return new WP_Error(
            'rest_forbidden',
            'Access denied. Rider account required.',
            ['status' => 403]
        );
    }

    return true;
}

/**
 * Validate JWT token and return user ID
 */
function kilifihub_validate_jwt_token($token) {
    try {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return false;
        }

        $payload = json_decode(base64_decode(strtr($parts[1], '-_', '+/')), true);

        if (!$payload) {
            return false;
        }

        // Try different payload structures
        $user_id = null;
        if (isset($payload['data']['user']->id)) {
            $user_id = intval($payload['data']['user']->id);
        } elseif (isset($payload['data']['user']['id'])) {
            $user_id = intval($payload['data']['user']['id']);
        } elseif (isset($payload['user_id'])) {
            $user_id = intval($payload['user_id']);
        } elseif (isset($payload['sub'])) {
            $user_id = intval($payload['sub']);
        }

        if (!$user_id) {
            return false;
        }

        // Check expiration
        if (isset($payload['exp']) && $payload['exp'] < time()) {
            return false;
        }

        return $user_id;

    } catch (Exception $e) {
        return false;
    }
}

/**
 * Get the authenticated rider's user ID from the request
 */
function kilifihub_get_rider_id(WP_REST_Request $request) {
    $auth_header = $request->get_header('authorization');
    if ($auth_header && strpos($auth_header, 'Bearer ') === 0) {
        $token = substr($auth_header, 7);
        $user_id = kilifihub_validate_jwt_token($token);
        if ($user_id) {
            return $user_id;
        }
    }

    $user = wp_get_current_user();
    return $user->ID;
}

// ============================================================
// 3. REST API CALLBACKS
// ============================================================

/**
 * Get rider profile
 */
function kilifihub_rest_rider_profile(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);
    $user = get_user_by('id', $rider_id);

    if (!$user) {
        return new WP_Error('not_found', 'Rider not found', ['status' => 404]);
    }

    return rest_ensure_response([
        'success' => true,
        'id'      => $user->ID,
        'name'    => $user->display_name,
        'phone'   => get_user_meta($user->ID, 'billing_phone', true),
        'email'   => $user->user_email,
        'avatar_url' => get_avatar_url($user->ID, ['size' => 256]),
        'is_online'  => get_user_meta($user->ID, '_kilifi_rider_online', true) === 'yes',
        'vehicle_type'  => get_user_meta($user->ID, '_kilifi_rider_vehicle_type', true),
        'vehicle_plate' => get_user_meta($user->ID, '_kilifi_rider_vehicle_plate', true),
        'rating'           => floatval(get_user_meta($user->ID, '_kilifi_rider_rating', true) ?: 0),
        'total_deliveries' => intval(get_user_meta($user->ID, '_kilifi_rider_total_deliveries', true) ?: 0),
        'registration_status' => get_user_meta($user->ID, '_rider_registration_status', true) ?: 'pending',
    ]);
}

/**
 * Rider go live
 */
function kilifihub_rest_rider_go_live(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);

    update_user_meta($rider_id, '_kilifi_rider_online', 'yes');
    update_user_meta($rider_id, '_kilifi_rider_went_online_at', current_time('mysql'));

    return rest_ensure_response([
        'success'   => true,
        'message'   => 'Rider is now online',
        'is_online' => true,
    ]);
}

/**
 * Rider go offline
 */
function kilifihub_rest_rider_go_offline(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);

    update_user_meta($rider_id, '_kilifi_rider_online', 'no');

    return rest_ensure_response([
        'success'   => true,
        'message'   => 'Rider is now offline',
        'is_online' => false,
    ]);
}

/**
 * Update rider GPS location
 */
function kilifihub_rest_rider_update_location(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);

    $latitude  = floatval($request->get_param('latitude'));
    $longitude = floatval($request->get_param('longitude'));
    $accuracy  = $request->get_param('accuracy');
    $speed     = $request->get_param('speed');

    if (!$latitude || !$longitude) {
        return new WP_Error('invalid_data', 'Latitude and longitude required', ['status' => 400]);
    }

    update_user_meta($rider_id, '_kilifi_rider_latitude', $latitude);
    update_user_meta($rider_id, '_kilifi_rider_longitude', $longitude);
    update_user_meta($rider_id, '_kilifi_rider_location_accuracy', $accuracy);
    update_user_meta($rider_id, '_kilifi_rider_location_speed', $speed);
    update_user_meta($rider_id, '_kilifi_rider_location_updated', current_time('mysql'));

    return rest_ensure_response([
        'success' => true,
        'message' => 'Location updated',
    ]);
}

/**
 * Register FCM device token for push notifications
 */
function kilifihub_rest_register_device_token(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);

    $device_token = sanitize_text_field($request->get_param('device_token'));
    $platform     = sanitize_text_field($request->get_param('platform'));

    if (empty($device_token)) {
        return new WP_Error('invalid_data', 'Device token is required', ['status' => 400]);
    }

    update_user_meta($rider_id, '_kilifi_rider_fcm_token', $device_token);
    update_user_meta($rider_id, '_kilifi_rider_fcm_platform', $platform ?: 'android');
    update_user_meta($rider_id, '_kilifi_rider_fcm_registered_at', current_time('mysql'));

    return rest_ensure_response([
        'success' => true,
        'message' => 'Device token registered successfully',
    ]);
}

/**
 * Get rider's orders
 */
function kilifihub_rest_rider_orders(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);
    $status   = $request->get_param('status');

    $args = [
        'limit'  => 50,
        'return' => 'objects',
    ];

    if ($status === 'active') {
        $args['status'] = ['courier-assignment', 'courier-assigned', 'rider-accepted', 'rider-picked-up', 'rider-on-the-way'];
        $args['meta_key']   = '_kilifi_rider_id';
        $args['meta_value'] = $rider_id;
    } else {
        $args['meta_key']   = '_kilifi_rider_id';
        $args['meta_value'] = $rider_id;
        if ($status) {
            $args['status'] = $status;
        }
    }

    $orders = wc_get_orders($args);
    $result = [];

    foreach ($orders as $order) {
        $result[] = kilifihub_format_order_for_app($order);
    }

    return rest_ensure_response($result);
}

/**
 * Get single order detail
 */
function kilifihub_rest_rider_order_detail(WP_REST_Request $request) {
    $order_id = intval($request['order_id']);
    $order = wc_get_order($order_id);

    if (!$order) {
        return new WP_Error('not_found', 'Order not found', ['status' => 404]);
    }

    return rest_ensure_response(kilifihub_format_order_for_app($order, true));
}

/**
 * Accept an order
 */
function kilifihub_rest_accept_order(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);
    $order_id = intval($request['order_id']);
    $order    = wc_get_order($order_id);

    if (!$order) {
        return new WP_Error('not_found', 'Order not found', ['status' => 404]);
    }

    $current_status = $order->get_status();
    if (!in_array($current_status, ['courier-assignment', 'courier-assigned'])) {
        return new WP_Error('invalid_status', 'Order cannot be accepted in current status', ['status' => 400]);
    }

    $order->update_status('rider-accepted', 'Rider accepted order via mobile app');
    update_post_meta($order_id, '_kilifi_rider_id', $rider_id);
    update_post_meta($order_id, '_kilifi_dispatch_status', 'accepted');
    update_post_meta($order_id, '_kilifi_rider_accepted_at', current_time('mysql'));

    $active_orders = get_user_meta($rider_id, '_kilifi_rider_active_orders', true) ?: [];
    if (!in_array($order_id, $active_orders)) {
        $active_orders[] = $order_id;
        update_user_meta($rider_id, '_kilifi_rider_active_orders', $active_orders);
    }

    return rest_ensure_response([
        'success' => true,
        'message' => 'Order accepted successfully',
    ]);
}

/**
 * Mark order as picked up
 */
function kilifihub_rest_pickup_order(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);
    $order_id = intval($request['order_id']);
    $order    = wc_get_order($order_id);

    if (!$order) {
        return new WP_Error('not_found', 'Order not found', ['status' => 404]);
    }

    $order->update_status('rider-picked-up', 'Rider picked up order via mobile app');
    update_post_meta($order_id, '_kilifi_rider_picked_up_at', current_time('mysql'));

    return rest_ensure_response([
        'success' => true,
        'message' => 'Order marked as picked up',
    ]);
}

/**
 * Complete delivery
 */
function kilifihub_rest_complete_delivery(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);
    $order_id = intval($request['order_id']);
    $order    = wc_get_order($order_id);

    if (!$order) {
        return new WP_Error('not_found', 'Order not found', ['status' => 404]);
    }

    $order->update_status('completed', 'Delivery completed via mobile app');
    update_post_meta($order_id, '_kilifi_rider_delivered_at', current_time('mysql'));

    $active_orders = get_user_meta($rider_id, '_kilifi_rider_active_orders', true) ?: [];
    $active_orders = array_diff($active_orders, [$order_id]);
    update_user_meta($rider_id, '_kilifi_rider_active_orders', $active_orders);

    $total = intval(get_user_meta($rider_id, '_kilifi_rider_total_deliveries', true) ?: 0);
    update_user_meta($rider_id, '_kilifi_rider_total_deliveries', $total + 1);

    $delivery_fee = floatval(get_post_meta($order_id, '_kilifi_delivery_fee', true) ?: 0);
    if ($delivery_fee > 0) {
        $earnings = floatval(get_user_meta($rider_id, '_kilifi_rider_earnings', true) ?: 0);
        update_user_meta($rider_id, '_kilifi_rider_earnings', $earnings + $delivery_fee);
    }

    return rest_ensure_response([
        'success' => true,
        'message' => 'Delivery completed successfully',
    ]);
}

/**
 * Decline an order
 */
function kilifihub_rest_decline_order(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);
    $order_id = intval($request['order_id']);
    $order    = wc_get_order($order_id);

    if (!$order) {
        return new WP_Error('not_found', 'Order not found', ['status' => 404]);
    }

    $order->update_status('courier-assignment', 'Rider declined order via mobile app - re-dispatching');
    delete_post_meta($order_id, '_kilifi_rider_id');
    update_post_meta($order_id, '_kilifi_dispatch_status', 'declined');
    update_post_meta($order_id, '_kilifi_rider_declined_at', current_time('mysql'));

    $active_orders = get_user_meta($rider_id, '_kilifi_rider_active_orders', true) ?: [];
    $active_orders = array_diff($active_orders, [$order_id]);
    update_user_meta($rider_id, '_kilifi_rider_active_orders', $active_orders);

    do_action('kilifihub_order_needs_dispatch', $order_id);

    return rest_ensure_response([
        'success' => true,
        'message' => 'Order declined. It will be reassigned.',
    ]);
}

/**
 * Get rider earnings
 */
function kilifihub_rest_rider_earnings(WP_REST_Request $request) {
    $rider_id = kilifihub_get_rider_id($request);

    $today = current_time('Y-m-d');
    $week_start = date('Y-m-d', strtotime('monday this week'));
    $month_start = date('Y-m-01');

    $today_earnings = kilifihub_calculate_rider_earnings($rider_id, $today);
    $week_earnings  = kilifihub_calculate_rider_earnings($rider_id, $week_start);
    $month_earnings = kilifihub_calculate_rider_earnings($rider_id, $month_start);

    return rest_ensure_response([
        'success'          => true,
        'today_earnings'   => $today_earnings['total'],
        'today_deliveries' => $today_earnings['count'],
        'week_earnings'    => $week_earnings['total'],
        'week_deliveries'  => $week_earnings['count'],
        'month_earnings'   => $month_earnings['total'],
        'month_deliveries' => $month_earnings['count'],
    ]);
}

/**
 * Send OTP
 */
function kilifihub_rest_send_otp(WP_REST_Request $request) {
    $phone = sanitize_text_field($request->get_param('phone'));

    if (empty($phone)) {
        return new WP_Error('invalid_data', 'Phone number is required', ['status' => 400]);
    }

    $users = get_users([
        'meta_key'     => 'billing_phone',
        'meta_value'   => $phone,
        'role'         => 'kilifi_rider',
        'number'       => 1,
    ]);

    if (empty($users)) {
        return new WP_Error('not_found', 'No rider account found with this phone number', ['status' => 404]);
    }

    $user = $users[0];

    $otp = (string) random_int(1000, 9999);
    update_user_meta($user->ID, '_kilifi_rider_otp', wp_hash($otp));
    update_user_meta($user->ID, '_kilifi_rider_otp_expires', time() + 300);

    do_action('kilifihub_send_otp_sms', $phone, $otp);

    return rest_ensure_response([
        'success' => true,
        'message' => 'Verification code sent',
    ]);
}

/**
 * Verify OTP and return JWT token
 */
function kilifihub_rest_verify_otp(WP_REST_Request $request) {
    $phone = sanitize_text_field($request->get_param('phone'));
    $otp   = sanitize_text_field($request->get_param('otp'));

    if (empty($phone) || empty($otp)) {
        return new WP_Error('invalid_data', 'Phone number and OTP are required', ['status' => 400]);
    }

    $users = get_users([
        'meta_key'     => 'billing_phone',
        'meta_value'   => $phone,
        'role'         => 'kilifi_rider',
        'number'       => 1,
    ]);

    if (empty($users)) {
        return new WP_Error('not_found', 'No rider account found', ['status' => 404]);
    }

    $user = $users[0];

    $stored_hash = get_user_meta($user->ID, '_kilifi_rider_otp', true);
    $expires_at  = intval(get_user_meta($user->ID, '_kilifi_rider_otp_expires', true));

    if (empty($stored_hash) || time() > $expires_at) {
        return new WP_Error('otp_expired', 'Verification code has expired', ['status' => 400]);
    }

    if (!wp_check_password($otp, $stored_hash)) {
        return new WP_Error('invalid_otp', 'Invalid verification code', ['status' => 400]);
    }

    delete_user_meta($user->ID, '_kilifi_rider_otp');
    delete_user_meta($user->ID, '_kilifi_rider_otp_expires');

    $token = kilifihub_generate_jwt_token($user);

    $rider_data = [
        'id'                  => $user->ID,
        'name'                => $user->display_name,
        'phone'               => get_user_meta($user->ID, 'billing_phone', true),
        'email'               => $user->user_email,
        'avatar_url'          => get_avatar_url($user->ID, ['size' => 256]),
        'is_online'           => get_user_meta($user->ID, '_kilifi_rider_online', true) === 'yes',
        'vehicle_type'        => get_user_meta($user->ID, '_kilifi_rider_vehicle_type', true),
        'vehicle_plate'       => get_user_meta($user->ID, '_kilifi_rider_vehicle_plate', true),
        'rating'              => floatval(get_user_meta($user->ID, '_kilifi_rider_rating', true) ?: 0),
        'total_deliveries'    => intval(get_user_meta($user->ID, '_kilifi_rider_total_deliveries', true) ?: 0),
        'registration_status' => get_user_meta($user->ID, '_rider_registration_status', true) ?: 'pending',
    ];

    return rest_ensure_response([
        'success'       => true,
        'message'       => 'Login successful',
        'token'         => $token,
        'refresh_token' => kilifihub_generate_refresh_token($user),
        'rider'         => $rider_data,
    ]);
}

// ============================================================
// 4. PUSH NOTIFICATION FUNCTIONS (Firebase v1 API)
// ============================================================

/**
 * Get OAuth2 access token using Firebase service account credentials
 *
 * Uses the private key JSON file to generate a JWT, exchange it for
 * an access token, and caches it for 50 minutes.
 */
function kilifihub_get_fcm_access_token() {
    // Check cached token first
    $cached = get_transient(KILIFIHUB_FCM_TOKEN_CACHE_KEY);
    if ($cached && isset($cached['token']) && $cached['expires'] > time()) {
        return $cached['token'];
    }

    // Load service account credentials
    $credentials_path = KILIFIHUB_FIREBASE_CREDENTIALS_PATH;

    if (!file_exists($credentials_path)) {
        error_log('KilifiHub Push: Firebase credentials file not found at ' . $credentials_path);
        return false;
    }

    $credentials = json_decode(file_get_contents($credentials_path), true);

    if (!$credentials || !isset($credentials['private_key']) || !isset($credentials['client_email'])) {
        error_log('KilifiHub Push: Invalid Firebase credentials file');
        return false;
    }

    // Create JWT for Google OAuth2
    $now = time();
    $jwt_header = base64_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $jwt_claim = base64_encode(json_encode([
        'iss'   => $credentials['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => KILIFIHUB_GOOGLE_TOKEN_ENDPOINT,
        'iat'   => $now,
        'exp'   => $now + 3600,
    ]));

    // Sign the JWT with the private key
    $signature_input = $jwt_header . '.' . $jwt_claim;
    openssl_sign($signature_input, $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256);
    $jwt = $signature_input . '.' . base64_encode($signature);

    // Exchange JWT for access token
    $response = wp_remote_post(KILIFIHUB_GOOGLE_TOKEN_ENDPOINT, [
        'body' => [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ],
        'timeout' => 10,
    ]);

    if (is_wp_error($response)) {
        error_log('KilifiHub Push: OAuth2 token request failed - ' . $response->get_error_message());
        return false;
    }

    $token_data = json_decode(wp_remote_retrieve_body($response), true);

    if (!isset($token_data['access_token'])) {
        error_log('KilifiHub Push: OAuth2 token response missing access_token - ' . wp_remote_retrieve_body($response));
        return false;
    }

    // Cache for 50 minutes (tokens last 60 min)
    set_transient(KILIFIHUB_FCM_TOKEN_CACHE_KEY, [
        'token'   => $token_data['access_token'],
        'expires' => $now + 3000,
    ], 3000);

    return $token_data['access_token'];
}

/**
 * Send push notification to a specific rider via Firebase Cloud Messaging v1 API
 *
 * @param int    $rider_id  WordPress user ID of the rider
 * @param string $title     Notification title
 * @param string $body      Notification body text
 * @param array  $data      Additional data payload (order_id, action, etc.)
 * @return bool True if sent successfully
 */
function kilifihub_send_push_notification($rider_id, $title, $body, $data = []) {
    $device_token = get_user_meta($rider_id, '_kilifi_rider_fcm_token', true);

    if (empty($device_token)) {
        error_log("KilifiHub Push: No FCM token for rider {$rider_id}");
        return false;
    }

    // Get OAuth2 access token
    $access_token = kilifihub_get_fcm_access_token();
    if (!$access_token) {
        error_log('KilifiHub Push: Could not get access token');
        return false;
    }

    // Build FCM v1 message payload
    $payload = [
        'message' => [
            'token' => $device_token,
            'notification' => [
                'title' => $title,
                'body'  => $body,
            ],
            'data' => array_merge([
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            ], $data),
            'android' => [
                'priority' => 'high',
                'notification' => [
                    'sound'  => 'default',
                    'channel_id' => 'kilifihub_rider_orders',
                ],
            ],
            'apns' => [
                'payload' => [
                    'aps' => [
                        'sound'             => 'default',
                        'content-available' => 1,
                    ],
                ],
            ],
        ],
    ];

    // Send via FCM v1 API
    $response = wp_remote_post(KILIFIHUB_FCM_V1_ENDPOINT, [
        'headers' => [
            'Authorization' => 'Bearer ' . $access_token,
            'Content-Type'  => 'application/json',
        ],
        'body'    => wp_json_encode($payload),
        'timeout' => 10,
    ]);

    if (is_wp_error($response)) {
        error_log('KilifiHub Push: Failed to send - ' . $response->get_error_message());
        return false;
    }

    $status_code = wp_remote_retrieve_response_code($response);
    $response_body = json_decode(wp_remote_retrieve_body($response), true);

    // Success = HTTP 200
    if ($status_code === 200 && isset($response_body['name'])) {
        return true;
    }

    // Handle errors
    if (isset($response_body['error'])) {
        $error_code = $response_body['error']['code'] ?? 0;
        $error_message = $response_body['error']['message'] ?? 'Unknown error';

        // Token not registered or invalid - remove it
        if ($error_code === 404 || strpos($error_message, 'UNREGISTERED') !== false || strpos($error_message, 'InvalidRegistration') !== false) {
            delete_user_meta($rider_id, '_kilifi_rider_fcm_token');
            error_log("KilifiHub Push: Invalid token removed for rider {$rider_id}");
        }

        error_log("KilifiHub Push: Error {$error_code} - {$error_message}");
    }

    return false;
}

/**
 * Push notification when order assigned to rider
 */
add_action('kilifihub_order_assigned_to_rider', function ($order_id, $rider_id) {
    $order = wc_get_order($order_id);
    if (!$order) return;

    $vendor_name = kilifihub_get_order_vendor_name($order);
    $customer_address = $order->get_billing_address_1() ?: 'Customer location';

    kilifihub_send_push_notification(
        $rider_id,
        'New Delivery Order!',
        "Order #{$order_id} from {$vendor_name} - Pick up and deliver to {$customer_address}",
        [
            'order_id' => $order_id,
            'action'   => 'new_order',
            'vendor'   => $vendor_name,
        ]
    );
}, 10, 2);

/**
 * Push notification when order status changes
 */
add_action('woocommerce_order_status_changed', function ($order_id, $old_status, $new_status) {
    $rider_id = get_post_meta($order_id, '_kilifi_rider_id', true);
    if (empty($rider_id)) return;

    $notifications = [
        'cancelled' => [
            'title' => 'Order Cancelled',
            'body'  => "Order #{$order_id} has been cancelled by the customer.",
        ],
        'processing' => [
            'title' => 'Order Ready for Pickup',
            'body'  => "Order #{$order_id} is ready for pickup!",
        ],
    ];

    if (isset($notifications[$new_status])) {
        kilifihub_send_push_notification(
            $rider_id,
            $notifications[$new_status]['title'],
            $notifications[$new_status]['body'],
            [
                'order_id' => $order_id,
                'action'   => 'status_change',
                'status'   => $new_status,
            ]
        );
    }
}, 10, 3);

// ============================================================
// 5. HELPER FUNCTIONS
// ============================================================

/**
 * Format a WooCommerce order for the rider app
 */
function kilifihub_format_order_for_app($order, $detailed = false) {
    $order_id = $order->get_id();

    $vendor_id = get_post_meta($order_id, '_vendor_id', true) ?: $order->get_meta('_vendor_id');
    $vendor_name = kilifihub_get_order_vendor_name($order);
    $vendor_address = $vendor_id ? get_user_meta($vendor_id, '_vendor_address', true) : '';
    $vendor_lat = $vendor_id ? floatval(get_user_meta($vendor_id, '_vendor_lat', true) ?: 0) : null;
    $vendor_lng = $vendor_id ? floatval(get_user_meta($vendor_id, '_vendor_lng', true) ?: 0) : null;
    $vendor_phone = $vendor_id ? get_user_meta($vendor_id, 'billing_phone', true) : '';

    $customer_name = trim($order->get_billing_first_name() . ' ' . $order->get_billing_last_name());
    $customer_phone = $order->get_billing_phone();
    $customer_address = trim($order->get_billing_address_1() . ', ' . $order->get_billing_city());
    $customer_lat = floatval(get_post_meta($order_id, '_customer_latitude', true) ?: 0) ?: null;
    $customer_lng = floatval(get_post_meta($order_id, '_customer_longitude', true) ?: 0) ?: null;
    $customer_notes = $order->get_customer_note();

    $items = [];
    foreach ($order->get_items() as $item) {
        $items[] = [
            'name'     => $item->get_name(),
            'quantity' => $item->get_quantity(),
            'price'    => floatval($item->get_total()),
        ];
    }

    return [
        'id'                   => $order_id,
        'order_number'         => $order->get_order_number(),
        'status'               => $order->get_status(),
        'date_created'         => $order->get_date_created() ? $order->get_date_created()->format('c') : '',
        'total'                => floatval($order->get_total()),
        'currency'             => $order->get_currency(),
        'payment_method_title' => $order->get_payment_method_title(),
        'vendor'    => [
            'id'        => intval($vendor_id ?: 0),
            'name'      => $vendor_name,
            'address'   => $vendor_address,
            'latitude'  => $vendor_lat ?: null,
            'longitude' => $vendor_lng ?: null,
            'phone'     => $vendor_phone,
        ],
        'customer'  => [
            'name'      => $customer_name,
            'phone'     => $customer_phone,
            'address'   => $customer_address,
            'latitude'  => $customer_lat,
            'longitude' => $customer_lng,
            'notes'     => $customer_notes,
        ],
        'delivery'   => [
            'delivery_fee'   => floatval(get_post_meta($order_id, '_kilifi_delivery_fee', true) ?: 0),
            'distance'       => floatval(get_post_meta($order_id, '_kilifi_delivery_distance', true) ?: 0),
            'estimated_time' => get_post_meta($order_id, '_kilifi_delivery_eta', true) ?: '',
        ],
        'items' => $items,
    ];
}

/**
 * Get vendor/store name from order
 */
function kilifihub_get_order_vendor_name($order) {
    $order_id = $order->get_id();

    $vendor_id = get_post_meta($order_id, '_vendor_id', true) ?: $order->get_meta('_vendor_id');
    if ($vendor_id) {
        $store_name = get_user_meta($vendor_id, 'store_name', true);
        if (!empty($store_name)) {
            return $store_name;
        }
        $vendor = get_user_by('id', $vendor_id);
        if ($vendor) {
            return $vendor->display_name;
        }
    }

    return 'Restaurant';
}

/**
 * Calculate rider earnings for a given period
 */
function kilifihub_calculate_rider_earnings($rider_id, $from_date) {
    global $wpdb;

    $earnings = $wpdb->get_var($wpdb->prepare(
        "SELECT COALESCE(SUM(CAST(pm.meta_value AS DECIMAL(10,2))), 0)
         FROM {$wpdb->posts} p
         INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = '_kilifi_delivery_fee'
         INNER JOIN {$wpdb->postmeta} pm2 ON p.ID = pm2.post_id AND pm2.meta_key = '_kilifi_rider_id' AND pm2.meta_value = %d
         WHERE p.post_type = 'shop_order'
         AND p.post_status IN ('wc-completed', 'wc-rider-picked-up', 'wc-rider-on-the-way')
         AND p.post_date >= %s",
        $rider_id,
        $from_date . ' 00:00:00'
    ));

    $count = $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(*)
         FROM {$wpdb->posts} p
         INNER JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id AND pm.meta_key = '_kilifi_rider_id' AND pm.meta_value = %d
         WHERE p.post_type = 'shop_order'
         AND p.post_status IN ('wc-completed', 'wc-rider-picked-up', 'wc-rider-on-the-way')
         AND p.post_date >= %s",
        $rider_id,
        $from_date . ' 00:00:00'
    ));

    return [
        'total' => floatval($earnings ?: 0),
        'count' => intval($count ?: 0),
    ];
}

/**
 * Generate a JWT token for the user
 */
function kilifihub_generate_jwt_token($user) {
    if (class_exists('Jwt_Auth_Public')) {
        return apply_filters('jwt_auth_generate_token', '', $user);
    }

    $header = base64_encode(wp_json_encode(['typ' => 'JWT', 'alg' => 'HS256']));
    $issued_at = time();
    $expire = $issued_at + (DAY_IN_SECONDS * 7);

    $payload = base64_encode(wp_json_encode([
        'iss'  => get_bloginfo('url'),
        'iat'  => $issued_at,
        'exp'  => $expire,
        'data' => [
            'user' => [
                'id' => $user->ID,
            ],
        ],
    ]));

    $signature = base64_encode(hash_hmac('sha256', "$header.$payload", wp_salt('auth'), true));

    return "$header.$payload.$signature";
}

/**
 * Generate a refresh token
 */
function kilifihub_generate_refresh_token($user) {
    $token = wp_generate_password(32, false);
    update_user_meta($user->ID, '_kilifi_refresh_token', wp_hash($token));
    update_user_meta($user->ID, '_kilifi_refresh_token_expires', time() + (DAY_IN_SECONDS * 30));
    return $token;
}
