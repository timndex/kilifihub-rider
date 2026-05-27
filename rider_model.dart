/// Rider model representing the logged-in rider
class RiderModel {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String avatarUrl;
  final bool isOnline;
  final String vehicleType;
  final String vehiclePlate;
  final double rating;
  final int totalDeliveries;
  final String registrationStatus;
  final String deviceToken;

  RiderModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.avatarUrl = '',
    this.isOnline = false,
    this.vehicleType = '',
    this.vehiclePlate = '',
    this.rating = 0,
    this.totalDeliveries = 0,
    this.registrationStatus = 'pending',
    this.deviceToken = '',
  });

  factory RiderModel.fromJson(Map<String, dynamic> json) {
    return RiderModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? json['display_name'] as String? ?? 'Rider',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      vehicleType: json['vehicle_type'] as String? ?? '',
      vehiclePlate: json['vehicle_plate'] as String? ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      totalDeliveries: json['total_deliveries'] as int? ?? 0,
      registrationStatus: json['registration_status'] as String? ?? 'pending',
      deviceToken: json['device_token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'is_online': isOnline,
      'vehicle_type': vehicleType,
      'vehicle_plate': vehiclePlate,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'registration_status': registrationStatus,
      'device_token': deviceToken,
    };
  }

  /// Whether rider can go online (must be approved)
  bool get canGoOnline => registrationStatus == 'approved';

  RiderModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    bool? isOnline,
    String? vehicleType,
    String? vehiclePlate,
    double? rating,
    int? totalDeliveries,
    String? registrationStatus,
    String? deviceToken,
  }) {
    return RiderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      deviceToken: deviceToken ?? this.deviceToken,
    );
  }
}
