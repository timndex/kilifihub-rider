/// App-wide constants and utility values
class Constants {
  // Order statuses
  static const String STATUS_COURIER_ASSIGNMENT = 'courier-assignment';
  static const String STATUS_COURIER_ASSIGNED = 'courier-assigned';
  static const String STATUS_RIDER_ACCEPTED = 'rider-accepted';
  static const String STATUS_RIDER_PICKED_UP = 'rider-picked-up';
  static const String STATUS_RIDER_ON_THE_WAY = 'rider-on-the-way';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';
  static const String STATUS_PROCESSING = 'processing';

  // Active order statuses (rider should see these)
  static const List<String> ACTIVE_STATUSES = [
    STATUS_COURIER_ASSIGNMENT,
    STATUS_COURIER_ASSIGNED,
    STATUS_RIDER_ACCEPTED,
    STATUS_RIDER_PICKED_UP,
    STATUS_RIDER_ON_THE_WAY,
  ];

  // Registration statuses
  static const String REG_PENDING = 'pending';
  static const String REG_APPROVED = 'approved';
  static const String REG_REJECTED = 'rejected';

  // Payment methods
  static const String PAYMENT_MPESA = 'mpesa';
  static const String PAYMENT_CARD = 'card';
  static const String PAYMENT_CASH = 'cod';

  // Distance units
  static const double METERS_PER_KM = 1000.0;

  // Time formatting
  static const String DATE_FORMAT = 'dd MMM yyyy';
  static const String TIME_FORMAT = 'hh:mm a';
  static const String DATETIME_FORMAT = 'dd MMM yyyy, hh:mm a';
}
