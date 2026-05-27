import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// Status badge widget - shows order status with color coding
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: config.color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.color,
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'courier-assignment':
        return _StatusConfig(
          label: 'NEW',
          color: const Color(AppConfig.ACCENT_COLOR),
        );
      case 'courier-assigned':
        return _StatusConfig(
          label: 'ASSIGNED',
          color: const Color(0xFF2196F3),
        );
      case 'rider-accepted':
        return _StatusConfig(
          label: 'ACCEPTED',
          color: const Color(0xFF2196F3),
        );
      case 'rider-picked-up':
        return _StatusConfig(
          label: 'PICKED UP',
          color: const Color(AppConfig.PRIMARY_COLOR),
        );
      case 'rider-on-the-way':
        return _StatusConfig(
          label: 'ON THE WAY',
          color: const Color(AppConfig.PRIMARY_COLOR),
        );
      case 'completed':
        return _StatusConfig(
          label: 'DELIVERED',
          color: const Color(AppConfig.SUCCESS_COLOR),
        );
      case 'cancelled':
        return _StatusConfig(
          label: 'CANCELLED',
          color: const Color(AppConfig.ERROR_COLOR),
        );
      default:
        return _StatusConfig(
          label: status.toUpperCase(),
          color: const Color(AppConfig.TEXT_SECONDARY),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color color;

  _StatusConfig({required this.label, required this.color});
}
