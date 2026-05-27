import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/order_model.dart';
import 'status_badge.dart';

/// Order card widget - shows order summary in a list
class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Order number + Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
                StatusBadge(status: order.status),
              ],
            ),

            const SizedBox(height: 12),

            // Vendor name
            Row(
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 16,
                  color: const Color(AppConfig.ACCENT_COLOR),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.vendor.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(AppConfig.TEXT_PRIMARY),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Customer address
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: const Color(AppConfig.PRIMARY_COLOR),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.customer.address.isNotEmpty
                        ? order.customer.address
                        : order.customer.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(AppConfig.TEXT_SECONDARY),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bottom row: Items count + Total + Arrow
            Row(
              children: [
                Text(
                  '${order.items.length} item${order.items.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(AppConfig.TEXT_HINT),
                  ),
                ),
                const Spacer(),
                Text(
                  'KSh ${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(AppConfig.TEXT_PRIMARY),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: Color(AppConfig.TEXT_HINT),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
