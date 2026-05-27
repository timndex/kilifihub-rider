import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../config/app_config.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

/// Order Detail Screen - shows full order info and action buttons
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiService.instance;
      final data = await api.getOrderDetail(widget.orderId);
      setState(() {
        _order = OrderModel.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load order details';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptOrder() async {
    setState(() => _isActionLoading = true);
    try {
      final api = ApiService.instance;
      await api.acceptOrder(widget.orderId);
      await _fetchOrderDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted! Head to the restaurant.'),
            backgroundColor: Color(AppConfig.SUCCESS_COLOR),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to accept order. It may have been assigned to another rider.');
    }
    setState(() => _isActionLoading = false);
  }

  Future<void> _pickUpOrder() async {
    setState(() => _isActionLoading = true);
    try {
      final api = ApiService.instance;
      await api.pickUpOrder(widget.orderId);
      await _fetchOrderDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order picked up! Head to the customer.'),
            backgroundColor: Color(AppConfig.SUCCESS_COLOR),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update order status.');
    }
    setState(() => _isActionLoading = false);
  }

  Future<void> _completeDelivery() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: const Text(
          'Are you sure you want to mark this order as delivered? '
          'Make sure the customer has received their order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConfig.SUCCESS_COLOR),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final api = ApiService.instance;
      await api.completeDelivery(widget.orderId);
      await _fetchOrderDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery completed! Great job!'),
            backgroundColor: Color(AppConfig.SUCCESS_COLOR),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to complete delivery.');
    }
    setState(() => _isActionLoading = false);
  }

  Future<void> _declineOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Order'),
        content: const Text(
          'Are you sure you want to decline this order? '
          'It will be reassigned to another rider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConfig.ERROR_COLOR),
              foregroundColor: Colors.white,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final api = ApiService.instance;
      await api.declineOrder(widget.orderId);
      if (mounted) {
        Navigator.pop(context); // Go back to orders list
      }
    } catch (e) {
      _showError('Failed to decline order.');
    }
    setState(() => _isActionLoading = false);
  }

  Future<void> _openMap(double? lat, double? lng, String label) async {
    if (lat != null && lng != null) {
      final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$label';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // Fallback: search by address
      final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(AppConfig.ERROR_COLOR),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
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
              : _buildOrderContent(),
      bottomNavigationBar: _order != null ? _buildActionButtons() : null,
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
            onPressed: _fetchOrderDetail,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderContent() {
    final order = _order!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(order),

          const SizedBox(height: 16),

          // Pickup Location (Hotel/Vendor)
          _buildLocationCard(
            icon: Icons.store,
            title: 'Pickup',
            name: order.vendor.name,
            address: order.vendor.address,
            phone: order.vendor.phone,
            lat: order.vendor.latitude,
            lng: order.vendor.longitude,
            color: const Color(AppConfig.ACCENT_COLOR),
          ),

          const SizedBox(height: 8),

          // Dotted line connector
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              children: List.generate(
                3,
                (_) => Container(
                  width: 2,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 2),
                  color: const Color(AppConfig.TEXT_HINT).withOpacity(0.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Delivery Location (Customer)
          _buildLocationCard(
            icon: Icons.location_on,
            title: 'Deliver To',
            name: order.customer.name,
            address: order.customer.address,
            phone: order.customer.phone,
            lat: order.customer.latitude,
            lng: order.customer.longitude,
            color: const Color(AppConfig.PRIMARY_COLOR),
          ),

          const SizedBox(height: 16),

          // Order Items
          _buildOrderItemsCard(order),

          const SizedBox(height: 16),

          // Payment Summary
          _buildPaymentCard(order),

          if (order.customer.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(order),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(OrderModel order) {
    final statusColor = _getStatusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(order.status),
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.statusLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(AppConfig.TEXT_SECONDARY),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String title,
    required String name,
    required String address,
    required String phone,
    required double? lat,
    required double? lng,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(AppConfig.TEXT_HINT),
                    fontWeight: FontWeight.w600,
                    textBaseline: TextBaseline.alphabetic,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
                if (address.isNotEmpty)
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(AppConfig.TEXT_SECONDARY),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            children: [
              // Navigate button
              IconButton(
                onPressed: () => _openMap(lat, lng, name),
                icon: const Icon(Icons.navigation_outlined),
                color: const Color(AppConfig.PRIMARY_COLOR),
                tooltip: 'Navigate',
              ),
              // Call button
              if (phone.isNotEmpty)
                IconButton(
                  onPressed: () => _makePhoneCall(phone),
                  icon: const Icon(Icons.phone_outlined),
                  color: const Color(AppConfig.SUCCESS_COLOR),
                  tooltip: 'Call',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(AppConfig.TEXT_PRIMARY),
            ),
          ),
          const SizedBox(height: 12),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(AppConfig.BACKGROUND_COLOR),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${item.quantity}x',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(AppConfig.TEXT_PRIMARY),
                        ),
                      ),
                    ),
                    Text(
                      'KSh ${(item.price * item.quantity).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(AppConfig.TEXT_PRIMARY),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          _buildPaymentRow('Subtotal', 'KSh ${order.total.toStringAsFixed(0)}'),
          if (order.delivery.deliveryFee > 0)
            _buildPaymentRow(
              'Delivery Fee',
              'KSh ${order.delivery.deliveryFee.toStringAsFixed(0)}',
              highlight: true,
            ),
          const Divider(height: 24),
          _buildPaymentRow(
            'Total',
            'KSh ${order.total.toStringAsFixed(0)}',
            isBold: true,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Spacer(),
              Icon(
                order.paymentMethod.toLowerCase().contains('mpesa')
                    ? Icons.phone_android
                    : Icons.credit_card,
                size: 14,
                color: const Color(AppConfig.TEXT_HINT),
              ),
              const SizedBox(width: 4),
              Text(
                order.paymentMethod,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(AppConfig.TEXT_HINT),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value,
      {bool isBold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: const Color(AppConfig.TEXT_SECONDARY),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: highlight
                ? const Color(AppConfig.SUCCESS_COLOR)
                : const Color(AppConfig.TEXT_PRIMARY),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppConfig.ACCENT_COLOR).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(AppConfig.ACCENT_COLOR).withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.note_outlined,
            color: Color(AppConfig.ACCENT_COLOR),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Notes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConfig.ACCENT_COLOR),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.customer.notes,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildActionButtons() {
    if (_order == null || _isActionLoading) {
      return _isActionLoading
          ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: const Center(
                child: SpinKitThreeBounce(
                  color: Color(AppConfig.PRIMARY_COLOR),
                  size: 20,
                ),
              ),
            )
          : null;
    }

    final order = _order!;

    // Completed orders - no actions
    if (order.status == 'completed' || order.status == 'cancelled') {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary action button
            if (order.canAccept)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _acceptOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConfig.SUCCESS_COLOR),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Accept Order',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (order.canPickUp)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _pickUpOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConfig.PRIMARY_COLOR),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Mark as Picked Up',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (order.canComplete)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _completeDelivery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConfig.SUCCESS_COLOR),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Complete Delivery',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Decline button (only for new orders)
            if (order.canAccept) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: _declineOrder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(AppConfig.ERROR_COLOR),
                    side: const BorderSide(color: Color(AppConfig.ERROR_COLOR)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Decline Order'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'courier-assignment':
        return const Color(AppConfig.ACCENT_COLOR);
      case 'rider-accepted':
        return const Color(0xFF2196F3); // Blue
      case 'rider-picked-up':
      case 'rider-on-the-way':
        return const Color(AppConfig.PRIMARY_COLOR);
      case 'completed':
        return const Color(AppConfig.SUCCESS_COLOR);
      case 'cancelled':
        return const Color(AppConfig.ERROR_COLOR);
      default:
        return const Color(AppConfig.TEXT_SECONDARY);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'courier-assignment':
        return Icons.new_releases;
      case 'rider-accepted':
        return Icons.thumb_up;
      case 'rider-picked-up':
        return Icons.shopping_bag;
      case 'rider-on-the-way':
        return Icons.delivery_dining;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
