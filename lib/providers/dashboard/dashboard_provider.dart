import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/services/auth_storage_service.dart';
import '../../global/global_api.dart';
import '../../models/dashboard_model.dart';
import '../../core/utils/database_helper.dart';

// Preset descriptor
class RangePreset {
  final String id;
  final String label;

  const RangePreset({required this.id, required this.label});
}

const List<RangePreset> kRangePresets = [
  RangePreset(id: 'today', label: 'Today'),
  RangePreset(id: 'week', label: 'This Week'),
  RangePreset(id: 'month', label: 'This Month'),
  RangePreset(id: 'year', label: 'This Year'),
  RangePreset(id: 'fiscal', label: 'Fiscal Year'),
  RangePreset(id: 'custom', label: 'Custom Range'),
];

class DashboardProvider extends ChangeNotifier {
  final AuthStorageService _storage = AuthStorageService();

  // ─── Loading states ──────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCalendarLoading = false;
  bool get isCalendarLoading => _isCalendarLoading;

  bool _isAttendanceLoading = false;
  bool get isAttendanceLoading => _isAttendanceLoading;

  // ─── Date range / preset / shift filters ─────────────────────────────────
  String _selectedPreset = 'today';
  String get selectedPreset => _selectedPreset;

  DateTime _dateFrom = DateTime.now();
  DateTime get dateFrom => _dateFrom;

  DateTime _dateTo = DateTime.now();
  DateTime get dateTo => _dateTo;

  // Legacy getter for widgets expecting single date
  DateTime get selectedDate => _dateFrom;

  String _selectedShiftType = 'All';
  String get selectedShiftType => _selectedShiftType;

  String? _runningShift;
  String? get runningShift => _runningShift;

  // ─── Selected category (for card/bar interaction) ─────────────────────────
  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;

  void setSelectedCategory(String? key) {
    _selectedCategory = (_selectedCategory == key) ? null : key;
    notifyListeners();
  }

  // ─── Management-dashboard summary ────────────────────────────────────────
  ManagementSummary? _summary;
  ManagementSummary? get summary => _summary;

  // ─── Attendance ──────────────────────────────────────────────────────────
  List<AttendanceRecord> _attendanceRecords = [];
  List<AttendanceRecord> get attendanceRecords => _attendanceRecords;
  String? _attendanceError;
  String? get attendanceError => _attendanceError;

  // ─── Legacy shift data (kept for existing widgets) ───────────────────────
  List<ShiftDashboardInfo> _availableShifts = [];
  List<ShiftDashboardInfo> get availableShifts => _availableShifts;

  List<dynamic> _opdData = [];
  List<dynamic> _expenses = [];
  List<dynamic> get opdData => _opdData;
  List<dynamic> get expenses => _expenses;
  Map<String, Map<String, List<dynamic>>> _calendarData = {};

  // ─── Calendar navigation month (independent of filter date range) ──────────
  DateTime _calendarDate = DateTime.now();
  DateTime get calendarDate => _calendarDate;

  // Legacy computed getters
  double totalOpdRevenue = 0;
  double totalConsultRevenue = 0;
  int totalConsultCount = 0;
  int totalPatients = 0;
  double totalExpenses = 0;
  List<ExpenseBreakdownItem> expenseBreakdown = [];
  double avgRevenuePerPatient = 0;
  double netRevenue = 0;
  String topExpenseCategory = '—';

  Map<String, double> shiftOpdRevenue = {'Morning': 0, 'Evening': 0, 'Night': 0};
  Map<String, double> shiftConsultRevenue = {'Morning': 0, 'Evening': 0, 'Night': 0};
  Map<String, int> shiftPatientCount = {'Morning': 0, 'Evening': 0, 'Night': 0};
  Map<String, int> shiftConsultCount = {'Morning': 0, 'Evening': 0, 'Night': 0};
  List<ChartDataPoint> trendData = [];

  // ─── Auth helpers ────────────────────────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Preset & date range helpers ─────────────────────────────────────────
  ({DateTime from, DateTime to}) _resolvePreset(String id, DateTime now) {
    switch (id) {
      case 'today':
        return (from: now, to: now);
      case 'week':
        final back = now.weekday == 7 ? 6 : now.weekday - 1; // Monday start
        final from = DateTime(now.year, now.month, now.day - back);
        final to = from.add(const Duration(days: 6));
        return (from: from, to: to);
      case 'month':
        final from = DateTime(now.year, now.month, 1);
        final to = DateTime(now.year, now.month + 1, 0);
        return (from: from, to: to);
      case 'year':
        final from = DateTime(now.year, 1, 1);
        final to = DateTime(now.year, 12, 31);
        return (from: from, to: to);
      case 'fiscal':
        final startYear = now.month >= 7 ? now.year : now.year - 1;
        final from = DateTime(startYear, 7, 1);
        final to = DateTime(startYear + 1, 6, 30);
        return (from: from, to: to);
      default:
        return (from: now, to: now);
    }
  }

  String _matchPreset(DateTime from, DateTime to, DateTime now) {
    final fmt = DateFormat('yyyy-MM-dd');
    for (final p in ['today', 'week', 'month', 'year', 'fiscal']) {
      final r = _resolvePreset(p, now);
      if (fmt.format(r.from) == fmt.format(from) && fmt.format(r.to) == fmt.format(to)) {
        return p;
      }
    }
    return 'custom';
  }

  Future<void> applyPreset(String presetId) async {
    if (presetId == 'custom') {
      _selectedPreset = 'custom';
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    final r = _resolvePreset(presetId, now);
    _selectedPreset = presetId;
    _dateFrom = r.from;
    _dateTo = r.to;
    _selectedCategory = null;
    notifyListeners();
    await refresh();
  }

  Future<void> setDateFrom(DateTime from) async {
    _dateFrom = from;
    if (_dateTo.isBefore(from)) {
      _dateTo = from;
    }
    _selectedPreset = _matchPreset(_dateFrom, _dateTo, DateTime.now());
    _selectedCategory = null;
    notifyListeners();
    await refresh();
  }

  Future<void> setDateTo(DateTime to) async {
    _dateTo = to;
    if (_dateFrom.isAfter(to)) {
      _dateFrom = to;
    }
    _selectedPreset = _matchPreset(_dateFrom, _dateTo, DateTime.now());
    _selectedCategory = null;
    notifyListeners();
    await refresh();
  }

  // Legacy single date setter
  Future<void> setSelectedDate(DateTime date) async {
    _dateFrom = date;
    _dateTo = date;
    _selectedPreset = 'today';
    _selectedCategory = null;
    notifyListeners();
    await refresh();
  }

  void setSelectedShiftType(String type) {
    _selectedShiftType = type;
    _selectedCategory = null;
    _fetchManagementSummary();
    fetchData();
    notifyListeners();
  }

  void resetToToday() {
    final now = DateTime.now();
    _dateFrom = now;
    _dateTo = now;
    _selectedPreset = 'today';
    _selectedShiftType = 'All';
    _selectedCategory = null;
    notifyListeners();
  }

  void resetLoading() {
    _isLoading = true;
    notifyListeners();
  }

  // ─── Running shift API ───────────────────────────────────────────────────
  Future<void> fetchCurrentShift() async {
    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/shifts/current';
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final type = json['data']?['shift_type']?.toString();
        if (type != null && type.isNotEmpty && type != 'All') {
          _runningShift = type;
          notifyListeners();
        }
      }
    } catch (e) {
      developer.log('Error fetching current shift: $e', name: 'DashboardProvider');
    }
  }

  // ─── Management-dashboard API ─────────────────────────────────────────────
  Future<void> _fetchManagementSummary() async {
    try {
      final headers = await _authHeaders();
      final fromStr = DateFormat('yyyy-MM-dd').format(_dateFrom);
      final toStr = DateFormat('yyyy-MM-dd').format(_dateTo);
      final shift = _selectedShiftType == 'All' ? '' : _selectedShiftType;
      final params = 'startDate=$fromStr&endDate=$toStr${shift.isNotEmpty ? '&shift=$shift' : ''}';
      final url = '${GlobalApi.baseUrl}/reports/management-dashboard?$params';
      developer.log('📡 GET $url', name: 'DashboardProvider');

      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          _summary = ManagementSummary.fromJson(json['data'] as Map<String, dynamic>);
          developer.log('✅ ManagementSummary loaded', name: 'DashboardProvider');
          _syncLegacyFromSummary();
        }
      } else if (response.statusCode == 403) {
        developer.log('⛔ No permission for management-dashboard', name: 'DashboardProvider');
      } else {
        developer.log('⚠️ management-dashboard HTTP ${response.statusCode}', name: 'DashboardProvider');
      }
    } catch (e) {
      developer.log('Error fetching management summary: $e', name: 'DashboardProvider');
    }
  }

  void _syncLegacyFromSummary() {
    if (_summary == null) return;
    totalOpdRevenue = _summary!.opd.amount;
    totalConsultRevenue = _summary!.consultation.amount;
    totalConsultCount = _summary!.consultation.qty;
    totalPatients = _summary!.opd.qty;
    totalExpenses = _summary!.expenses.amount;
    netRevenue = _summary!.revenue.net;
  }

  // ─── Attendance API ───────────────────────────────────────────────────────
  Future<void> fetchAttendance([DateTime? date]) async {
    _isAttendanceLoading = true;
    _attendanceError = null;
    notifyListeners();

    try {
      final headers = await _authHeaders();
      final targetDate = date ?? (_dateFrom == _dateTo ? _dateFrom : DateTime.now());
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final url = '${GlobalApi.baseUrl}/attendance/report?date_from=$dateStr&date_to=$dateStr&limit=2000';
      developer.log('📡 GET $url (attendance)', name: 'DashboardProvider');

      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];
        if (data is List) {
          _attendanceRecords = data
              .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
              .toList();
          _attendanceRecords.sort((a, b) {
            if (a.sortRank != b.sortRank) return a.sortRank.compareTo(b.sortRank);
            return b.lateMinutes.compareTo(a.lateMinutes);
          });
          developer.log('✅ ${_attendanceRecords.length} attendance records', name: 'DashboardProvider');
        }
      }
    } catch (e) {
      _attendanceError = 'Attendance unavailable';
      developer.log('Error fetching attendance: $e', name: 'DashboardProvider');
    }

    _isAttendanceLoading = false;
    notifyListeners();
  }

  // ─── Main refresh ─────────────────────────────────────────────────────────
  Future<void> refresh() async {
    await Future.wait([
      fetchCurrentShift(),
      fetchAvailableShifts(_dateFrom),
      fetchCalendarData(_dateFrom),
      fetchAttendance(_dateFrom == _dateTo ? _dateFrom : DateTime.now()),
    ]);
  }

  // ─── Legacy: fetch available shifts + opd data ────────────────────────────
  Future<void> fetchAvailableShifts(DateTime date) async {
    _isLoading = true;
    _availableShifts = [];
    notifyListeners();

    final fromStr = DateFormat('yyyy-MM-dd').format(_dateFrom);

    try {
      final headers = await _authHeaders();
      final url = '${GlobalApi.baseUrl}/opd-patient-data?shift_date=$fromStr&limit=500';
      developer.log('📡 GET $url (for shifts)', name: 'DashboardProvider');
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] is List) {
          final List<dynamic> data = json['data'];
          final Map<int, ShiftDashboardInfo> shiftsMap = {};

          for (var r in data) {
            final shiftId = r['shift_id'];
            if (shiftId != null && !shiftsMap.containsKey(shiftId)) {
              shiftsMap[shiftId] = ShiftDashboardInfo(
                shiftId: shiftId,
                shiftType: r['shift_type'] ?? 'Unknown',
                shiftDate: r['shift_date'] ?? fromStr,
              );
            }
          }

          final List<ShiftDashboardInfo> allShifts = shiftsMap.values.toList()
            ..sort((a, b) => a.shiftId.compareTo(b.shiftId));

          final nightShifts = allShifts.where((s) => _normalizeShiftType(s.shiftType) == 'Night').toList();
          int? shiftIdToExclude;
          if (nightShifts.length > 1) {
            shiftIdToExclude = nightShifts[0].shiftId;
          }

          _availableShifts = allShifts.where((s) => s.shiftId != shiftIdToExclude).toList();
        }
      }
    } catch (e) {
      developer.log('Error fetching available shifts: $e', name: 'DashboardProvider');
    }

    await Future.wait([
      _fetchManagementSummary(),
      fetchData(),
    ]);
    notifyListeners();
  }

  Future<void> fetchData() async {
    _isLoading = true;
    _opdData = [];
    _expenses = [];
    _processData();
    notifyListeners();

    List<int> shiftIdsToFetch = [];
    if (_selectedShiftType == 'All') {
      shiftIdsToFetch = _availableShifts.map((s) => s.shiftId).toList();
    } else {
      shiftIdsToFetch = _availableShifts
          .where((s) => _normalizeShiftType(s.shiftType) == _selectedShiftType)
          .map((s) => s.shiftId)
          .toList();
    }

    try {
      final headers = await _authHeaders();
      List<dynamic> allOpdData = [];
      List<dynamic> allExpenses = [];
      final Set<dynamic> seenRecords = {};
      final Set<dynamic> seenExpenses = {};

      final fromStr = DateFormat('yyyy-MM-dd').format(_dateFrom);

      if (shiftIdsToFetch.isEmpty && _selectedShiftType == 'All') {
        final opdUrl = '${GlobalApi.baseUrl}/opd-patient-data?shift_date=$fromStr&reg_date=$fromStr&registration_date=$fromStr&date=$fromStr&limit=500';
        final expUrl = '${GlobalApi.baseUrl}/expenses?shift_date=$fromStr&reg_date=$fromStr&date=$fromStr&limit=500';

        final responses = await Future.wait([
          http.get(Uri.parse(opdUrl), headers: headers),
          http.get(Uri.parse(expUrl), headers: headers),
        ]);

        final opdRes = responses[0];
        final expRes = responses[1];

        if (opdRes.statusCode == 200) {
          final json = jsonDecode(opdRes.body);
          if (json['success'] == true && json['data'] != null) {
            allOpdData = json['data'];
          }
        }
        if (expRes.statusCode == 200) {
          final json = jsonDecode(expRes.body);
          if (json['success'] == true && json['data'] != null) {
            allExpenses = json['data'];
          }
        }
      } else {
        final futures = shiftIdsToFetch.map((shiftId) async {
          final opdUrl = '${GlobalApi.baseUrl}/opd-patient-data/shift/$shiftId?shift_date=$fromStr&reg_date=$fromStr&date=$fromStr';
          final opdRes = await http.get(Uri.parse(opdUrl), headers: headers);
          if (opdRes.statusCode == 200) {
            final json = jsonDecode(opdRes.body);
            if (json['success'] == true && json['data'] != null) {
              return {'type': 'opd', 'data': json['data']};
            }
          }
          return null;
        }).toList();

        final expFutures = shiftIdsToFetch.map((shiftId) async {
          final expUrl = '${GlobalApi.baseUrl}/expenses/shift/$shiftId?shift_date=$fromStr&date=$fromStr';
          final expRes = await http.get(Uri.parse(expUrl), headers: headers);
          if (expRes.statusCode == 200) {
            final json = jsonDecode(expRes.body);
            if (json['success'] == true && json['data'] != null) {
              return {'type': 'expense', 'data': json['data']};
            }
          }
          return null;
        }).toList();

        final results = await Future.wait([...futures, ...expFutures]);

        for (var result in results) {
          if (result == null) continue;
          final List<dynamic> data = result['data'];
          if (result['type'] == 'opd') {
            for (var r in data) {
              if (seenRecords.add(r['srl_no'])) {
                allOpdData.add(r);
              }
            }
          } else {
            for (var e in data) {
              final key = e['id'] ?? e['srl_no'];
              if (seenExpenses.add(key)) {
                allExpenses.add(e);
              }
            }
          }
        }
      }

      _opdData = allOpdData;
      _expenses = allExpenses;
      _processData();
    } catch (e) {
      developer.log('Error fetching dashboard data: $e', name: 'DashboardProvider');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _processData() async {
    totalOpdRevenue = 0;
    totalConsultRevenue = 0;
    totalConsultCount = 0;
    totalPatients = 0;
    totalExpenses = 0;
    shiftOpdRevenue = {'Morning': 0, 'Evening': 0, 'Night': 0};
    shiftConsultRevenue = {'Morning': 0, 'Evening': 0, 'Night': 0};
    shiftPatientCount = {'Morning': 0, 'Evening': 0, 'Night': 0};
    shiftConsultCount = {'Morning': 0, 'Evening': 0, 'Night': 0};
    Map<String, double> hourMap = {};

    for (var r in _opdData) {
      final shift = _normalizeShiftType(r['shift_type']);
      if (!shiftOpdRevenue.containsKey(shift)) continue;

      final amount = _parseDouble(r['service_amount'] ?? r['total_amount']);

      totalOpdRevenue += amount;
      totalPatients += 1;

      shiftOpdRevenue[shift] = (shiftOpdRevenue[shift] ?? 0) + amount;
      shiftPatientCount[shift] = (shiftPatientCount[shift] ?? 0) + 1;

      final opdService = (r['opd_service'] ?? '').toString().trim();
      if (opdService == 'Consultation') {
        totalConsultRevenue += amount;
        totalConsultCount += 1;
        shiftConsultRevenue[shift] = (shiftConsultRevenue[shift] ?? 0) + amount;
        shiftConsultCount[shift] = (shiftConsultCount[shift] ?? 0) + 1;
      }

      try {
        final dateStr = r['created_at'] ?? r['reg_date'] ?? r['date_time'] ?? '';
        if (dateStr.isNotEmpty) {
          DateTime dt;
          if (dateStr.contains('T')) {
            dt = DateTime.parse(dateStr);
          } else {
            dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateStr);
          }
          final hourKey = DateFormat('h a').format(dt);
          hourMap[hourKey] = (hourMap[hourKey] ?? 0) + amount;
        }
      } catch (_) {}
    }

    Map<String, double> expMap = {};
    for (var e in _expenses) {
      final amt = _parseDouble(e['expense_amount']);
      totalExpenses += amt;
      final category = (e['expense_type'] ?? e['category'] ?? e['expense_head'] ?? e['expense_name'] ?? 'Other').toString().trim();
      expMap[category] = (expMap[category] ?? 0) + amt;
    }

    final sortedExp = expMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    expenseBreakdown = sortedExp.take(8).map((entry) => ExpenseBreakdownItem(
      name: entry.key,
      value: entry.value,
      color: _getContrastColor(sortedExp.indexOf(entry)),
    )).toList();

    avgRevenuePerPatient = totalPatients > 0 ? (totalOpdRevenue / totalPatients) : 0;
    netRevenue = totalOpdRevenue - totalExpenses;
    topExpenseCategory = sortedExp.isNotEmpty ? sortedExp[0].key : '—';

    final sortedHours = hourMap.entries.toList()..sort((a, b) {
      final order = {
        '12 AM': 0, '1 AM': 1, '2 AM': 2, '3 AM': 3, '4 AM': 4, '5 AM': 5, '6 AM': 6, '7 AM': 7,
        '8 AM': 8, '9 AM': 9, '10 AM': 10, '11 AM': 11, '12 PM': 12, '1 PM': 13, '2 PM': 14,
        '3 PM': 15, '4 PM': 16, '5 PM': 17, '6 PM': 18, '7 PM': 19, '8 PM': 20, '9 PM': 21,
        '10 PM': 22, '11 PM': 23
      };
      return (order[a.key] ?? 0).compareTo(order[b.key] ?? 0);
    });

    trendData = sortedHours.map((e) => ChartDataPoint(e.key, e.value)).toList();
    if (trendData.isEmpty) {
      trendData = [ChartDataPoint('8 AM', 0), ChartDataPoint('12 PM', 0), ChartDataPoint('6 PM', 0)];
    }
  }

  String _normalizeShiftType(dynamic type) {
    if (type == null) return 'Unknown';
    final t = type.toString().trim().toLowerCase();
    if (t == 'morning') return 'Morning';
    if (t == 'evening') return 'Evening';
    if (t == 'night') return 'Night';
    return 'Unknown';
  }

  Color _getContrastColor(int index) {
    final colors = [
      const Color(0xFF10B981),
      const Color(0xFF6366F1),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFFF97316),
      const Color(0xFF64748B),
    ];
    return colors[index % colors.length];
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // ─── Calendar data ────────────────────────────────────────────────────────
  Future<void> fetchCalendarData(DateTime date) async {
    _calendarDate = date;   // ← remember navigated month
    _isCalendarLoading = true;
    notifyListeners();

    try {
      final headers = await _authHeaders();
      final year = date.year;
      final month = date.month;
      final url = '${GlobalApi.baseUrl}/appointments/calendar?year=$year&month=$month';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] is List) {
          final List<dynamic> appointments = json['data'];
          Map<String, Map<String, List<dynamic>>> grouped = {};

          for (var apt in appointments) {
            final dateStr = DateTime.parse(apt['appointment_date']).toIso8601String().split('T')[0];
            final doctorName = apt['doctor_name'] ?? 'Unknown Doctor';

            grouped.putIfAbsent(dateStr, () => {});
            grouped[dateStr]!.putIfAbsent(doctorName, () => []);
            grouped[dateStr]![doctorName]!.add(apt);
          }
          _calendarData = grouped;
        }
      }
    } catch (e) {
      developer.log('Error fetching calendar data from API: $e', name: 'DashboardProvider');
    }

    // Merge local appointments
    try {
      final db = await DatabaseHelper().database;

      final doctorRows = await db.query('master_doctors');
      final doctorMap = {
        for (var d in doctorRows)
          d['srl_no'].toString(): d['doctor_name']?.toString() ?? 'Dr. Unknown'
      };

      final localRows = await db.query('appointments_local');

      for (var row in localRows) {
        final dateStr = DateTime.tryParse(row['appointment_date']?.toString() ?? '')
            ?.toIso8601String().split('T')[0];
        if (dateStr == null) continue;

        final docSrlNo = row['doctor_srl_no']?.toString() ?? '';
        final doctorName = doctorMap[docSrlNo] ?? 'Dr. ID: $docSrlNo';

        _calendarData.putIfAbsent(dateStr, () => {});
        _calendarData[dateStr]!.putIfAbsent(doctorName, () => []);

        final alreadyPresent = _calendarData[dateStr]![doctorName]!
            .any((a) => a['device_uuid'] == row['device_uuid']);

        if (!alreadyPresent) {
          _calendarData[dateStr]![doctorName]!.add({
            'appointment_date': row['appointment_date'],
            'doctor_name': doctorName,
            'patient_name': row['patient_name'],
            'slot_time': row['appointment_time'],
            'token_number': row['token_number'],
            'sync_status': row['sync_status'],
            'device_uuid': row['device_uuid'],
          });
        }
      }
    } catch (e) {
      developer.log('Error loading local appointments for calendar: $e', name: 'DashboardProvider');
    }

    _isCalendarLoading = false;
    notifyListeners();
  }

  Map<String, Map<String, List<dynamic>>> get calendarData => _calendarData;
  List<ChartDataPoint> get barChartData => [];
}
