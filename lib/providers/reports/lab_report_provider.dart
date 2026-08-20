import 'package:flutter/material.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/lab_report_model.dart';

class LabReportProvider extends ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isDisposed = false;
  bool _loading = false;
  String? _errorMessage;

  List<LabReportItem> _tests = [];

  // Filters
  String _searchQuery = '';
  String _dateFrom = '';
  String _dateTo = '';
  String _selectedShift = 'All';
  bool _summarized = false;

  LabReportProvider() {
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _dateFrom = today;
    _dateTo = today;
  }

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  String get dateFrom => _dateFrom;
  String get dateTo => _dateTo;
  String get selectedShift => _selectedShift;
  bool get summarized => _summarized;

  bool get hasActiveFilters {
    final now = DateTime.now();
    final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    return _searchQuery.trim().isNotEmpty ||
           _selectedShift != 'All' ||
           _dateFrom != today ||
           _dateTo != today;
  }

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
      final data = await _apiService.fetchLabReport(
        search: _searchQuery,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        shift: _selectedShift,
      );

      _tests = data.whereType<Map<String, dynamic>>().map((json) => LabReportItem.fromJson(json)).toList();
    } catch (e) {
      _errorMessage = 'Failed to load lab report: $e';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  List<LabReportItem> get filteredTests {
    List<LabReportItem> result = List.from(_tests);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((item) {
        return item.testName.toLowerCase().contains(q) ||
            item.mrNumber.toLowerCase().contains(q) ||
            item.patientName.toLowerCase().contains(q) ||
            item.opdService.toLowerCase().contains(q) ||
            item.serviceDetail.toLowerCase().contains(q) ||
            item.shiftType.toLowerCase().contains(q) ||
            item.testAmount.toString().contains(q);
      }).toList();
    }

    if (_selectedShift.isNotEmpty && _selectedShift != 'All') {
      result = result.where((item) => item.shiftType.toLowerCase() == _selectedShift.toLowerCase()).toList();
    }

    if (_dateFrom.isNotEmpty) {
      result = result.where((item) => item.testDate.compareTo(_dateFrom) >= 0).toList();
    }
    if (_dateTo.isNotEmpty) {
      result = result.where((item) => item.testDate.compareTo(_dateTo) <= 0).toList();
    }

    if (_summarized) {
      final Map<String, LabReportItem> map = {};
      for (final item in result) {
        final label = item.serviceDetail.trim().isEmpty || item.serviceDetail == '—' 
            ? item.testName 
            : item.serviceDetail;
        
        final name = label.isEmpty ? 'Unknown' : label;
        
        if (!map.containsKey(name)) {
          map[name] = LabReportItem(
            id: item.id,
            receiptSrl: name,
            testName: item.testName,
            testAmount: item.testAmount,
            companyShare: item.companyShare,
            testDate: '—',
            testTime: '—',
            shiftType: '—',
            testCount: 1,
            mrNumber: '—',
            patientName: '—',
            opdService: item.opdService,
            serviceDetail: name,
          );
        } else {
          final existing = map[name]!;
          map[name] = LabReportItem(
            id: existing.id,
            receiptSrl: name,
            testName: existing.testName,
            testAmount: existing.testAmount + item.testAmount,
            companyShare: existing.companyShare + item.companyShare,
            testDate: '—',
            testTime: '—',
            shiftType: '—',
            testCount: existing.testCount + 1,
            mrNumber: '—',
            patientName: '—',
            opdService: existing.opdService,
            serviceDetail: existing.serviceDetail,
          );
        }
      }
      return map.values.toList();
    }

    return result;
  }

  double get totalTestAmount => filteredTests.fold(0.0, (sum, item) => sum + item.testAmount);
  double get totalCompanyShare => filteredTests.fold(0.0, (sum, item) => sum + item.companyShare);
  int get totalTestCount => filteredTests.fold(0, (sum, item) => sum + item.testCount);
}
