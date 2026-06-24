// ─── Emergency Dashboard Models ──────────────────────────────────────────────

class EmergencyBedStatsModel {
  final int total;
  final int occupied;
  final int vacant;
  final int critical;
  final int serious;
  final int stable;

  const EmergencyBedStatsModel({
    this.total = 0,
    this.occupied = 0,
    this.vacant = 0,
    this.critical = 0,
    this.serious = 0,
    this.stable = 0,
  });

  factory EmergencyBedStatsModel.fromJson(Map<String, dynamic> json) {
    return EmergencyBedStatsModel(
      total: _parseInt(json['total'] ?? json['total_beds'] ?? json['totalBeds']),
      occupied: _parseInt(json['occupied'] ?? json['occupied_beds'] ?? json['occupiedBeds']),
      vacant: _parseInt(json['vacant'] ?? json['vacant_beds'] ?? json['vacantBeds']),
      critical: _parseInt(json['critical'] ?? json['critical_beds'] ?? json['criticalBeds']),
      serious: _parseInt(json['serious'] ?? json['serious_beds'] ?? json['seriousBeds']),
      stable: _parseInt(json['stable'] ?? json['stable_beds'] ?? json['stableBeds']),
    );
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    final parsedInt = int.tryParse(val.toString().trim());
    if (parsedInt != null) return parsedInt;
    final parsedDouble = double.tryParse(val.toString().trim());
    if (parsedDouble != null) return parsedDouble.toInt();
    return 0;
  }
}

class EmergencyBedTypeModel {
  final String typeName;

  const EmergencyBedTypeModel({required this.typeName});

  factory EmergencyBedTypeModel.fromJson(Map<String, dynamic> json) {
    return EmergencyBedTypeModel(
      typeName: json['type_name']?.toString() ?? 'Emergency',
    );
  }
}

class EmergencyBedModel {
  final int id;
  final String bedNumber;
  final int? allotmentId;
  final String? patientMrNumber;
  final String? patientName;
  final String? patientAge;
  final String? patientGender;
  final String? patientStatus;
  final String? admittedSince;
  final String? mo;
  final String? complaint;
  final double servicesTotal;
  final bool isBilled;
  final int? receiptId;

  const EmergencyBedModel({
    required this.id,
    required this.bedNumber,
    this.allotmentId,
    this.patientMrNumber,
    this.patientName,
    this.patientAge,
    this.patientGender,
    this.patientStatus,
    this.admittedSince,
    this.mo,
    this.complaint,
    this.servicesTotal = 0.0,
    this.isBilled = false,
    this.receiptId,
  });

  bool get isOccupied => allotmentId != null;

  factory EmergencyBedModel.fromJson(Map<String, dynamic> json) {
    return EmergencyBedModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      bedNumber: (json['bed_number'] ?? json['bedNumber'])?.toString() ?? '',
      allotmentId: (json['allotment_id'] ?? json['allotmentId'] ?? json['allotment']) != null
          ? int.tryParse((json['allotment_id'] ?? json['allotmentId'] ?? json['allotment']).toString())
          : null,
      patientMrNumber: (json['patient_mr_number'] ?? json['patientMrNumber'] ?? json['mr_number'] ?? json['patient_mr'])?.toString(),
      patientName: (json['patient_name'] ?? json['patientName'] ?? json['name'])?.toString(),
      patientAge: (json['patient_age'] ?? json['patientAge'] ?? json['age'])?.toString(),
      patientGender: (json['patient_gender'] ?? json['patientGender'] ?? json['gender'])?.toString(),
      patientStatus: (json['patient_status'] ?? json['patientStatus'] ?? json['status'])?.toString(),
      admittedSince: (json['admitted_since'] ?? json['admittedSince'] ?? json['admitted'])?.toString(),
      mo: (json['mo'] ?? json['medical_officer'] ?? json['medicalOfficer'])?.toString(),
      complaint: (json['complaint'] ?? json['chief_complaint'] ?? json['chiefComplaint'])?.toString(),
      servicesTotal:
          double.tryParse((json['services_total'] ?? json['servicesTotal'] ?? json['services_sum'] ?? '').toString()) ?? 0.0,
      isBilled: json['is_billed'] == true || json['is_billed'] == 1 || json['isBilled'] == true || json['isBilled'] == 1,
      receiptId: (json['receipt_id'] ?? json['receiptId']) != null
          ? int.tryParse((json['receipt_id'] ?? json['receiptId']).toString())
          : null,
    );
  }
}

class EmergencyDashboardData {
  final List<EmergencyBedModel> beds;
  final EmergencyBedStatsModel stats;
  final EmergencyBedTypeModel? bedType;

  const EmergencyDashboardData({
    this.beds = const [],
    this.stats = const EmergencyBedStatsModel(),
    this.bedType,
  });

  factory EmergencyDashboardData.fromJson(Map<String, dynamic> json) {
    final bedsList = (json['beds'] as List? ?? [])
        .map((e) => EmergencyBedModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final statsJson = json['stats'];
    final stats = statsJson != null
        ? EmergencyBedStatsModel.fromJson(statsJson as Map<String, dynamic>)
        : const EmergencyBedStatsModel();

    final bedTypeJson = json['bed_type'];
    final bedType = bedTypeJson != null
        ? EmergencyBedTypeModel.fromJson(
            bedTypeJson as Map<String, dynamic>)
        : null;

    return EmergencyDashboardData(
      beds: bedsList,
      stats: stats,
      bedType: bedType,
    );
  }
}

// ─── Service Log Model ────────────────────────────────────────────────────────

class EmergencyServiceLogModel {
  final int? id;
  final String? patientMrNumber;
  final String? patientName;
  final String? serviceHead;
  final String? createdAt;

  const EmergencyServiceLogModel({
    this.id,
    this.patientMrNumber,
    this.patientName,
    this.serviceHead,
    this.createdAt,
  });

  factory EmergencyServiceLogModel.fromJson(Map<String, dynamic> json) {
    return EmergencyServiceLogModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      patientMrNumber: json['patient_mr_number']?.toString(),
      patientName: json['patient_name']?.toString(),
      serviceHead: json['service_head']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

// ─── Active Doctor Call Model ─────────────────────────────────────────────────

class ActiveDoctorCallModel {
  final int id;
  final String? patientMrNumber;
  final String? doctorName;
  final String? calledAt;

  const ActiveDoctorCallModel({
    required this.id,
    this.patientMrNumber,
    this.doctorName,
    this.calledAt,
  });

  factory ActiveDoctorCallModel.fromJson(Map<String, dynamic> json) {
    return ActiveDoctorCallModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      patientMrNumber: json['patient_mr_number']?.toString(),
      doctorName: json['doctor_name']?.toString(),
      calledAt: json['called_at']?.toString(),
    );
  }
}

// ─── Queue Patient Model (for dashboard) ─────────────────────────────────────

class EmergencyQueuePatientModel {
  final String patientMrNumber;
  final String patientName;
  final String patientAge;
  final String patientGender;
  final int? receiptId;
  final String? admittedSince;

  const EmergencyQueuePatientModel({
    required this.patientMrNumber,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    this.receiptId,
    this.admittedSince,
  });

  factory EmergencyQueuePatientModel.fromJson(Map<String, dynamic> json) {
    return EmergencyQueuePatientModel(
      patientMrNumber: json['patient_mr_number']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? '',
      patientAge: json['patient_age']?.toString() ?? '',
      patientGender: json['patient_gender']?.toString() ?? '',
      receiptId: json['receipt_id'] != null
          ? int.tryParse(json['receipt_id'].toString())
          : null,
      admittedSince: json['admitted_since']?.toString(),
    );
  }
}
