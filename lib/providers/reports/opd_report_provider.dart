import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/opd_report_model.dart';

class OpdReportProvider with ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();

  bool _isLoading = false;
  String? _errorMessage;

  String _dateFrom = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _dateTo = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _searchQuery = '';
  String _selectedShift = 'All';
  String _activeTab = 'opd'; // 'opd', 'consultation', 'dental', 'emergency'
  String _dateSortOrder = 'desc'; // 'asc' or 'desc'
  bool _summarized = false;

  List<OpdReportRow> _allOpdRows = [];
  List<OpdReportRow> _allEmergencyRows = [];

  List<OpdReportRow> _cachedOpdRows = [];
  List<OpdReportRow> _cachedConsultationRows = [];
  List<OpdReportRow> _cachedEmergencyRows = [];
  List<OpdReportSummaryRow> _cachedSummarizedRows = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get dateFrom => _dateFrom;
  String get dateTo => _dateTo;
  String get searchQuery => _searchQuery;
  String get selectedShift => _selectedShift;
  String get activeTab => _activeTab;
  String get dateSortOrder => _dateSortOrder;
  bool get summarized => _summarized;

  void setDateFrom(String val) {
    _dateFrom = val;
    notifyListeners();
  }

  void setDateTo(String val) {
    _dateTo = val;
    notifyListeners();
  }

  void setSearchQuery(String val) {
    _searchQuery = val;
    _applyFilters();
    notifyListeners();
  }

  void setSelectedShift(String val) {
    _selectedShift = val;
    _applyFilters();
    notifyListeners();
  }

  void setActiveTab(String val) {
    _activeTab = val;
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
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dateFrom = today;
    _dateTo = today;
    _searchQuery = '';
    _selectedShift = 'All';
    _activeTab = 'opd';
    _dateSortOrder = 'desc';
    _summarized = false;
    fetchReport();
  }

  Future<void> fetchReport() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.fetchOpdPatientData(_dateFrom, _dateTo),
        _apiService.fetchEmergencyBillsData(_dateFrom, _dateTo),
      ]);

      final opdRaw = results[0];
      final emergencyRaw = results[1];

      _allOpdRows = opdRaw.map((e) => OpdReportRow.fromJson(e as Map<String, dynamic>, type: 'opd')).toList();
      _allEmergencyRows = emergencyRaw.map((e) => OpdReportRow.fromJson(e as Map<String, dynamic>, type: 'emergency')).toList();
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to load OPD report: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<OpdReportRow> _filterAndSort(List<OpdReportRow> rows) {
    var result = List<OpdReportRow>.from(rows);

    if (_selectedShift != 'All') {
      result = result.where((r) => r.shiftType.toLowerCase() == _selectedShift.toLowerCase()).toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((r) {
        return r.mrNumber.toLowerCase().contains(query) ||
            r.patientName.toLowerCase().contains(query) ||
            r.serviceName.toLowerCase().contains(query) ||
            r.serviceDetail.toLowerCase().contains(query) ||
            r.doctorName.toLowerCase().contains(query) ||
            r.shiftType.toLowerCase().contains(query) ||
            r.status.toLowerCase().contains(query);
      }).toList();
    }

    result.sort((a, b) {
      final da = a.parsedDate ?? DateTime(1970);
      final db = b.parsedDate ?? DateTime(1970);
      final cmp = _dateSortOrder == 'asc' ? da.compareTo(db) : db.compareTo(da);
      if (cmp != 0) return cmp;
      return a.time.compareTo(b.time);
    });

    return result;
  }

  void _applyFilters() {
    final opdFiltered = _allOpdRows.where((r) => r.serviceName.toLowerCase() != 'consultation').toList();
    _cachedOpdRows = _filterAndSort(opdFiltered);

    final consultFiltered = _allOpdRows.where((r) => r.serviceName.toLowerCase() == 'consultation').toList();
    _cachedConsultationRows = _filterAndSort(consultFiltered);

    _cachedEmergencyRows = _filterAndSort(_allEmergencyRows);

    if (_activeTab == 'dental') {
      _cachedSummarizedRows = [];
      return;
    }

    final map = <String, OpdReportSummaryRow>{};
    final rows = activeTabRows;

    for (final r in rows) {
      String key;
      if (_activeTab == 'consultation') {
        key = r.serviceDetail.isNotEmpty && r.serviceDetail != '-'
            ? r.serviceDetail
            : (r.doctorName.isNotEmpty ? r.doctorName : 'Unknown Detail');
      } else if (_activeTab == 'emergency') {
        key = r.serviceName.isNotEmpty && r.serviceName != '-' ? r.serviceName : 'Emergency';
      } else {
        key = r.serviceName.isNotEmpty && r.serviceName != '-' ? r.serviceName : 'Unknown Service';
      }

      if (!map.containsKey(key)) {
        map[key] = OpdReportSummaryRow(
          srlNo: 0,
          label: key,
          combinedRecords: 0,
          amountTotal: 0.0,
        );
      }

      final existing = map[key]!;
      map[key] = OpdReportSummaryRow(
        srlNo: 0,
        label: existing.label,
        combinedRecords: existing.combinedRecords + 1,
        amountTotal: existing.amountTotal + r.amount,
      );
    }

    final list = map.values.toList();
    list.sort((a, b) => a.label.compareTo(b.label));

    _cachedSummarizedRows = List.generate(list.length, (index) {
      final item = list[index];
      return OpdReportSummaryRow(
        srlNo: index + 1,
        label: item.label,
        combinedRecords: item.combinedRecords,
        amountTotal: item.amountTotal,
      );
    });
  }

  List<OpdReportRow> get opdTabRows => _cachedOpdRows;
  List<OpdReportRow> get consultationTabRows => _cachedConsultationRows;
  List<OpdReportRow> get emergencyTabRows => _cachedEmergencyRows;

  List<OpdReportRow> get activeTabRows {
    if (_activeTab == 'consultation') return _cachedConsultationRows;
    if (_activeTab == 'emergency') return _cachedEmergencyRows;
    if (_activeTab == 'dental') return [];
    return _cachedOpdRows;
  }

  List<OpdReportSummaryRow> get summarizedRows => _cachedSummarizedRows;

  int get totalOpdCount => _cachedOpdRows.length;
  int get totalConsultationCount => _cachedConsultationRows.length;
  int get totalEmergencyCount => _cachedEmergencyRows.length;
  double get activeTotalAmount => activeTabRows.fold(0.0, (sum, item) => sum + item.amount);
}
