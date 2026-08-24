import 'task_model.dart';

// ── Overview Report (counts + trend + by-department) ─────────────────────────
class OverviewCounts {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int onHold;

  const OverviewCounts({
    this.total = 0,
    this.pending = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.onHold = 0,
  });

  factory OverviewCounts.fromJson(Map<String, dynamic> json) {
    return OverviewCounts(
      total:      json['total']      is int ? json['total']      : int.tryParse(json['total']?.toString()      ?? '0') ?? 0,
      pending:    json['pending']    is int ? json['pending']    : int.tryParse(json['pending']?.toString()    ?? '0') ?? 0,
      inProgress: json['inProgress'] is int ? json['inProgress'] : int.tryParse(json['inProgress']?.toString() ?? '0') ?? 0,
      completed:  json['completed']  is int ? json['completed']  : int.tryParse(json['completed']?.toString()  ?? '0') ?? 0,
      onHold:     json['onHold']     is int ? json['onHold']     : int.tryParse(json['onHold']?.toString()     ?? '0') ?? 0,
    );
  }
}

class TrendPoint {
  final String day;    // formatted label, e.g. "22 Aug"
  final int completed;

  const TrendPoint({required this.day, required this.completed});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    String raw = json['day']?.toString() ?? '';
    String label = raw;
    try {
      final dt = DateTime.parse(raw);
      // e.g. "22 Aug"
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      label = '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {}
    return TrendPoint(
      day: label,
      completed: json['completed'] is int ? json['completed'] : int.tryParse(json['completed']?.toString() ?? '0') ?? 0,
    );
  }
}

class DeptTaskCount {
  final String departmentName;
  final int total;

  const DeptTaskCount({required this.departmentName, required this.total});

  factory DeptTaskCount.fromJson(Map<String, dynamic> json) {
    return DeptTaskCount(
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString() ?? 'Unknown',
      total: json['total'] is int ? json['total'] : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }
}

class OverviewReport {
  final OverviewCounts counts;
  final List<TrendPoint> completionTrend;
  final List<DeptTaskCount> byDepartment;
  final int activeUsers;

  const OverviewReport({
    required this.counts,
    required this.completionTrend,
    required this.byDepartment,
    this.activeUsers = 0,
  });

  factory OverviewReport.fromJson(Map<String, dynamic> json) {
    final countsRaw = json['counts'];
    final counts = countsRaw is Map<String, dynamic>
        ? OverviewCounts.fromJson(countsRaw)
        : const OverviewCounts();

    final trendRaw = json['completionTrend'] as List<dynamic>? ?? [];
    final trend = trendRaw.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>)).toList();

    final byDeptRaw = json['byDepartment'] as List<dynamic>? ?? [];
    final byDept = byDeptRaw.map((e) => DeptTaskCount.fromJson(e as Map<String, dynamic>)).toList();

    return OverviewReport(
      counts: counts,
      completionTrend: trend,
      byDepartment: byDept,
      activeUsers: json['activeUsers'] is int ? json['activeUsers'] : int.tryParse(json['activeUsers']?.toString() ?? '0') ?? 0,
    );
  }
}

class ProgressTaskRow {
  final int id;
  final String title;
  final String? projectName;
  final String? departmentName;
  final String status;
  final String priority;
  final String? dueDate;
  final int completedPoints;
  final int totalPoints;
  final double progressPercent;
  final bool isOverdue;
  final List<TaskAssignee> assignees;

  ProgressTaskRow({
    required this.id,
    required this.title,
    this.projectName,
    this.departmentName,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.completedPoints,
    required this.totalPoints,
    required this.progressPercent,
    required this.isOverdue,
    this.assignees = const [],
  });

  factory ProgressTaskRow.fromJson(Map<String, dynamic> json) {
    final assigneesList = (json['assignees'] as List<dynamic>?)
            ?.map((e) => TaskAssignee.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ProgressTaskRow(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? json['project_name']?.toString(),
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      priority: json['priority']?.toString() ?? 'medium',
      dueDate: json['dueDate']?.toString() ?? json['due_date']?.toString(),
      completedPoints: json['completedPoints'] is int
          ? json['completedPoints']
          : int.tryParse(json['completedPoints']?.toString() ?? '0') ?? 0,
      totalPoints: json['totalPoints'] is int
          ? json['totalPoints']
          : int.tryParse(json['totalPoints']?.toString() ?? '0') ?? 0,
      progressPercent: json['progressPercent'] is num
          ? (json['progressPercent'] as num).toDouble()
          : double.tryParse(json['progressPercent']?.toString() ?? '0') ?? 0.0,
      isOverdue: json['isOverdue'] == true || json['is_overdue'] == 1,
      assignees: assigneesList,
    );
  }
}

class UserPerformanceReport {
  final int employeeId;
  final String name;
  final String? employeeCode;
  final String? designation;
  final String? departmentName;
  final int assignedCount;
  final int completedCount;
  final int inProgressCount;
  final int pendingCount;
  final int overdueCount;
  final double avgRating;
  final int ratingCount;

  UserPerformanceReport({
    required this.employeeId,
    required this.name,
    this.employeeCode,
    this.designation,
    this.departmentName,
    this.assignedCount = 0,
    this.completedCount = 0,
    this.inProgressCount = 0,
    this.pendingCount = 0,
    this.overdueCount = 0,
    this.avgRating = 0.0,
    this.ratingCount = 0,
  });

  factory UserPerformanceReport.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
    return UserPerformanceReport(
      employeeId:     _i(json['employeeId']),
      name:           json['name']?.toString() ?? '',
      employeeCode:   json['employeeCode']?.toString(),
      designation:    json['designation']?.toString(),
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString(),
      assignedCount:  _i(json['assignedCount']  ?? json['assigned']),
      completedCount: _i(json['completedCount'] ?? json['completed']),
      inProgressCount: _i(json['inProgressCount'] ?? json['inProgress']),
      pendingCount:   _i(json['pendingCount']   ?? json['pending']),
      overdueCount:   _i(json['overdueCount']),
      avgRating: json['avgRating'] is num
          ? (json['avgRating'] as num).toDouble()
          : double.tryParse(json['avgRating']?.toString() ?? '0') ?? 0.0,
      ratingCount: _i(json['ratingCount']),
    );
  }
}

class DepartmentSummaryReport {
  final int departmentId;
  final String departmentName;
  final int staff;
  final int tasks;
  final int completed;
  final int overdueTasks;
  final double completionRate;

  DepartmentSummaryReport({
    required this.departmentId,
    required this.departmentName,
    this.staff = 0,
    this.tasks = 0,
    this.completed = 0,
    this.overdueTasks = 0,
    this.completionRate = 0.0,
  });

  factory DepartmentSummaryReport.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
    
    return DepartmentSummaryReport(
      departmentId: _i(json['departmentId']),
      departmentName: json['departmentName']?.toString() ?? 'Unknown',
      staff: _i(json['staff']),
      tasks: _i(json['tasks'] ?? json['totalTasks']),
      completed: _i(json['completed'] ?? json['completedTasks']),
      overdueTasks: _i(json['overdueTasks']),
      completionRate: json['completionRate'] is num
          ? (json['completionRate'] as num).toDouble()
          : double.tryParse(json['completionRate']?.toString() ?? '0') ?? 0.0,
    );
  }
}
