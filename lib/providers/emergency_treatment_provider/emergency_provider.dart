import 'package:flutter/material.dart';

import '../../core/services/emergency_treatment_api_service.dart';
import '../../core/services/opd_receipt_api_service.dart';
import '../../core/services/mr_api_service.dart';
import '../../global/global_api.dart';
import '../../models/emergency_model/emergency_treatment_model.dart';
import '../../models/opd_model/opd_receipt_model.dart';

// ── Data Models ──

class EmergencyPatient {
  final String mrNo;
  final String name;
  final String age;
  final String gender;
  final String phone;
  final String address;
  final DateTime admittedSince;
  final String receiptNo;
  final List<String> emergencyServices;

  EmergencyPatient({
    required this.mrNo,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.address,
    required this.admittedSince,
    this.receiptNo = '',
    this.emergencyServices = const [],
  });
}

class EmergencyService {
  final String id;
  final String name;
  final double price;
  final IconData icon;
  final Color color;
  final String? imageUrl;

  const EmergencyService({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
    this.imageUrl,
  });
}

class EmergencyInvestigation {
  final String type;
  final String name;
  EmergencyInvestigation({required this.type, required this.name});

  factory EmergencyInvestigation.fromJson(Map<String, dynamic> json) {
    return EmergencyInvestigation(
      type: json['type'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
  };
}

class EmergencyMedicine {
  final String name;
  final String dose;
  final String route;
  const EmergencyMedicine({required this.name, required this.dose, required this.route});
}

class EmergencyPrescription {
  final String name;
  String plan;
  String days;
  EmergencyPrescription({
    required this.name,
    this.plan = '1+1+1',
    this.days = '3',
  });

  factory EmergencyPrescription.fromJson(Map<String, dynamic> json) {
    return EmergencyPrescription(
      name: json['name'] ?? '',
      plan: json['plan'] ?? '1+1+1',
      days: json['days']?.toString() ?? '3',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'plan': plan,
    'days': days,
  };
}

// ── Provider ──

class EmergencyProvider extends ChangeNotifier {
  // ── Static MR formatter ──
  static String formatMr(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return int.parse(digits).toString().padLeft(5, '0');
  }

  // ── Queue (loaded from API) ──
  final List<EmergencyPatient> _queue = [];

  List<EmergencyPatient> get queue => List.unmodifiable(_queue);
  int get queueCount => _queue.length;

  bool _loadingQueue = false;
  bool get isLoadingQueue => _loadingQueue;

  final EmergencyTreatmentApiService _emergencyApi =
      EmergencyTreatmentApiService();

  /// Load the emergency queue from the API.
  Future<void> loadQueue() async {
    // Ensure we are not notifying during a build phase
    await Future.value();
    _loadingQueue = true;
    notifyListeners();
    final result = await _emergencyApi.fetchEmergencyQueue();
    if (result.success) {
      _queue
        ..clear()
        ..addAll(result.queue.map((item) => EmergencyPatient(
              mrNo: item.patientMrNumber,
              name: item.patientName,
              age: item.patientAge,
              gender: item.patientGender,
              phone: '',
              address: '',
              admittedSince: item.admittedSince != null
                  ? DateTime.tryParse(item.admittedSince!) ?? DateTime.now()
                  : DateTime.now(),
              emergencyServices: [],
            )));
    }
    _loadingQueue = false;
    notifyListeners();
  }

  // ── Emergency Services (loaded from API) ──
  final List<EmergencyService> _emergencyServices = [];
  List<EmergencyService> get emergencyServices => List.unmodifiable(_emergencyServices);

  bool _loadingServices = false;
  bool get isLoadingServices => _loadingServices;

  final OpdReceiptApiService _opdApi = OpdReceiptApiService();
  final MrApiService _mrApi = MrApiService();

  Future<MrPatientResult> fetchPatientInfoByMR(String mr) async {
    return await _mrApi.fetchPatientByMR(mr);
  }

  Future<OpdReceiptApiModel?> fetchLatestEmergencyReceipt(String mr) async {
    final res = await _opdApi.fetchOpdReceipts(mrNumber: mr, emergencyPaid: true);
    if (res.success && res.receipts.isNotEmpty) {
      return res.receipts.first;
    }
    return null;
  }

  Future<void> loadEmergencyServices() async {
    _loadingServices = true;
    notifyListeners();
    final result = await _opdApi.fetchOpdServices();
    if (result.success) {
      _emergencyServices.clear();
      for (final s in result.services) {
        if (s.isActive == 1 && s.allowEmergencyService != 0) {
          final rate = double.tryParse(s.serviceRate) ?? 0.0;
          
          // Map head to color/icon
          Color color = const Color(0xFFE53935);
          IconData icon = Icons.medical_services_rounded;
          
          switch (s.serviceHead.toLowerCase()) {
            case 'emergency': color = const Color(0xFFE53935); icon = Icons.emergency_rounded; break;
            case 'opd':       color = const Color(0xFF1E88E5); icon = Icons.local_hospital_rounded; break;
          }

          final imageUrl = GlobalApi.getImageUrl(s.imageUrl);

          _emergencyServices.add(EmergencyService(
            id: s.serviceId,
            name: s.serviceName,
            price: rate,
            icon: icon,
            color: color,
            imageUrl: imageUrl,
          ));
        }
      }
    }
    _loadingServices = false;
    notifyListeners();
  }

  /// Kept for backward compatibility with OPD receipt bridge (no-op now — queue comes from API).
  void addPatientFromOpd(Map<String, dynamic> data) {
    final mrNo = data['mrNo'] as String;
    // Don't add if already in queue
    if (_queue.any((p) => p.mrNo == mrNo)) return;

    _queue.add(EmergencyPatient(
      mrNo: mrNo,
      name: data['name'] ?? '',
      age: data['age'] ?? '',
      gender: data['gender'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      admittedSince: data['admittedSince'] ?? DateTime.now(),
      receiptNo: data['receiptNo'] ?? '',
      emergencyServices: List<String>.from(data['emergencyServices'] ?? []),
    ));
    notifyListeners();
  }

  EmergencyPatient? lookupPatient(String mrNo) {
    try {
      return _queue.firstWhere((p) => p.mrNo == mrNo);
    } catch (_) {
      return null;
    }
  }

  void refresh() => notifyListeners();

  // ── Existing treatment record (loaded per-MR) ──
  EmergencyTreatmentApiModel? currentRecord;

  /// Fetch existing treatment for a given MR from the API.
  Future<EmergencyTreatmentApiModel?> fetchExistingTreatment(
      String mrNo) async {
    final result = await _emergencyApi.fetchByMR(mrNo);
    if (result.success) {
      currentRecord = result.record;
      return result.record;
    }
    return null;
  }

  /// Create a new treatment record.
  Future<EmergencyTreatmentResult> saveToApi(
      Map<String, dynamic> payload) async {
    return _emergencyApi.createTreatment(payload);
  }

  /// Update an existing treatment record.
  Future<EmergencyTreatmentResult> updateToApi(
      int id, Map<String, dynamic> payload) async {
    return _emergencyApi.updateTreatment(id, payload);
  }

  /// Create an emergency bill.
  Future<EmergencyBillingResult> createBill(
      Map<String, dynamic> payload) async {
    return _emergencyApi.createBill(payload);
  }

  /// Fetch current shift.
  Future<ShiftResult> fetchCurrentShift() async {
    return _emergencyApi.fetchCurrentShift();
  }


  // ── Selected emergency services ──
  final List<EmergencyService> _selectedServices = [];
  List<EmergencyService> get selectedServices => List.unmodifiable(_selectedServices);

  bool isServiceSelected(String id) => _selectedServices.any((s) => s.id == id);

  void toggleService(EmergencyService svc) {
    if (isServiceSelected(svc.id)) {
      _selectedServices.removeWhere((s) => s.id == svc.id);
    } else {
      _selectedServices.add(svc);
    }
    notifyListeners();
  }

  void removeSelectedService(String id) {
    _selectedServices.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  double get servicesTotalPrice =>
      _selectedServices.fold(0.0, (sum, s) => sum + s.price);

  // ── Dynamic Investigations & Medicines lists loaded from API ──
  List<Map<String, dynamic>> _radiologyTests = [];
  List<Map<String, dynamic>> get radiologyTests => _radiologyTests;

  List<Map<String, dynamic>> _labTests = [];
  List<Map<String, dynamic>> get labTests => _labTests;

  List<Map<String, dynamic>> _medicinesList = [];
  List<Map<String, dynamic>> get medicinesList => _medicinesList;

  bool _loadingTestsAndMeds = false;
  bool get isLoadingTestsAndMeds => _loadingTestsAndMeds;

  Future<void> loadRadiologyTests() async {
    final res = await _emergencyApi.fetchRadiologyTests();
    _radiologyTests = res;
    notifyListeners();
  }

  Future<void> loadLabTests() async {
    final res = await _emergencyApi.fetchLabTests();
    _labTests = res;
    notifyListeners();
  }

  Future<void> loadMedicines() async {
    final res = await _emergencyApi.fetchMedicines();
    _medicinesList = res;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchBilledServices({
    required String patientName,
    required String from,
    required String to,
  }) async {
    return await _emergencyApi.fetchBilledServices(
      patientName: patientName,
      from: from,
      to: to,
    );
  }

  // ── Selected Investigations ──
  final List<EmergencyInvestigation> _addedInvestigations = [];
  List<EmergencyInvestigation> get addedInvestigations => List.unmodifiable(_addedInvestigations);

  void addInvestigation(String type, String name) {
    if (_addedInvestigations.any((i) => i.name.toLowerCase() == name.toLowerCase())) {
      _addedInvestigations.removeWhere((i) => i.name.toLowerCase() == name.toLowerCase());
    } else {
      _addedInvestigations.add(EmergencyInvestigation(type: type, name: name));
    }
    notifyListeners();
  }

  void removeInvestigation(String name) {
    _addedInvestigations.removeWhere((i) => i.name.toLowerCase() == name.toLowerCase());
    notifyListeners();
  }

  void setAddedInvestigations(List<Map<String, dynamic>> list) {
    _addedInvestigations.clear();
    for (final item in list) {
      _addedInvestigations.add(EmergencyInvestigation(
        type: item['type'] ?? '',
        name: item['name'] ?? '',
      ));
    }
    notifyListeners();
  }

  // ── Selected Medicines ──
  final List<EmergencyPrescription> _prescribedMedicines = [];
  List<EmergencyPrescription> get prescribedMedicines => List.unmodifiable(_prescribedMedicines);

  bool isMedicinePrescribed(String name) =>
      _prescribedMedicines.any((p) => p.name.toLowerCase() == name.toLowerCase());

  void toggleMedicine(String name) {
    if (isMedicinePrescribed(name)) {
      _prescribedMedicines.removeWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    } else {
      _prescribedMedicines.add(EmergencyPrescription(name: name));
    }
    notifyListeners();
  }

  void removeMedicine(String name) {
    _prescribedMedicines.removeWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    notifyListeners();
  }

  void setPrescribedMedicines(List<Map<String, dynamic>> list) {
    _prescribedMedicines.clear();
    for (final item in list) {
      _prescribedMedicines.add(EmergencyPrescription(
        name: item['name'] ?? '',
        plan: item['plan'] ?? '1+1+1',
        days: item['days']?.toString() ?? '3',
      ));
    }
    notifyListeners();
  }

  // ── Save record (local queue update only — API called from screen) ──
  void saveRecord({
    required String mrNo,
    required String name,
    required String age,
    required String gender,
    required String phone,
    required String address,
    required String mo,
    required String bed,
    required String complaint,
    required String moNotes,
    required String dischargeOpt,
    required List<EmergencyService> services,
    required List<EmergencyInvestigation> investigations,
    required List<EmergencyPrescription> medicines,
  }) {
    // On discharge — remove from queue
    if (dischargeOpt == 'Discharged' ||
        dischargeOpt == 'Expired' ||
        dischargeOpt == 'LAMA') {
      _queue.removeWhere((p) => p.mrNo == mrNo);
    }
    notifyListeners();
  }

  void clearAll() {
    _selectedServices.clear();
    _addedInvestigations.clear();
    _prescribedMedicines.clear();
    currentRecord = null;
    notifyListeners();
  }

  /// Called on screen init — loads queue, services, and dynamic lists from real API.
  Future<void> refreshAll() async {
    _loadingTestsAndMeds = true;
    notifyListeners();
    await Future.wait([
      loadQueue(),
      loadEmergencyServices(),
      loadRadiologyTests(),
      loadLabTests(),
      loadMedicines(),
    ]);
    _loadingTestsAndMeds = false;
    notifyListeners();
  }
}