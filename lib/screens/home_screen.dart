import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_config.dart';
import '../models/order_model.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/push_notification_service.dart';
import '../services/api_service.dart';
import '../widgets/order_card.dart';
import 'order_detail_screen.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';

/// Home Screen - Main rider dashboard with Go Live toggle and active orders
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isOnline = false;
  bool _isTogglingOnline = false;
  List<OrderModel> _activeOrders = [];
  bool _isLoadingOrders = false;
  String? _ordersError;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
    _setupPushNotifications();
  }

  Future<void> _loadInitialState() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.rider != null) {
      setState(() => _isOnline = auth.rider!.isOnline);
    }
    _fetchActiveOrders();
  }

  void _setupPushNotifications() {
    final pushService = PushNotificationService.instance;
    pushService.onOrderNotification = (orderId) {
      _navigateToOrderDetail(orderId);
    };
  }

  Future<void> _fetchActiveOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });

    try {
      final api = ApiService.instance;
      final ordersData = await api.getOrders(status: 'active');

      setState(() {
        _activeOrders = ordersData
            .map((data) => OrderModel.fromJson(data))
            .where((order) => order.isActive)
            .toList();
        _isLoadingOrders = false;
      });
    } catch (e) {
      setState(() {
        _ordersError = 'Failed to load orders. Pull to refresh.';
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_isTogglingOnline) return;

    setState(() => _isTogglingOnline = true);

    final api = ApiService.instance;
    final locationService = LocationService.instance;

    try {
      if (!_isOnline) {
        // Going online - check location permission first
        final hasPermission = await locationService.hasLocationPermission();
        if (!hasPermission) {
          final granted = await locationService.requestLocationPermission();
          if (!granted) {
            _showSnackBar('Location permission is required to go online',
                isError: true);
            setState(() => _isTogglingOnline = false);
            return;
          }
        }

        // Start location tracking
        final trackingStarted = await locationService.startTracking();
        if (!trackingStarted) {
          _showSnackBar('Failed to start location tracking', isError: true);
          setState(() => _isTogglingOnline = false);
          return;
        }

        // Tell server rider is online
        await api.goLive();
        setState(() => _isOnline = true);
        _showSnackBar('You are now online! Waiting for orders...');
        _fetchActiveOrders(); // Refresh orders
      } else {
        // Going offline - stop tracking
        await locationService.stopTracking();
        await api.goOffline();
        setState(() => _isOnline = false);
        _showSnackBar('You are now offline');
      }
    } catch (e) {
      _showSnackBar('Failed to update status. Check your connection.',
          isError: true);
    }

    setState(() => _isTogglingOnline = false);
  }

  void _navigateToOrderDetail(int orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(orderId: orderId),
      ),
    ).then((_) => _fetchActiveOrders()); // Refresh on return
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(AppConfig.ERROR_COLOR) : const Color(AppConfig.SUCCESS_COLOR),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.RADIUS_MD),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          const EarningsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchActiveOrders,
        color: const Color(AppConfig.PRIMARY_COLOR),
        child: CustomScrollView(
          slivers: [
            // App Bar with Go Live Toggle
            SliverToBoxAdapter(child: _buildHeader()),

            // Active Orders
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'Active Orders',
                      style: TextStyle(
                        fontSize: AppConfig.FONT_SIZE_LARGE,
                        fontWeight: FontWeight.bold,
                        color: const Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_activeOrders.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(AppConfig.PRIMARY_COLOR),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_activeOrders.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Orders List or Empty State
            _isLoadingOrders
                ? const SliverFillRemaining(
                    child: Center(
                      child: SpinKitThreeBounce(
                        color: Color(AppConfig.PRIMARY_COLOR),
                        size: 24,
                      ),
                    ),
                  )
                : _ordersError != null
                    ? SliverFillRemaining(
                        child: _buildErrorState(),
                      )
                    : _activeOrders.isEmpty
                        ? SliverFillRemaining(
                            child: _buildEmptyState(),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.all(20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final order = _activeOrders[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: OrderCard(
                                      order: order,
                                      onTap: () =>
                                          _navigateToOrderDetail(order.id),
                                    ),
                                  );
                                },
                                childCount: _activeOrders.length,
                              ),
                            ),
                          ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: _isOnline
            ? const Color(AppConfig.SUCCESS_COLOR).withOpacity(0.08)
            : const Color(AppConfig.BACKGROUND_COLOR),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Top row: greeting + avatar
          Row(
            children: [
              Expanded(
                child: Consumer<AuthService>(
                  builder: (context, auth, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? 'You\'re Online' : 'You\'re Offline',
                          style: TextStyle(
                            fontSize: AppConfig.FONT_SIZE_SMALL,
                            color: _isOnline
                                ? const Color(AppConfig.SUCCESS_COLOR)
                                : const Color(AppConfig.TEXT_SECONDARY),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hi, ${auth.rider?.name.split(' ').first ?? 'Rider'}!',
                          style: const TextStyle(
                            fontSize: AppConfig.FONT_SIZE_XLARGE,
                            fontWeight: FontWeight.bold,
                            color: Color(AppConfig.TEXT_PRIMARY),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(AppConfig.PRIMARY_COLOR).withOpacity(0.15),
                child: const Icon(
                  Icons.person,
                  color: Color(AppConfig.PRIMARY_COLOR),
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Go Live / Go Offline Toggle
          GestureDetector(
            onTap: _toggleOnlineStatus,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 56,
              decoration: BoxDecoration(
                color: _isOnline
                    ? const Color(AppConfig.SUCCESS_COLOR)
                    : const Color(AppConfig.PRIMARY_COLOR),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (_isOnline
                            ? const Color(AppConfig.SUCCESS_COLOR)
                            : const Color(AppConfig.PRIMARY_COLOR))
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isTogglingOnline
                    ? const SpinKitThreeBounce(color: Colors.white, size: 18)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isOnline ? Icons.power_settings_new : Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOnline ? 'Go Offline' : 'Go Live',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          if (_isOnline) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(AppConfig.SUCCESS_COLOR),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Tracking active · Waiting for orders',
                  style: TextStyle(
                    fontSize: AppConfig.FONT_SIZE_SMALL,
                    color: const Color(AppConfig.SUCCESS_COLOR).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOnline ? Icons.inbox_outlined : Icons.power_off_outlined,
              size: 72,
              color: const Color(AppConfig.TEXT_HINT),
            ),
            const SizedBox(height: 16),
            Text(
              _isOnline ? 'No Active Orders' : 'Go Live to Receive Orders',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_LARGE,
                fontWeight: FontWeight.w600,
                color: const Color(AppConfig.TEXT_SECONDARY),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isOnline
                  ? 'New orders will appear here when hotels assign them to you. Stay online!'
                  : 'Tap the "Go Live" button above to start receiving delivery orders.',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_MEDIUM,
                color: const Color(AppConfig.TEXT_HINT),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: Color(AppConfig.ERROR_COLOR),
            ),
            const SizedBox(height: 16),
            Text(
              _ordersError ?? 'Something went wrong',
              style: TextStyle(
                fontSize: AppConfig.FONT_SIZE_MEDIUM,
                color: const Color(AppConfig.TEXT_SECONDARY),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchActiveOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(AppConfig.PRIMARY_COLOR).withOpacity(0.1),
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
