import 'package:flutter/foundation.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/payroll_report_model.dart';

class PayrollReportProvider with ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isLoading = false;
  String? _errorMessage;

  String _dateFrom = '';
  String _dateTo = '';
  String _selectedDepartment = '';
  String _selectedEmployee = '';
  String _selectedShift = '';
  String _searchQuery = '';
  String _dateSortOrder = 'desc';
  bool _summarized = false;

  List<PayrollLookupItem> _departments = [];
  List<PayrollLookupItem> _employees = [];
  List<PayrollLookupItem> _shifts = [];
  List<PayrollAttendanceRow> _attendanceRows = [];

  List<PayrollAttendanceRow> _cachedFilteredRows = [];
  List<PayrollReportSummaryRow> _cachedSummarizedRows = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get dateFrom => _dateFrom;
  String get dateTo => _dateTo;
  String get selectedDepartment => _selectedDepartment;
  String get selectedEmployee => _selectedEmployee;
  String get selectedShift => _selectedShift;
  String get searchQuery => _searchQuery;
  String get dateSortOrder => _dateSortOrder;
  bool get summarized => _summarized;

  List<PayrollLookupItem> get departments => _departments;
  List<PayrollLookupItem> get employees => _employees;
  List<PayrollLookupItem> get shifts => _shifts;
  List<PayrollAttendanceRow> get filteredRows => _cachedFilteredRows;
  List<PayrollReportSummaryRow> get summarizedRows => _cachedSummarizedRows;
  int get totalRecords => _cachedFilteredRows.length;

  void setDateFrom(String val) {
    _dateFrom = val;
    _applyFilters();
    notifyListeners();
  }

  void setDateTo(String val) {
    _dateTo = val;
    _applyFilters();
    notifyListeners();
  }

  void setSelectedDepartment(String val) {
    _selectedDepartment = val;
    fetchReport();
  }

  void setSelectedEmployee(String val) {
    _selectedEmployee = val;
    fetchReport();
  }

  void setSelectedShift(String val) {
    _selectedShift = val;
    fetchReport();
  }

  void setSearchQuery(String val) {
    _searchQuery = val;
    _applyFilters();
    notifyListeners();
  }

  void setDateSortOrder(String val) {
    _dateSortOrder = val;
    _applyFilters();
    notifyListeners();
  }

  void setSummarized(bool val) {
    _summarized = val;
    notifyListeners();
  }

  void clearFilters() {
    _dateFrom = '';
    _dateTo = '';
    _selectedDepartment = '';
    _selectedEmployee = '';
    _selectedShift = '';
    _searchQuery = '';
    _dateSortOrder = 'desc';
    _summarized = false;
    fetchReport();
  }

  Future<void> loadLookups() async {
    try {
      final results = await Future.wait([
        _apiService.fetchDepartments(),
        _apiService.fetchEmployees(),
        _apiService.fetchShifts(),
      ]);

      final deptsRaw = results[0];
      final empsRaw = results[1];
      final shiftsRaw = results[2];

      _departments = deptsRaw
          .map((e) => PayrollLookupItem.fromJson(e as Map<String, dynamic>))
          .where((item) => item.id.isNotEmpty && item.id != 'null')
          .toList();
      _employees = empsRaw
          .map((e) => PayrollLookupItem.fromJson(e as Map<String, dynamic>))
          .where((item) => item.id.isNotEmpty && item.id != 'null')
          .toList();
      _shifts = shiftsRaw
          .map((e) => PayrollLookupItem.fromJson(e as Map<String, dynamic>))
          .where((item) => item.id.isNotEmpty && item.id != 'null')
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading payroll lookups: $e');
    }
  }

  Future<void> fetchReport() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final raw = await _apiService.fetchPayrollAttendanceData(
        departmentId: _selectedDepartment.isNotEmpty ? _selectedDepartment : null,
        employeeId: _selectedEmployee.isNotEmpty ? _selectedEmployee : null,
        shiftId: _selectedShift.isNotEmpty ? _selectedShift : null,
      );

      _attendanceRows = raw.map((e) => PayrollAttendanceRow.fromJson(e as Map<String, dynamic>)).toList();
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to load payroll report: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyFilters() {
    var result = List<PayrollAttendanceRow>.from(_attendanceRows);

    if (_selectedDepartment.isNotEmpty) {
      result = result.where((r) => r.departmentId == _selectedDepartment).toList();
    }
    if (_selectedEmployee.isNotEmpty) {
      result = result.where((r) => r.empId == _selectedEmployee).toList();
    }
    if (_selectedShift.isNotEmpty) {
      result = result.where((r) => r.dutyShiftId == _selectedShift).toList();
    }

    if (_dateFrom.isNotEmpty) {
      final from = DateTime.tryParse(_dateFrom);
      if (from != null) {
        result = result.where((r) {
          final d = r.parsedDate;
          return d != null && (d.isAfter(from) || d.isAtSameMomentAs(from));
        }).toList();
      }
    }

    if (_dateTo.isNotEmpty) {
      final to = DateTime.tryParse(_dateTo);
      if (to != null) {
        result = result.where((r) {
          final d = r.parsedDate;
          return d != null && (d.isBefore(to) || d.isAtSameMomentAs(to));
        }).toList();
      }
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((r) {
        return r.empId.toLowerCase().contains(query) ||
            r.employeeName.toLowerCase().contains(query) ||
            r.departmentName.toLowerCase().contains(query) ||
            r.dutyShiftName.toLowerCase().contains(query) ||
            r.machineCode.toLowerCase().contains(query) ||
            r.status.toLowerCase().contains(query);
      }).toList();
    }

    result.sort((a, b) {
      final da = a.parsedDate ?? DateTime(1970);
      final db = b.parsedDate ?? DateTime(1970);
      final cmp = _dateSortOrder == 'asc' ? da.compareTo(db) : db.compareTo(da);
      if (cmp != 0) return cmp;
      return a.timeIn.compareTo(b.timeIn);
    });

    _cachedFilteredRows = result;

    final map = <String, PayrollReportSummaryRow>{};
    for (final r in _cachedFilteredRows) {
      final key = r.employeeName.isNotEmpty && r.employeeName != '-' ? r.employeeName : r.empId;

      if (!map.containsKey(key)) {
        map[key] = PayrollReportSummaryRow(
          srlNo: 0,
          employeeName: key,
          empId: r.empId,
          totalDays: 0,
          presentDays: 0,
          lateDays: 0,
          absentDays: 0,
        );
      }

      final ex = map[key]!;
      final st = r.status.toLowerCase();

      map[key] = PayrollReportSummaryRow(
        srlNo: 0,
        employeeName: ex.employeeName,
        empId: ex.empId,
        totalDays: ex.totalDays + 1,
        presentDays: ex.presentDays + (st.contains('present') ? 1 : 0),
        lateDays: ex.lateDays + (st.contains('late') ? 1 : 0),
        absentDays: ex.absentDays + (st.contains('absent') ? 1 : 0),
      );
    }

    final list = map.values.toList();
    list.sort((a, b) => a.employeeName.compareTo(b.employeeName));

    _cachedSummarizedRows = List.generate(list.length, (index) {
      final item = list[index];
      return PayrollReportSummaryRow(
        srlNo: index + 1,
        employeeName: item.employeeName,
        empId: item.empId,
        totalDays: item.totalDays,
        presentDays: item.presentDays,
        lateDays: item.lateDays,
        absentDays: item.absentDays,
      );
    });
  }
}
