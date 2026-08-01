import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/shift_report_model.dart';

class ShiftGroupItem {
  final String name;
  final double total;
  final double share;
  final double hospital;
  final int count;

  ShiftGroupItem({
    required this.name,
    required this.total,
    required this.share,
    required this.hospital,
    required this.count,
  });
}

class ShiftReportProvider extends ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isDisposed = false;
  bool _loading = false;
  String? _errorMessage;

  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  dynamic _selectedShiftId = 'All';
  List<AvailableShift> _availableShifts = [];

  List<ShiftOpdRecord> _opdData = [];
  List<ShiftExpenseRecord> _expenses = [];
  List<ShiftEmergencyBill> _emergencyBills = [];

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;

  String get selectedDate => _selectedDate;
  dynamic get selectedShiftId => _selectedShiftId;
  List<AvailableShift> get availableShifts => _availableShifts;

  List<ShiftOpdRecord> get opdData => _opdData;
  List<ShiftExpenseRecord> get expenses => _expenses;
  List<ShiftEmergencyBill> get emergencyBills => _emergencyBills;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void setSelectedDate(String dateStr) {
    _selectedDate = dateStr;
    loadShiftDataForDate();
  }

  void setSelectedShiftId(dynamic id) {
    _selectedShiftId = id;
    fetchData();
  }

  Future<void> loadShiftDataForDate() async {
    _loading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final shiftsRaw = await _apiService.fetchAvailableShiftsForDate(_selectedDate);
      final Map<dynamic, AvailableShift> shiftMap = {};

      for (final item in shiftsRaw) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['shift_id'];
        if (id != null && !shiftMap.containsKey(id)) {
          shiftMap[id] = AvailableShift.fromJson(item);
        }
      }

      List<AvailableShift> allShifts = shiftMap.values.toList();
      allShifts.sort((a, b) {
        final idA = int.tryParse(a.shiftId.toString()) ?? 0;
        final idB = int.tryParse(b.shiftId.toString()) ?? 0;
        return idA.compareTo(idB);
      });

      final nightShifts = allShifts.where((s) => s.shiftType.toLowerCase() == 'night').toList();
      dynamic shiftIdToExclude;
      if (nightShifts.length > 1) {
        shiftIdToExclude = nightShifts[0].shiftId;
      }

      _availableShifts = allShifts.where((s) => s.shiftId != shiftIdToExclude).toList();
      _selectedShiftId = 'All';
      await fetchData();
    } catch (e) {
      _errorMessage = 'Failed to load available shifts: $e';
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> fetchData() async {
    _loading = true;
    _errorMessage = null;
    _safeNotify();

    List<dynamic> targetShiftIds = [];
    if (_selectedShiftId == 'All') {
      targetShiftIds = _availableShifts.map((s) => s.shiftId).toList();
    } else {
      targetShiftIds = [_selectedShiftId];
    }

    if (targetShiftIds.isEmpty) {
      _opdData = [];
      _expenses = [];
      _emergencyBills = [];
      _loading = false;
      _safeNotify();
      return;
    }

    try {
      final opdFutures = targetShiftIds.map((id) => _apiService.fetchShiftOpdData(id));
      final expFutures = targetShiftIds.map((id) {
        final shiftInfo = _availableShifts.firstWhere(
          (s) => s.shiftId == id,
          orElse: () => AvailableShift(shiftId: id, shiftType: '', shiftDate: ''),
        );
        return _apiService.fetchShiftExpensesData(
          id,
          shiftDate: shiftInfo.shiftDate.isNotEmpty ? shiftInfo.shiftDate : null,
          shiftType: shiftInfo.shiftType.isNotEmpty ? shiftInfo.shiftType : null,
        );
      });
      final emergFutures = targetShiftIds.map((id) => _apiService.fetchShiftEmergencyBills(id));

      final results = await Future.wait([
        Future.wait(opdFutures),
        Future.wait(expFutures),
        Future.wait(emergFutures),
      ]);

      // 1. OPD
      final opdLists = results[0];
      List<ShiftOpdRecord> allOpd = [];
      final Set<dynamic> seenOpd = {};
      for (final res in opdLists) {
        for (final item in res) {
          if (item is! Map<String, dynamic>) continue;
          final rec = ShiftOpdRecord.fromJson(item);
          if (!seenOpd.contains(rec.srlNo)) {
            seenOpd.add(rec.srlNo);
            allOpd.add(rec);
          }
        }
      }
      _opdData = allOpd;

      // 2. Expenses
      final expLists = results[1];
      List<ShiftExpenseRecord> allExp = [];
      final Set<dynamic> seenExp = {};
      for (final res in expLists) {
        for (final item in res) {
          if (item is! Map<String, dynamic>) continue;
          final rec = ShiftExpenseRecord.fromJson(item);
          if (!seenExp.contains(rec.id)) {
            seenExp.add(rec.id);
            allExp.add(rec);
          }
        }
      }
      _expenses = allExp;

      // 3. Emergency Bills
      final emergLists = results[2];
      List<ShiftEmergencyBill> allEmerg = [];
      final Set<dynamic> seenEmerg = {};
      for (final res in emergLists) {
        for (final item in res) {
          if (item is! Map<String, dynamic>) continue;
          final rec = ShiftEmergencyBill.fromJson(item);
          if (!seenEmerg.contains(rec.id)) {
            seenEmerg.add(rec.id);
            allEmerg.add(rec);
          }
        }
      }
      _emergencyBills = allEmerg;
    } catch (e) {
      _errorMessage = 'Failed to fetch shift details: $e';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  // ── Computations matching React ShiftReport.jsx ──────────────────────────
  List<ShiftOpdRecord> get cancelledConsultations =>
      _opdData.where((r) => r.isCancelled && r.isConsultation).toList();

  List<ShiftOpdRecord> get cancelledOther =>
      _opdData.where((r) => r.isCancelled && !r.isConsultation).toList();

  List<ShiftGroupItem> get consultationData {
    final Map<String, ShiftGroupItem> map = {};
    for (final r in _opdData) {
      if (r.isCancelled || !r.isConsultation) continue;
      final drName = r.doctorName.isEmpty ? "Unknown Doctor" : r.doctorName;
      if (!map.containsKey(drName)) {
        map[drName] = ShiftGroupItem(name: drName, total: r.feeAmount, share: r.drShareAmount, hospital: r.hospitalShare, count: 1);
      } else {
        final existing = map[drName]!;
        map[drName] = ShiftGroupItem(
          name: drName,
          total: existing.total + r.feeAmount,
          share: existing.share + r.drShareAmount,
          hospital: existing.hospital + r.hospitalShare,
          count: existing.count + 1,
        );
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<ShiftGroupItem> get otherData {
    final Map<String, ShiftGroupItem> map = {};
    for (final r in _opdData) {
      if (r.isCancelled || r.isConsultation) continue;
      final serviceName = r.opdService.isEmpty ? "Other" : r.opdService;
      if (!map.containsKey(serviceName)) {
        map[serviceName] = ShiftGroupItem(name: serviceName, total: r.feeAmount, share: r.drShareAmount, hospital: r.hospitalShare, count: 1);
      } else {
        final existing = map[serviceName]!;
        map[serviceName] = ShiftGroupItem(
          name: serviceName,
          total: existing.total + r.feeAmount,
          share: existing.share + r.drShareAmount,
          hospital: existing.hospital + r.hospitalShare,
          count: existing.count + 1,
        );
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<ShiftGroupItem> get emergencyData {
    final Map<String, ShiftGroupItem> map = {};
    for (final b in _emergencyBills) {
      final name = b.serviceHead.isEmpty ? "Emergency" : b.serviceHead;
      if (!map.containsKey(name)) {
        map[name] = ShiftGroupItem(name: name, total: b.netAmount, share: 0, hospital: b.netAmount, count: 1);
      } else {
        final existing = map[name]!;
        map[name] = ShiftGroupItem(name: name, total: existing.total + b.netAmount, share: 0, hospital: existing.hospital + b.netAmount, count: existing.count + 1);
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  double get totalRevenue {
    double opdActiveRev = _opdData.where((r) => !r.isCancelled).fold(0.0, (sum, r) => sum + r.feeAmount);
    double emergRev = _emergencyBills.fold(0.0, (sum, b) => sum + b.netAmount);
    return opdActiveRev + emergRev;
  }

  double get totalDocShare {
    return _opdData.where((r) => !r.isCancelled).fold(0.0, (sum, r) => sum + r.drShareAmount);
  }

  double get expenseTotalOnly => _expenses.fold(0.0, (sum, r) => sum + r.expenseAmount);

  double get totalExpensesWithDocShare => expenseTotalOnly + totalDocShare;

  double get netHospitalRevenue => totalRevenue - totalExpensesWithDocShare;

  int get cancelledCount => _opdData.where((r) => r.isCancelled).length;

  double get cancelledTotal => _opdData.where((r) => r.isCancelled).fold(0.0, (sum, r) => sum + r.feeAmount);
}
