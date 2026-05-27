import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_config.dart';
import '../models/earnings_model.dart';
import '../services/api_service.dart';

/// Earnings Screen - shows rider income breakdown
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  EarningsModel? _earnings;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchEarnings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchEarnings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiService.instance;
      final data = await api.getEarnings();
      setState(() {
        _earnings = EarningsModel.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load earnings';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(AppConfig.TEXT_PRIMARY),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(
              child: SpinKitThreeBounce(
                color: Color(AppConfig.PRIMARY_COLOR),
                size: 24,
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Color(AppConfig.ERROR_COLOR)),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Color(AppConfig.TEXT_SECONDARY))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchEarnings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final earnings = _earnings!;

    return RefreshIndicator(
      onRefresh: _fetchEarnings,
      color: const Color(AppConfig.PRIMARY_COLOR),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Earnings Hero Card
            _buildHeroCard(earnings),

            const SizedBox(height: 20),

            // Period tabs
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(AppConfig.TEXT_SECONDARY),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(AppConfig.PRIMARY_COLOR),
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'This Week'),
                  Tab(text: 'This Month'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tab content
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPeriodSummary(
                    earnings: earnings.todayEarnings,
                    deliveries: earnings.todayDeliveries,
                    period: 'today',
                  ),
                  _buildPeriodSummary(
                    earnings: earnings.weekEarnings,
                    deliveries: earnings.weekDeliveries,
                    period: 'this week',
                  ),
                  _buildPeriodSummary(
                    earnings: earnings.monthEarnings,
                    deliveries: earnings.monthDeliveries,
                    period: 'this month',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recent Payments
            const Text(
              'Recent Payments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(AppConfig.TEXT_PRIMARY),
              ),
            ),
            const SizedBox(height: 12),
            ...earnings.recentPayments.take(10).map((payment) => _buildPaymentItem(payment)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(EarningsModel earnings) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(AppConfig.PRIMARY_COLOR), Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(AppConfig.PRIMARY_COLOR).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Earnings',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'KSh ${earnings.todayEarnings.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(
                icon: Icons.delivery_dining,
                label: '${earnings.todayDeliveries} deliveries',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: earnings.todayEarnings > 0
                    ? Icons.trending_up
                    : Icons.trending_flat,
                label: earnings.todayEarnings > 0
                    ? 'KSh ${(earnings.todayEarnings / (earnings.todayDeliveries > 0 ? earnings.todayDeliveries : 1)).toStringAsFixed(0)}/delivery'
                    : 'No deliveries yet',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSummary({
    required double earnings,
    required int deliveries,
    required String period,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Earnings amount
          Text(
            'KSh ${earnings.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(AppConfig.TEXT_PRIMARY),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'earned $period',
            style: const TextStyle(
              fontSize: 14,
              color: Color(AppConfig.TEXT_SECONDARY),
            ),
          ),
          const SizedBox(height: 24),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  label: 'Deliveries',
                  value: '$deliveries',
                  icon: Icons.motorcycle,
                  color: const Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBox(
                  label: 'Avg/Delivery',
                  value: deliveries > 0
                      ? 'KSh ${(earnings / deliveries).toStringAsFixed(0)}'
                      : 'KSh 0',
                  icon: Icons.analytics_outlined,
                  color: const Color(AppConfig.ACCENT_COLOR),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(PaymentEntry payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(AppConfig.SUCCESS_COLOR).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_circle_outline,
              color: Color(AppConfig.SUCCESS_COLOR),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.vendorName.isNotEmpty
                      ? payment.vendorName
                      : 'Order #${payment.orderId}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
                Text(
                  _formatDate(payment.date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(AppConfig.TEXT_HINT),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+KSh ${payment.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(AppConfig.SUCCESS_COLOR),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
