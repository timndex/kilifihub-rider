/// Earnings model for rider income data
class EarningsModel {
  final double todayEarnings;
  final double weekEarnings;
  final double monthEarnings;
  final int todayDeliveries;
  final int weekDeliveries;
  final int monthDeliveries;
  final List<DailyEarning> dailyBreakdown;
  final List<PaymentEntry> recentPayments;

  EarningsModel({
    this.todayEarnings = 0,
    this.weekEarnings = 0,
    this.monthEarnings = 0,
    this.todayDeliveries = 0,
    this.weekDeliveries = 0,
    this.monthDeliveries = 0,
    this.dailyBreakdown = const [],
    this.recentPayments = const [],
  });

  factory EarningsModel.fromJson(Map<String, dynamic> json) {
    return EarningsModel(
      todayEarnings: double.tryParse(json['today_earnings']?.toString() ?? '0') ?? 0,
      weekEarnings: double.tryParse(json['week_earnings']?.toString() ?? '0') ?? 0,
      monthEarnings: double.tryParse(json['month_earnings']?.toString() ?? '0') ?? 0,
      todayDeliveries: json['today_deliveries'] as int? ?? 0,
      weekDeliveries: json['week_deliveries'] as int? ?? 0,
      monthDeliveries: json['month_deliveries'] as int? ?? 0,
      dailyBreakdown: (json['daily_breakdown'] as List<dynamic>?)
              ?.map((e) => DailyEarning.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentPayments: (json['recent_payments'] as List<dynamic>?)
              ?.map((e) => PaymentEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DailyEarning {
  final DateTime date;
  final double earnings;
  final int deliveries;

  DailyEarning({
    required this.date,
    this.earnings = 0,
    this.deliveries = 0,
  });

  factory DailyEarning.fromJson(Map<String, dynamic> json) {
    return DailyEarning(
      date: DateTime.parse(json['date'] as String? ?? DateTime.now().toIso8601String()),
      earnings: double.tryParse(json['earnings']?.toString() ?? '0') ?? 0,
      deliveries: json['deliveries'] as int? ?? 0,
    );
  }
}

class PaymentEntry {
  final int orderId;
  final double amount;
  final DateTime date;
  final String type; // 'delivery_fee', 'tip', 'bonus'
  final String vendorName;

  PaymentEntry({
    required this.orderId,
    this.amount = 0,
    required this.date,
    this.type = 'delivery_fee',
    this.vendorName = '',
  });

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    return PaymentEntry(
      orderId: json['order_id'] as int? ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      date: DateTime.parse(json['date'] as String? ?? DateTime.now().toIso8601String()),
      type: json['type'] as String? ?? 'delivery_fee',
      vendorName: json['vendor_name'] as String? ?? '',
    );
  }
}
