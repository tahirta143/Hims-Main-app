import 'package:flutter/material.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/monthly_report_model.dart';

class MonthlyReportProvider extends ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isDisposed = false;
  bool _loading = false;
  String? _errorMessage;

  String _selectedYear = DateTime.now().year.toString();
  String _selectedMonth = DateTime.now().month.toString();
  String _viewMode = 'summary'; // 'summary', 'detailed', 'calendar', 'overview'
  String _searchQuery = '';

  List<MonthlyDaySummary> _dailySummary = [];
  List<MonthlyParticularItem> _opdParticulars = [];
  List<MonthlyParticularItem> _expenseParticulars = [];
  Map<String, Map<int, double>> _opdCalendar = {};
  Map<String, Map<int, double>> _expensesCalendar = {};

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;

  String get selectedYear => _selectedYear;
  String get selectedMonth => _selectedMonth;
  String get viewMode => _viewMode;
  String get searchQuery => _searchQuery;

  List<MonthlyDaySummary> get dailySummary => _dailySummary;
  List<MonthlyParticularItem> get opdParticulars => _opdParticulars;
  List<MonthlyParticularItem> get expenseParticulars => _expenseParticulars;
  Map<String, Map<int, double>> get opdCalendar => _opdCalendar;
  Map<String, Map<int, double>> get expensesCalendar => _expensesCalendar;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void setSelectedYear(String year) {
    _selectedYear = year;
    loadMonthlyData();
  }

  void setSelectedMonth(String month) {
    _selectedMonth = month;
    loadMonthlyData();
  }

  void setViewMode(String mode) {
    _viewMode = mode;
    _safeNotify();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    _safeNotify();
  }

  Future<void> loadMonthlyData() async {
    _loading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final results = await Future.wait([
        _apiService.fetchMonthlySummary(_selectedYear, _selectedMonth),
        _apiService.fetchMonthlyDetailed(_selectedYear, _selectedMonth),
        _apiService.fetchMonthlyCalendar(_selectedYear, _selectedMonth),
      ]);

      // 1. Summary
      final sumList = (results[0] as List<dynamic>?) ?? [];
      _dailySummary = sumList.whereType<Map<String, dynamic>>().map((j) => MonthlyDaySummary.fromJson(j)).toList();

      // 2. Detailed
      final detMap = results[1] as Map<String, dynamic>?;
      if (detMap != null) {
        final opdList = (detMap['opdParticulars'] as List<dynamic>?) ?? [];
        final expList = (detMap['expenseParticulars'] as List<dynamic>?) ?? [];
        _opdParticulars = opdList.whereType<Map<String, dynamic>>().map((j) => MonthlyParticularItem.fromJson(j)).toList();
        _expenseParticulars = expList.whereType<Map<String, dynamic>>().map((j) => MonthlyParticularItem.fromJson(j)).toList();
      } else {
        _opdParticulars = [];
        _expenseParticulars = [];
      }

      // 3. Calendar
      final calMap = results[2] as Map<String, dynamic>?;
      if (calMap != null) {
        _opdCalendar = _parseCalendarMap(calMap['opdCalendar']);
        _expensesCalendar = _parseCalendarMap(calMap['expensesCalendar']);
      } else {
        _opdCalendar = {};
        _expensesCalendar = {};
      }
    } catch (e) {
      _errorMessage = 'Failed to load monthly report: $e';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Map<String, Map<int, double>> _parseCalendarMap(dynamic jsonMap) {
    if (jsonMap is! Map) return {};
    final Map<String, Map<int, double>> result = {};
    jsonMap.forEach((serviceKey, daysVal) {
      if (daysVal is Map) {
        final Map<int, double> dayMap = {};
        daysVal.forEach((dayKey, amt) {
          final dayInt = int.tryParse(dayKey.toString());
          final amountDouble = double.tryParse(amt.toString());
          if (dayInt != null && amountDouble != null) {
            dayMap[dayInt] = amountDouble;
          }
        });
        result[serviceKey.toString()] = dayMap;
      }
    });
    return result;
  }

  // Summary Totals
  double get totalOpdRevenue {
    return _dailySummary.fold(0.0, (sum, day) {
      return sum + day.morning.opdTotal + day.evening.opdTotal + day.night.opdTotal;
    });
  }

  double get totalExpenses {
    return _dailySummary.fold(0.0, (sum, day) {
      return sum + day.morning.expensesTotal + day.evening.expensesTotal + day.night.expensesTotal;
    });
  }

  double get netRevenue => totalOpdRevenue - totalExpenses;
}
