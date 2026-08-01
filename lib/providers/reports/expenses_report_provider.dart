import 'package:flutter/material.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/expenses_report_model.dart';

class ExpensesReportProvider extends ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isDisposed = false;
  bool _loading = false;
  String? _errorMessage;

  List<ExpenseReportItem> _expenses = [];

  // Filter state
  String _searchQuery = '';
  String _dateFrom = '';
  String _dateTo = '';
  String _selectedShift = '';
  bool _summarized = false;
  String _dateSortOrder = 'desc'; // 'asc' or 'desc'

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  List<ExpenseReportItem> get rawExpenses => _expenses;

  String get searchQuery => _searchQuery;
  String get dateFrom => _dateFrom;
  String get dateTo => _dateTo;
  String get selectedShift => _selectedShift;
  bool get summarized => _summarized;
  String get dateSortOrder => _dateSortOrder;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _dateFrom.isNotEmpty ||
      _dateTo.isNotEmpty ||
      _selectedShift.isNotEmpty;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    _safeNotify();
  }

  void setDateFrom(String df) {
    _dateFrom = df;
    _safeNotify();
  }

  void setDateTo(String dt) {
    _dateTo = dt;
    _safeNotify();
  }

  void setSelectedShift(String s) {
    _selectedShift = s;
    _safeNotify();
  }

  void setSummarized(bool val) {
    _summarized = val;
    _safeNotify();
  }

  void toggleDateSortOrder() {
    _dateSortOrder = _dateSortOrder == 'asc' ? 'desc' : 'asc';
    _safeNotify();
  }

  void resetFilters() {
    _searchQuery = '';
    _dateFrom = '';
    _dateTo = '';
    _selectedShift = '';
    _summarized = false;
    fetchReport();
  }

  Future<void> fetchReport() async {
    _loading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final data = await _apiService.fetchExpensesReport(
        search: _searchQuery,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        shift: _selectedShift,
      );

      _expenses = data.whereType<Map<String, dynamic>>().map((json) => ExpenseReportItem.fromJson(json)).toList();
    } catch (e) {
      _errorMessage = 'Failed to load expenses report: $e';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  // Filtered & Summarized computed items (matches React useMemo logic)
  List<ExpenseReportItem> get filteredExpenses {
    List<ExpenseReportItem> result = List.from(_expenses);

    // Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((item) {
        return item.expenseName.toLowerCase().contains(q) ||
            item.expenseDescription.toLowerCase().contains(q) ||
            item.expenseShift.toLowerCase().contains(q) ||
            item.expenseAmount.toString().contains(q) ||
            item.expenseBy.toLowerCase().contains(q);
      }).toList();
    }

    // Shift filter
    if (_selectedShift.isNotEmpty) {
      result = result.where((item) => item.expenseShift.toLowerCase() == _selectedShift.toLowerCase()).toList();
    }

    // Date From & To filters
    if (_dateFrom.isNotEmpty) {
      result = result.where((item) => item.expenseDate.compareTo(_dateFrom) >= 0).toList();
    }
    if (_dateTo.isNotEmpty) {
      result = result.where((item) => item.expenseDate.compareTo(_dateTo) <= 0).toList();
    }

    // Sorting
    if (_searchQuery.trim().isNotEmpty) {
      result.sort((a, b) => a.expenseName.toLowerCase().compareTo(b.expenseName.toLowerCase()));
    } else {
      result.sort((a, b) {
        final cmp = a.expenseDate.compareTo(b.expenseDate);
        if (cmp == 0) {
          return a.expenseTime.compareTo(b.expenseTime);
        }
        return _dateSortOrder == 'asc' ? cmp : -cmp;
      });
    }

    // Summarize mode
    if (_summarized) {
      final Map<String, ExpenseReportItem> map = {};
      for (final item in result) {
        final name = item.expenseName.isEmpty ? 'Unknown' : item.expenseName;
        if (!map.containsKey(name)) {
          map[name] = ExpenseReportItem(
            id: item.id,
            expenseName: name,
            expenseDescription: '—',
            expenseAmount: item.expenseAmount,
            expenseDate: '—',
            expenseTime: '—',
            expenseShift: '—',
            expenseBy: '—',
            expenseCount: 1,
          );
        } else {
          final existing = map[name]!;
          map[name] = ExpenseReportItem(
            id: existing.id,
            expenseName: existing.expenseName,
            expenseDescription: '—',
            expenseAmount: existing.expenseAmount + item.expenseAmount,
            expenseDate: '—',
            expenseTime: '—',
            expenseShift: '—',
            expenseBy: '—',
            expenseCount: existing.expenseCount + 1,
          );
        }
      }
      return map.values.toList();
    }

    return result;
  }

  double get totalExpenseAmount {
    return filteredExpenses.fold(0.0, (sum, item) => sum + item.expenseAmount);
  }

  int get totalExpenseCount {
    return filteredExpenses.fold(0, (sum, item) => sum + item.expenseCount);
  }
}
