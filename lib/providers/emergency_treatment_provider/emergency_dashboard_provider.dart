import 'package:flutter/material.dart';
import '../../core/services/emergency_dashboard_api_service.dart';
import '../../models/emergency_model/emergency_dashboard_model.dart';

class EmergencyDashboardProvider extends ChangeNotifier {
  final EmergencyDashboardApiService _api = EmergencyDashboardApiService();

  // ── State ─────────────────────────────────────────────────────────────────
  List<EmergencyQueuePatientModel> _queue = [];
  EmergencyDashboardData? _data;
  List<EmergencyServiceLogModel> _serviceLogs = [];
  List<ActiveDoctorCallModel> _activeDoctorCalls = [];

  bool _isLoading = false;
  bool _logsLoading = false;
  bool _allotting = false;
  String _filterMr = '';
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<EmergencyQueuePatientModel> get queue => _queue;
  EmergencyDashboardData?          get data  => _data;
  List<EmergencyServiceLogModel>   get serviceLogs => _serviceLogs;
  List<ActiveDoctorCallModel>      get activeDoctorCalls => _activeDoctorCalls;

  bool    get isLoading   => _isLoading;
  bool    get logsLoading => _logsLoading;
  bool    get allotting   => _allotting;
  String  get filterMr    => _filterMr;
  String? get error       => _error;

  /// MR numbers already on a bed
  Set<String> get allottedMrs => _data?.beds
      .where((b) => b.allotmentId != null && b.patientMrNumber != null)
      .map((b) => b.patientMrNumber!)
      .toSet() ?? {};

  /// Queue patients NOT yet on any bed
  List<EmergencyQueuePatientModel> get unallottedPatients {
    final allotted = allottedMrs;
    return _queue.where((p) => !allotted.contains(p.patientMrNumber)).toList();
  }

  /// Active doctor call map by MR
  Map<String, ActiveDoctorCallModel> get activeCallByMr {
    final map = <String, ActiveDoctorCallModel>{};
    for (final c in _activeDoctorCalls) {
      if (c.patientMrNumber != null) map[c.patientMrNumber!] = c;
    }
    return map;
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadQueue() async {
    try {
      final r = await _api.fetchEmergencyQueue();
      if (r.success && r.data != null) _queue = r.data!;
    } catch (_) {}
  }

  Future<void> _loadBeds() async {
    try {
      final r = await _api.fetchEmergencyBeds();
      if (r.success && r.data != null) _data = r.data;
    } catch (_) {}
  }

  Future<void> _loadLogs({String? mrFilter}) async {
    final filter = mrFilter ?? _filterMr;
    _logsLoading = true;
    notifyListeners();
    try {
      final r = await _api.fetchActiveServiceLogs(
          mrFilter: filter.isEmpty ? null : filter);
      _serviceLogs = (r.success && r.data != null) ? r.data! : [];
    } catch (_) {
      _serviceLogs = [];
    }
    _logsLoading = false;
    notifyListeners();
  }

  Future<void> _loadDoctorCalls() async {
    try {
      final r = await _api.fetchActiveDoctorCalls();
      _activeDoctorCalls = (r.success && r.data != null) ? r.data! : [];
    } catch (_) {}
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([_loadQueue(), _loadBeds(), _loadDoctorCalls()]);
    _isLoading = false;
    notifyListeners();
    await _loadLogs();
  }

  // ── Filter ────────────────────────────────────────────────────────────────

  void setFilterMr(String mr) {
    // Toggle: if same MR is tapped again, clear
    _filterMr = _filterMr == mr ? '' : mr;
    notifyListeners();
    _loadLogs(mrFilter: _filterMr);
  }

  void clearFilter() {
    _filterMr = '';
    notifyListeners();
    _loadLogs(mrFilter: '');
  }

  // ── Allot Bed ─────────────────────────────────────────────────────────────
  Future<bool> allotBed({
    required EmergencyBedModel bed,
    required EmergencyQueuePatientModel patient,
    required String status,
  }) async {
    _allotting = true;
    notifyListeners();
    try {
      final r = await _api.allotBed({
        'bed_id': bed.id,
        'patient_mr_number': patient.patientMrNumber,
        'patient_name':      patient.patientName,
        'patient_age':       patient.patientAge,
        'patient_gender':    patient.patientGender,
        'receipt_id':        patient.receiptId,
        'admitted_since':    patient.admittedSince,
        'patient_status':    status,
      });
      if (r.success) await refreshAll();
      return r.success;
    } catch (_) {
      return false;
    } finally {
      _allotting = false;
      notifyListeners();
    }
  }

  // ── Release Bed ───────────────────────────────────────────────────────────
  Future<bool> releaseBed(int allotmentId) async {
    try {
      final r = await _api.releaseBed(allotmentId);
      if (r.success) await refreshAll();
      return r.success;
    } catch (_) {
      return false;
    }
  }

  // ── End Doctor Call ───────────────────────────────────────────────────────
  int? _endingCallId;
  int? get endingCallId => _endingCallId;

  Future<bool> endDoctorCall(int callId) async {
    _endingCallId = callId;
    notifyListeners();
    try {
      final r = await _api.endDoctorCall(callId);
      if (r.success) await refreshAll();
      return r.success;
    } catch (_) {
      return false;
    } finally {
      _endingCallId = null;
      notifyListeners();
    }
  }
}
