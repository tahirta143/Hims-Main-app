import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../core/services/reports_api_service.dart';
import '../../models/reports/accounts_report_model.dart';

class AccountsReportProvider with ChangeNotifier {
  final ReportsApiService _apiService = ReportsApiService();
  bool _isLoading = false;
  String? _errorMessage;
  String _dateFrom = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _dateTo = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<AccountsRevenueGroup> _revenueRows = [];
  List<AccountsReceipt> _cancelledRows = [];
  List<AccountsExpense> _expenses = [];
  int _revenueCount = 0;
  double _revenueTotal = 0;
  double _doctorShare = 0;
  double _hospitalShare = 0;
  double _cancelledTotal = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get dateFrom => _dateFrom;
  String get dateTo => _dateTo;
  List<AccountsRevenueGroup> get revenueRows => _revenueRows;
  List<AccountsReceipt> get cancelledRows => _cancelledRows;
  List<AccountsExpense> get expenses => _expenses;
  int get revenueCount => _revenueCount;
  double get revenueTotal => _revenueTotal;
  double get doctorShare => _doctorShare;
  double get hospitalShare => _hospitalShare;
  double get cancelledTotal => _cancelledTotal;
  double get expenseTotal => _expenses.fold(0, (sum, item) => sum + item.amount);
  String get rangeLabel => _dateFrom == _dateTo ? _dateFrom : '$_dateFrom - $_dateTo';

  void setDateFrom(String value) {
    _dateFrom = value;
    _dateTo = value;
    notifyListeners();
    fetchReport();
  }

  void setDateTo(String value) {
    _dateTo = value;
    notifyListeners();
    fetchReport();
  }

  Future<void> fetchReport() async {
    if (_dateFrom.isEmpty || _dateTo.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _apiService.fetchOpdPatientData(_dateFrom, _dateTo),
        _apiService.fetchAccountsExpenses(_dateFrom, _dateTo),
      ]);
      final receipts = results[0].whereType<Map<String, dynamic>>().map(AccountsReceipt.fromJson).toList();
      _expenses = results[1].whereType<Map<String, dynamic>>().map(AccountsExpense.fromJson).toList();
      _buildTotals(receipts);
    } catch (error) {
      _errorMessage = 'Failed to load day book. Please try again.';
      _revenueRows = [];
      _cancelledRows = [];
      _expenses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _buildTotals(List<AccountsReceipt> receipts) {
    final groups = <String, _MutableRevenue>{};
    final cancelled = <AccountsReceipt>[];
    var count = 0;
    var total = 0.0;
    var doctor = 0.0;
    var hospital = 0.0;
    for (final receipt in receipts) {
      if (receipt.cancelled) {
        cancelled.add(receipt);
        continue;
      }
      final key = '${receipt.type}::${receipt.label}';
      final entry = groups.putIfAbsent(key, () => _MutableRevenue(receipt.type, receipt.label));
      entry.count++;
      entry.total += receipt.amount;
      entry.doctorShare += receipt.doctorShare;
      entry.hospitalShare += receipt.hospitalShare;
      count++;
      total += receipt.amount;
      doctor += receipt.doctorShare;
      hospital += receipt.hospitalShare;
    }
    final rows = groups.entries.map((entry) => AccountsRevenueGroup(
      key: entry.key,
      type: entry.value.type,
      label: entry.value.label,
      count: entry.value.count,
      total: entry.value.total,
      doctorShare: entry.value.doctorShare,
      hospitalShare: entry.value.hospitalShare,
    )).toList()..sort((a, b) => a.type == b.type ? a.label.compareTo(b.label) : a.type.compareTo(b.type));
    _revenueRows = rows;
    _cancelledRows = cancelled;
    _revenueCount = count;
    _revenueTotal = total;
    _doctorShare = doctor;
    _hospitalShare = hospital;
    _cancelledTotal = cancelled.fold(0, (sum, item) => sum + item.amount);
  }
}

class _MutableRevenue {
  final String type;
  final String label;
  int count = 0;
  double total = 0;
  double doctorShare = 0;
  double hospitalShare = 0;
  _MutableRevenue(this.type, this.label);
}
