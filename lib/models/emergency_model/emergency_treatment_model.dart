import 'dart:convert';

class EmergencyTreatmentApiModel {
  final int srlNo;
  final String patientMrNumber;
  final String? receiptId;
  final String patientName;
  final String patientAge;
  final String patientGender;
  final String phoneNumber;
  final String address;
  final String? admittedSince;
  final String mo;
  final String bed;
  final String pulse;
  final String temp;
  final String bp;
  final String respRate;
  final String spo2;
  final String weight;
  final String height;
  final String complaint;
  final String moNotes;
  final String? outcome;
  final bool dischargePatient;
  final List<String> selectedServices;
  final String? createdAt;
  final String? updatedAt;
  final bool isBilled;
  final double servicesTotal;
  final List<Map<String, dynamic>> investigations;
  final List<Map<String, dynamic>> medicines;

  EmergencyTreatmentApiModel({
    required this.srlNo,
    required this.patientMrNumber,
    this.receiptId,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.phoneNumber,
    required this.address,
    this.admittedSince,
    required this.mo,
    required this.bed,
    required this.pulse,
    required this.temp,
    required this.bp,
    required this.respRate,
    required this.spo2,
    required this.weight,
    required this.height,
    required this.complaint,
    required this.moNotes,
    this.outcome,
    required this.dischargePatient,
    required this.selectedServices,
    this.createdAt,
    this.updatedAt,
    this.isBilled = false,
    this.servicesTotal = 0.0,
    this.investigations = const [],
    this.medicines = const [],
  });

  factory EmergencyTreatmentApiModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedServices = [];
    final rawServices = json['selected_services'];
    if (rawServices != null) {
      if (rawServices is String && rawServices.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawServices);
          if (decoded is List) {
            parsedServices = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          parsedServices = rawServices
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } else if (rawServices is List) {
        parsedServices = rawServices.map((e) => e.toString()).toList();
      }
    }

    List<Map<String, dynamic>> parsedInvs = [];
    final rawInvs = json['investigations'];
    if (rawInvs != null) {
      if (rawInvs is String && rawInvs.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawInvs);
          if (decoded is List) {
            parsedInvs = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      } else if (rawInvs is List) {
        parsedInvs = rawInvs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    List<Map<String, dynamic>> parsedMeds = [];
    final rawMeds = json['medicines'];
    if (rawMeds != null) {
      if (rawMeds is String && rawMeds.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawMeds);
          if (decoded is List) {
            parsedMeds = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      } else if (rawMeds is List) {
        parsedMeds = rawMeds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    return EmergencyTreatmentApiModel(
      srlNo: json['srl_no'] ?? 0,
      patientMrNumber: json['patient_mr_number']?.toString() ?? '',
      receiptId: json['receipt_id']?.toString(),
      patientName: json['patient_name'] ?? '',
      patientAge: json['patient_age']?.toString() ?? '',
      patientGender: json['patient_gender'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      admittedSince: json['admitted_since']?.toString(),
      mo: json['mo'] ?? '',
      bed: json['bed'] ?? '',
      pulse: json['pulse']?.toString() ?? '',
      temp: json['temp']?.toString() ?? '',
      bp: json['bp']?.toString() ?? '',
      respRate: json['resp_rate']?.toString() ?? '',
      spo2: json['spo2']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      height: json['height']?.toString() ?? '',
      complaint: json['complaint'] ?? '',
      moNotes: json['mo_notes'] ?? '',
      outcome: json['outcome']?.toString(),
      dischargePatient: json['discharge_patient'] == true ||
          json['discharge_patient'] == 1,
      selectedServices: parsedServices,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      isBilled: json['is_billed'] == true || json['is_billed'] == 1,
      servicesTotal: double.tryParse(json['services_total']?.toString() ?? '') ?? 0.0,
      investigations: parsedInvs,
      medicines: parsedMeds,
    );
  }

  Map<String, dynamic> toJson() => {
    'patient_mr_number': patientMrNumber,
    'receipt_id': receiptId,
    'patient_name': patientName,
    'patient_age': patientAge,
    'patient_gender': patientGender,
    'phone_number': phoneNumber,
    'address': address,
    'admitted_since': admittedSince,
    'mo': mo,
    'bed': bed,
    'pulse': pulse,
    'temp': temp,
    'bp': bp,
    'resp_rate': respRate,
    'spo2': spo2,
    'weight': weight,
    'height': height,
    'complaint': complaint,
    'mo_notes': moNotes,
    'outcome': outcome,
    'discharge_patient': dischargePatient,
    'selected_services': jsonEncode(selectedServices),
    'is_billed': isBilled,
    'services_total': servicesTotal,
    'investigations': jsonEncode(investigations),
    'medicines': jsonEncode(medicines),
  };
}

class EmergencyQueueItemModel {
  final int srlNo;
  final String patientMrNumber;
  final String patientName;
  final String patientAge;
  final String patientGender;
  final String? admittedSince;

  EmergencyQueueItemModel({
    required this.srlNo,
    required this.patientMrNumber,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    this.admittedSince,
  });

  factory EmergencyQueueItemModel.fromJson(Map<String, dynamic> json) {
    return EmergencyQueueItemModel(
      srlNo: json['srl_no'] ?? 0,
      patientMrNumber: json['patient_mr_number']?.toString() ?? '',
      patientName: json['patient_name'] ?? '',
      patientAge: json['patient_age']?.toString() ?? '',
      patientGender: json['patient_gender'] ?? '',
      admittedSince: json['admitted_since']?.toString(),
    );
  }
}

class ShiftModel {
  final String shiftId;
  final String shiftType;
  final String shiftDate;

  ShiftModel({
    required this.shiftId,
    required this.shiftType,
    required this.shiftDate,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      shiftId: json['shift_id']?.toString() ?? '',
      shiftType: json['shift_type'] ?? '',
      shiftDate: json['shift_date'] ?? '',
    );
  }
}
