import 'package:flutter/material.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/yearly_report_model.dart';

class YearlyReportProvider extends ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isDisposed = false;
  bool _loading = false;
  String? _errorMessage;

  String _selectedYear = DateTime.now().year.toString();
  String _selectedShift = 'All'; // 'All', 'Morning', 'Evening', 'Night'
  String _selectedCategory = 'All'; // 'All', 'OPD', 'Expenses'
  String _searchQuery = '';
  String _activeTab = 'matrix'; // 'matrix', 'graphical', 'consultation'

  List<YearlyBreakdownRawItem> _opdBreakdown = [];
  List<YearlyBreakdownRawItem> _expensesBreakdown = [];
  List<YearlyBreakdownRawItem> _consultationBreakdown = [];
  List<YearlyBreakdownRawItem> _consultationShareBreakdown = [];

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;

  String get selectedYear => _selectedYear;
  String get selectedShift => _selectedShift;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String get activeTab => _activeTab;

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
    loadYearlyReport();
  }

  void setSelectedShift(String shift) {
    _selectedShift = shift;
    _safeNotify();
  }

  void setSelectedCategory(String cat) {
    _selectedCategory = cat;
    _safeNotify();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    _safeNotify();
  }

  void setActiveTab(String tab) {
    _activeTab = tab;
    _safeNotify();
  }

  Future<void> loadYearlyReport() async {
    _loading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final data = await _apiService.fetchYearlyBreakdown(_selectedYear);
      if (data != null) {
        _opdBreakdown = _parseRawList(data['opdBreakdown']);
        _expensesBreakdown = _parseRawList(data['expensesBreakdown']);
        _consultationBreakdown = _parseRawList(data['consultationBreakdown']);
        _consultationShareBreakdown = _parseRawList(data['consultationShareBreakdown']);
      } else {
        _opdBreakdown = [];
        _expensesBreakdown = [];
        _consultationBreakdown = [];
        _consultationShareBreakdown = [];
      }
    } catch (e) {
      _errorMessage = 'Failed to load yearly report: $e';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  List<YearlyBreakdownRawItem> _parseRawList(dynamic list) {
    if (list is! List) return [];
    return list.whereType<Map<String, dynamic>>().map((j) => YearlyBreakdownRawItem.fromJson(j)).toList();
  }

  // Pivot matrix processing (matches React processMatrix)
  Map<String, dynamic> processMatrix(List<YearlyBreakdownRawItem> data, String nameType) {
    final filtered = data.where((d) {
      if (_selectedShift != 'All' && d.shift != null && d.shift != _selectedShift) {
        return false;
      }
      final name = nameType == 'doctor'
          ? (d.doctorName ?? '')
          : nameType == 'head'
              ? (d.head ?? '')
              : (d.service ?? '');
      if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final Map<String, List<double>> pivoted = {};
    final Map<String, double> totalsMap = {};
    final List<double> monthlyTotals = List.filled(12, 0.0);
    double grandTotal = 0.0;

    for (final row in filtered) {
      final name = (nameType == 'doctor'
              ? row.doctorName
              : nameType == 'head'
                  ? row.head
                  : row.service) ??
          'Other';
      final mIdx = (row.month - 1).clamp(0, 11);
      final amt = row.amount;

      if (!pivoted.containsKey(name)) {
        pivoted[name] = List.filled(12, 0.0);
        totalsMap[name] = 0.0;
      }
      pivoted[name]![mIdx] += amt;
      totalsMap[name] = totalsMap[name]! + amt;
      monthlyTotals[mIdx] += amt;
      grandTotal += amt;
    }

    final List<YearlyRowData> rows = pivoted.keys.map((name) {
      return YearlyRowData(
        key: name,
        title: name,
        months: pivoted[name]!,
        total: totalsMap[name]!,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return {
      'rows': rows,
      'monthlyTotals': monthlyTotals,
      'grandTotal': grandTotal,
    };
  }

  Map<String, dynamic> get opdMatrix => processMatrix(_opdBreakdown, 'service');
  Map<String, dynamic> get expensesMatrix => processMatrix(_expensesBreakdown, 'head');
  Map<String, dynamic> get consultationMatrix {
    final list = _selectedCategory == 'Expenses' ? _consultationShareBreakdown : _consultationBreakdown;
    return processMatrix(list, 'doctor');
  }
}
