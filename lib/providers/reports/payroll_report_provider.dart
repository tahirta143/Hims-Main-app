import 'package:flutter/foundation.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/payroll_report_model.dart';

class PayrollReportProvider with ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isLoading = false;
  String? _errorMessage;

  // Tabs
  String _activeTab = 'register'; // 'register', 'employeewise', 'monthly', 'salary-sheet', 'salary-slip'
  bool _isFilterApplied = false;

  String _dateFrom = '';
  String _dateTo = '';
  String _selectedDepartment = '';
  String _selectedEmployee = '';
  String _selectedShift = '';
  String _searchQuery = '';
  String _dateSortOrder = 'desc';
  bool _summarized = false;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  List<PayrollLookupItem> _departments = [];
  List<PayrollLookupItem> _employees = [];
  List<PayrollLookupItem> _shifts = [];
  List<PayrollAttendanceRow> _attendanceRows = [];
  List<EmployeewiseAttendanceRow> _employeewiseRows = [];
  List<EmployeewiseAttendanceRow> _filteredEmployeewiseRows = [];
  List<MonthlyAttendanceEmployee> _monthlyRows = [];
  List<PayrollRun> _runs = [];
  PayrollRun? _currentRun;
  List<SalarySheetLine> _salaryLines = [];
  Map<String, dynamic>? _currentSlip;

  List<PayrollAttendanceRow> _cachedFilteredRows = [];
  List<PayrollReportSummaryRow> _cachedSummarizedRows = [];

  PayrollReportProvider() {
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _dateFrom = today;
    _dateTo = today;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeTab => _activeTab;
  bool get isFilterApplied => _isFilterApplied;
  String get dateFrom => _dateFrom;
  String get dateTo => _dateTo;
  String get selectedDepartment => _selectedDepartment;
  String get selectedEmployee => _selectedEmployee;
  String get selectedShift => _selectedShift;
  String get searchQuery => _searchQuery;
  String get dateSortOrder => _dateSortOrder;
  bool get summarized => _summarized;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;

  bool get hasActiveFilters {
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    return _searchQuery.trim().isNotEmpty ||
           _dateFrom != today ||
           _dateTo != today ||
           _selectedDepartment.isNotEmpty ||
           _selectedEmployee.isNotEmpty ||
           _selectedShift.isNotEmpty;
  }

  List<PayrollLookupItem> get departments => _departments;
  List<PayrollLookupItem> get employees => _employees;
  List<PayrollLookupItem> get shifts => _shifts;
  List<PayrollAttendanceRow> get filteredRows => _cachedFilteredRows;
  List<PayrollReportSummaryRow> get summarizedRows => _cachedSummarizedRows;
  List<EmployeewiseAttendanceRow> get employeewiseRows => _employeewiseRows;
  List<EmployeewiseAttendanceRow> get filteredEmployeewiseRows => _filteredEmployeewiseRows;
  List<MonthlyAttendanceEmployee> get monthlyRows => _monthlyRows;
  List<PayrollRun> get runs => _runs;
  PayrollRun? get currentRun => _currentRun;
  List<SalarySheetLine> get salaryLines => _salaryLines;
  Map<String, dynamic>? get currentSlip => _currentSlip;

  int get totalRecords => _cachedFilteredRows.length;
  int get uniqueEmployees => _cachedFilteredRows.map((r) => r.empId).toSet().length;
  int get uniqueDepartments => _cachedFilteredRows.map((r) => r.departmentName).toSet().length;
  int get uniqueShifts => _cachedFilteredRows.map((r) => r.dutyShiftName).toSet().length;

  double get totalPresentDays => _employeewiseRows.fold(0.0, (sum, r) => sum + r.presentDays);
  int get totalAbsentDays => _employeewiseRows.fold(0, (sum, r) => sum + r.absentDays);
  int get totalOvertimeMinutes => _employeewiseRows.fold(0, (sum, r) => sum + r.overtimeMinutes);
  int get totalFlaggedDays => _employeewiseRows.fold(0, (sum, r) => sum + r.flaggedDays);

  void setActiveTab(String val) {
    _activeTab = val;
    _isFilterApplied = false;
    _attendanceRows = [];
    _cachedFilteredRows = [];
    _cachedSummarizedRows = [];
    _employeewiseRows = [];
    _filteredEmployeewiseRows = [];
    _monthlyRows = [];
    _currentRun = null;
    _salaryLines = [];
    _currentSlip = null;
    _safeNotify();
    fetchReport();
  }

  void setDateFrom(String val) {
    _dateFrom = val;
    _safeNotify();
  }

  void setDateTo(String val) {
    _dateTo = val;
    _safeNotify();
  }

  void setSelectedDepartment(String val) {
    _selectedDepartment = val;
    _selectedEmployee = ''; // Clear employee when dept changes
    _safeNotify();
  }

  void setSelectedEmployee(String val) {
    _selectedEmployee = val;
    _safeNotify();
  }

  void setSelectedShift(String val) {
    _selectedShift = val;
    _safeNotify();
  }

  void setSelectedYear(int val) {
    _selectedYear = val;
    _safeNotify();
  }

  void setSelectedMonth(int val) {
    _selectedMonth = val;
    _safeNotify();
  }

  void setSearchQuery(String val) {
    _searchQuery = val;
    _applyFilters();
    _applyEmployeewiseSearch();
    _safeNotify();
  }

  void setDateSortOrder(String val) {
    _dateSortOrder = val;
    _applyFilters();
    _safeNotify();
  }

  void setSummarized(bool val) {
    _summarized = val;
    _safeNotify();
  }

  void clearFilters() {
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _dateFrom = today;
    _dateTo = today;
    _selectedDepartment = '';
    _selectedEmployee = '';
    _selectedShift = '';
    _searchQuery = '';
    _dateSortOrder = 'desc';
    _summarized = false;
    _isFilterApplied = false;
    _attendanceRows = [];
    _cachedFilteredRows = [];
    _cachedSummarizedRows = [];
    _filteredEmployeewiseRows = [];
    _safeNotify();
    fetchReport();
  }

  bool _isDisposed = false;
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
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
    _safeNotify();

    try {
      if (_activeTab == 'register') {
        final raw = await _apiService.fetchPayrollAttendanceData(
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          employeeId: _selectedEmployee.isNotEmpty ? _selectedEmployee : null,
          shiftId: _selectedShift.isNotEmpty ? _selectedShift : null,
        );
        _attendanceRows = raw.map((e) => PayrollAttendanceRow.fromJson(e as Map<String, dynamic>)).toList();
      } else if (_activeTab == 'employeewise') {
        final raw = await _apiService.fetchPayrollSummary(dateFrom: _dateFrom, dateTo: _dateTo);
        _employeewiseRows = raw.map((e) => EmployeewiseAttendanceRow.fromJson(e as Map<String, dynamic>)).toList();
        _applyEmployeewiseSearch();
      } else if (_activeTab == 'monthly') {
        final from = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-01';
        final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
        final to = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
        final raw = await _apiService.fetchPayrollAttendanceData(dateFrom: from, dateTo: to);
        _monthlyRows = _buildMonthlyRows(raw);
      } else if (_activeTab == 'salary-sheet') {
        await fetchRuns();
        final run = _runs.firstWhere(
          (r) => r.periodYear.toString() == _selectedYear.toString() && r.periodMonth.toString() == _selectedMonth.toString(),
          orElse: () => PayrollRun(id: null, periodYear: 0, periodMonth: 0, status: ''),
        );
        if (run.id != null) {
          await fetchPayrollRun(run.id);
        } else {
          _currentRun = null;
          _salaryLines = [];
        }
      } else if (_activeTab == 'salary-slip') {
        if (_runs.isEmpty) await fetchRuns();
      }

      _isFilterApplied = true;
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to load payroll report: $e';
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> fetchRuns() async {
    try {
      final raw = await _apiService.fetchPayrollRuns();
      _runs = raw.map((e) => PayrollRun.fromJson(e as Map<String, dynamic>)).toList();
      _safeNotify();
    } catch (_) {}
  }

  Future<void> fetchPayrollRun(dynamic id) async {
    _isLoading = true;
    _currentSlip = null;
    _safeNotify();
    try {
      final data = await _apiService.fetchPayrollRun(id);
      if (data != null && data['data'] != null) {
        final runData = data['data']['run'];
        final linesData = data['data']['lines'] as List?;
        _currentRun = PayrollRun.fromJson(runData);
        if (linesData != null) {
          _salaryLines = linesData.map((e) => SalarySheetLine.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {} finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> generatePayroll() async {
    _isLoading = true;
    _safeNotify();
    try {
      final res = await _apiService.createPayrollRun(_selectedYear, _selectedMonth);
      if (res != null && res['success'] == true) {
        await fetchReport();
      } else {
        _errorMessage = res?['message'] ?? 'Could not generate payroll.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> finalizePayroll(dynamic id) async {
    _isLoading = true;
    _safeNotify();
    try {
      final success = await _apiService.finalizePayrollRun(id);
      if (success) await fetchReport();
    } catch (_) {} finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> deletePayroll(dynamic id) async {
    _isLoading = true;
    _safeNotify();
    try {
      final success = await _apiService.deletePayrollRun(id);
      if (success) await fetchReport();
    } catch (_) {} finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> fetchSlip(dynamic runId, dynamic employeeSrlNo) async {
    _isLoading = true;
    _currentSlip = null;
    _safeNotify();
    try {
      final data = await _apiService.fetchSalarySlip(runId, employeeSrlNo);
      if (data != null && data['data'] != null) {
        _currentSlip = data['data'] as Map<String, dynamic>;
      }
    } catch (_) {} finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void _applyFilters() {
    var result = List<PayrollAttendanceRow>.from(_attendanceRows);

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

  void _applyEmployeewiseSearch() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredEmployeewiseRows = query.isEmpty
        ? List<EmployeewiseAttendanceRow>.from(_employeewiseRows)
        : _employeewiseRows.where((row) => [
            row.employeeName,
            row.empId,
            row.departmentName,
            row.employeeMachineCode,
          ].any((value) => value.toLowerCase().contains(query))).toList();
  }

  List<MonthlyAttendanceEmployee> _buildMonthlyRows(List<dynamic> raw) {
    final grouped = <int, Map<String, dynamic>>{};
    const statusCodes = {
      'Present': 'P', 'Absent': 'A', 'Half Day': 'H',
      'Leave': 'L', 'Holiday': '*', 'Weekly Off': 'O',
    };
    for (final item in raw) {
      final row = item as Map<String, dynamic>;
      final employeeId = int.tryParse((row['employee_srl_no'] ?? 0).toString()) ?? 0;
      final date = (row['date'] ?? row['attendance_date'] ?? '').toString();
      final day = int.tryParse(date.length >= 10 ? date.substring(8, 10) : '') ?? 0;
      if (employeeId == 0 || day == 0) continue;
      final entry = grouped.putIfAbsent(employeeId, () => {
        'empId': (row['emp_id'] ?? '-').toString(),
        'name': (row['employee_name'] ?? '-').toString(),
        'department': (row['department_name'] ?? '-').toString(),
        'days': <int, String>{},
        'present': 0.0,
        'absent': 0,
      });
      final code = statusCodes[row['status']?.toString()] ?? '-';
      (entry['days'] as Map<int, String>)[day] = code;
      if (code == 'P') entry['present'] = (entry['present'] as double) + 1;
      if (code == 'H') entry['present'] = (entry['present'] as double) + 0.5;
      if (code == 'A') entry['absent'] = (entry['absent'] as int) + 1;
    }
    final result = grouped.entries.map((entry) => MonthlyAttendanceEmployee(
      employeeSrlNo: entry.key,
      empId: entry.value['empId'] as String,
      employeeName: entry.value['name'] as String,
      departmentName: entry.value['department'] as String,
      days: entry.value['days'] as Map<int, String>,
      present: entry.value['present'] as double,
      absent: entry.value['absent'] as int,
    )).toList();
    result.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return result;
  }
}
