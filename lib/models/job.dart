/// Represents a job with all its details.
class Job {
  final int? id;
  final String? title;
  final String? description;
  final String? customerName;
  final int? vehicleId;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? licensePlate;
  final String? status;
  final DateTime? createdAt;
  final String? customerPhone;
  final String? customerEmail;
  final String? vehicleVin;
  final String? vehicleMileage;
  final String? signatureUrl;
  final List<dynamic>? assignedParts;
  final List<dynamic>? notes;
  final int? timeInMinutes;
  final String? jobCode;
  final String? timeFrame;
  final String? bayLocation;
  DateTime? startTime; // Make these fields mutable
  DateTime? endTime; // Make these fields mutable
  final String? custNotes;
  DateTime? pausedAt;

  Job({
    this.id,
    this.title,
    this.description,
    this.customerName,
    this.vehicleId,
    this.vehicleMake,
    this.vehicleModel,
    this.licensePlate,
    this.status,
    this.createdAt,
    this.customerPhone,
    this.customerEmail,
    this.vehicleVin,
    this.vehicleMileage,
    this.signatureUrl,
    this.assignedParts,
    this.notes,
    this.timeInMinutes,
    this.jobCode,
    this.timeFrame,
    this.bayLocation,
    this.startTime,
    this.endTime,
    this.custNotes,
    this.pausedAt,

  });

  factory Job.fromJson(Map<String, dynamic> json) {
    // Safely extract data from joined tables, handling both List and Map types.
    final dynamic customerData = (json['customers'] is List) ? (json['customers'] as List).firstOrNull : json['customers'];
    final dynamic vehicleData = (json['vehicles'] is List) ? (json['vehicles'] as List).firstOrNull : json['vehicles'];

    return Job(
      id: json['job_id'] as int?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      customerName: customerData?['name'] as String?,
      vehicleId: json['vehicle_id'] as int?,
      vehicleMake: vehicleData?['make'] as String?,
      vehicleModel: vehicleData?['model'] as String?,
      licensePlate: vehicleData?['license_plate'] as String?,
      status: json['status'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      customerPhone: customerData?['contact_number'] as String?,
      customerEmail: customerData?['email'] as String?,
      vehicleVin: vehicleData?['vin_number'] as String?,
      vehicleMileage: vehicleData?['mileage'] as String?,
      signatureUrl: json['signature_url'] as String?,
      assignedParts: json['assigned_parts'] as List<dynamic>?,
      notes: json['notes'] as List<dynamic>?,
      timeInMinutes: json['time_in_minutes'] as int?,
      jobCode: json['job_code'] as String?,
      timeFrame: json['time_frame'] as String?,
      bayLocation: json['bay_location'] as String?,
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']).toLocal() : null,
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']).toLocal(): null,
      custNotes: json['cust_notes'] as String?,
      pausedAt: json['paused_at'] != null ? DateTime.parse(json['paused_at']).toLocal() : null,
    );
  }

  Job copyWith({
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    int? timeInMinutes,
    DateTime? pausedAt,
  }) {
    return Job(
      id: id,
      createdAt: createdAt,
      title: title,
      description: description,
      status: status ?? this.status,
      bayLocation: bayLocation,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      timeInMinutes: timeInMinutes ?? this.timeInMinutes,
      licensePlate: licensePlate,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleVin: vehicleVin,
      vehicleMileage: vehicleMileage,
      pausedAt: pausedAt ?? this.pausedAt,
    );
  }
}