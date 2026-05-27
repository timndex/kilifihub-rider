/// Order model representing a delivery order
class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final DateTime dateCreated;
  final double total;
  final String currency;
  final String paymentMethod;
  final VendorInfo vendor;
  final CustomerInfo customer;
  final DeliveryInfo delivery;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.dateCreated,
    required this.total,
    this.currency = 'KES',
    this.paymentMethod = '',
    required this.vendor,
    required this.customer,
    required this.delivery,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as int,
      orderNumber: json['order_number'] ?? json['id'].toString(),
      status: json['status'] as String? ?? 'pending',
      dateCreated: DateTime.parse(
        json['date_created'] as String? ?? DateTime.now().toIso8601String(),
      ),
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      currency: json['currency'] as String? ?? 'KES',
      paymentMethod: json['payment_method_title'] as String? ?? '',
      vendor: VendorInfo.fromJson(json['vendor'] as Map<String, dynamic>? ?? {}),
      customer: CustomerInfo.fromJson(json['customer'] as Map<String, dynamic>? ?? {}),
      delivery: DeliveryInfo.fromJson(json['delivery'] as Map<String, dynamic>? ?? {}),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Human-readable status
  String get statusLabel {
    switch (status) {
      case 'courier-assignment':
        return 'Awaiting Acceptance';
      case 'courier-assigned':
        return 'Assigned';
      case 'rider-accepted':
        return 'Accepted';
      case 'rider-picked-up':
        return 'Picked Up';
      case 'rider-on-the-way':
        return 'On The Way';
      case 'completed':
        return 'Delivered';
      case 'processing':
        return 'Processing';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('-', ' ').toUpperCase();
    }
  }

  /// Whether this order can be accepted
  bool get canAccept => status == 'courier-assignment';

  /// Whether this order can be marked as picked up
  bool get canPickUp => status == 'rider-accepted';

  /// Whether this order can be marked as delivered
  bool get canComplete => status == 'rider-picked-up' || status == 'rider-on-the-way';

  /// Whether this order is active (in progress)
  bool get isActive => [
        'courier-assignment',
        'courier-assigned',
        'rider-accepted',
        'rider-picked-up',
        'rider-on-the-way',
      ].contains(status);
}

class VendorInfo {
  final int id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String phone;

  VendorInfo({
    required this.id,
    required this.name,
    this.address = '',
    this.latitude,
    this.longitude,
    this.phone = '',
  });

  factory VendorInfo.fromJson(Map<String, dynamic> json) {
    return VendorInfo(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Vendor',
      address: json['address'] as String? ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      phone: json['phone'] as String? ?? '',
    );
  }
}

class CustomerInfo {
  final String name;
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;
  final String notes;

  CustomerInfo({
    required this.name,
    this.phone = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.notes = '',
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      name: json['name'] as String? ?? 'Customer',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      notes: json['notes'] as String? ?? '',
    );
  }
}

class DeliveryInfo {
  final double deliveryFee;
  final double distance;
  final String estimatedTime;

  DeliveryInfo({
    this.deliveryFee = 0,
    this.distance = 0,
    this.estimatedTime = '',
  });

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) {
    return DeliveryInfo(
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
      distance: double.tryParse(json['distance']?.toString() ?? '0') ?? 0,
      estimatedTime: json['estimated_time'] as String? ?? '',
    );
  }
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.name,
    this.quantity = 1,
    this.price = 0,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String? ?? 'Item',
      quantity: json['quantity'] as int? ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
    );
  }
}
