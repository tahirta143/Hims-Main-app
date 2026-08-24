import 'package:flutter/material.dart';
import '../../core/services/task_management/task_api_service.dart';
import '../../models/task_management/task_report_model.dart';

class TaskReportProvider with ChangeNotifier {
  final TaskApiService _api = TaskApiService();

  OverviewReport? _overview;
  List<UserPerformanceReport> _performance = [];
  List<DepartmentSummaryReport> _departments = [];
  bool _loading = false;
  String? _error;

  OverviewReport? get overview => _overview;
  List<UserPerformanceReport> get performance => _performance;
  List<DepartmentSummaryReport> get departments => _departments;
  bool get loading => _loading;
  String? get error => _error;

  // AI Insights
  String _aiInsights = '';
  bool _aiLoading = false;
  String get aiInsights => _aiInsights;
  bool get aiLoading => _aiLoading;

  // AI Chat
  final List<Map<String, String>> _aiHistory = [];
  bool _aiAsking = false;
  List<Map<String, String>> get aiHistory => _aiHistory;
  bool get aiAsking => _aiAsking;

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.fetchOverviewReport(),
        _api.fetchUserPerformance(),
        _api.fetchDepartmentSummary(),
      ]);

      final ovRes = results[0] as TaskApiResponse<OverviewReport>;
      final perfRes = results[1] as TaskApiResponse<List<UserPerformanceReport>>;
      final deptRes = results[2] as TaskApiResponse<List<DepartmentSummaryReport>>;

      if (ovRes.success) {
        _overview = ovRes.data;
      }
      if (perfRes.success) {
        _performance = perfRes.data ?? [];
      }
      if (deptRes.success) {
        _departments = deptRes.data ?? [];
      }

      if (!ovRes.success || !perfRes.success || !deptRes.success) {
        _error = ovRes.message ?? perfRes.message ?? deptRes.message ?? 'Could not load reports';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> generateAiInsights() async {
    _aiLoading = true;
    notifyListeners();

    final res = await _api.fetchAiInsights();
    if (res.success && res.data != null) {
      _aiInsights = res.data!;
    }
    _aiLoading = false;
    notifyListeners();
  }

  Future<void> sendAiChat(String prompt) async {
    if (prompt.trim().isEmpty) return;

    _aiHistory.add({'role': 'user', 'content': prompt});
    _aiAsking = true;
    notifyListeners();

    // Only send last 6 messages to keep context focused and save tokens
    final historyToSend = _aiHistory.length > 6 
        ? _aiHistory.sublist(_aiHistory.length - 6) 
        : _aiHistory;

    final res = await _api.sendAiChat(prompt, history: historyToSend);
    
    _aiHistory.add({
      'role': 'assistant',
      'content': res.success && res.data != null
          ? res.data!
          : (res.message ?? 'The assistant could not answer that.'),
    });
    
    _aiAsking = false;
    notifyListeners();
  }

  void clearChat() {
    _aiHistory.clear();
    notifyListeners();
  }
}
