import 'package:flutter/material.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/shares_report_model.dart';

class SharesReportProvider extends ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isDisposed = false;
  bool _loading = false;
  String? _errorMessage;

  List<SharesReportRow> _rows = [];
  SharesReportTotals? _totals;

  // Filters
  String _personType = 'all'; // 'all', 'doctor', 'employee'
  String _serviceType = 'all'; // 'all', 'opd', 'indoor'
  String _searchQuery = '';
  String _department = '';

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  List<SharesReportRow> get rows => _rows;
  SharesReportTotals? get totals => _totals;

  String get personType => _personType;
  String get serviceType => _serviceType;
  String get searchQuery => _searchQuery;
  String get department => _department;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void setPersonType(String val) {
    _personType = val;
    _safeNotify();
  }

  void setServiceType(String val) {
    _serviceType = val;
    _safeNotify();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    _safeNotify();
  }

  void setDepartment(String dep) {
    _department = dep;
    _safeNotify();
  }

  void resetFilters() {
    _personType = 'all';
    _serviceType = 'all';
    _searchQuery = '';
    _department = '';
    fetchReport();
  }

  List<String> get availableDepartments {
    final set = _rows.map((r) => r.department).where((d) => d.isNotEmpty).toSet();
    final list = set.toList()..sort();
    return list;
  }

  List<SharesReportRow> get filteredRows {
    List<SharesReportRow> result = List.from(_rows);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((r) {
        return r.personName.toLowerCase().contains(q) ||
            r.personCode.toLowerCase().contains(q) ||
            r.serviceName.toLowerCase().contains(q) ||
            r.department.toLowerCase().contains(q);
      }).toList();
    }

    if (_personType != 'all') {
      result = result.where((r) => r.personType.toLowerCase() == _personType.toLowerCase()).toList();
    }

    if (_serviceType != 'all') {
      result = result.where((r) => r.serviceType.toLowerCase() == _serviceType.toLowerCase()).toList();
    }

    if (_department.isNotEmpty) {
      result = result.where((r) => r.department.toLowerCase() == _department.toLowerCase()).toList();
    }

    return result;
  }

  Future<void> fetchReport() async {
    _loading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final data = await _apiService.fetchSharesReport(
        personType: _personType,
        serviceType: _serviceType,
        q: _searchQuery,
        department: _department,
      );

      if (data != null) {
        final rawRows = (data['rows'] as List<dynamic>?) ?? [];
        _rows = rawRows.whereType<Map<String, dynamic>>().map((json) => SharesReportRow.fromJson(json)).toList();
        if (data['totals'] != null) {
          _totals = SharesReportTotals.fromJson(data['totals'] as Map<String, dynamic>);
        }
      } else {
        _rows = [];
        _totals = null;
      }
    } catch (e) {
      _errorMessage = 'Failed to load shares report: $e';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }
}
