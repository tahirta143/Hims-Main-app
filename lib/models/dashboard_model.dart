import 'package:flutter/material.dart';

// ─── Legacy models (kept for backward compat) ────────────────────────────────

class ShiftDashboardInfo {
  final int shiftId;
  final String shiftType;
  final String shiftDate;

  ShiftDashboardInfo({
    required this.shiftId,
    required this.shiftType,
    required this.shiftDate,
  });

  factory ShiftDashboardInfo.fromJson(Map<String, dynamic> json) {
    return ShiftDashboardInfo(
      shiftId: json['shift_id'] ?? 0,
      shiftType: json['shift_type'] ?? 'Unknown',
      shiftDate: json['shift_date'] ?? '',
    );
  }
}

class DashboardStat {
  final String title;
  final double value;
  final double? prevValue;
  final String? subtitle;
  final bool isCurrency;

  DashboardStat({
    required this.title,
    required this.value,
    this.prevValue,
    this.subtitle,
    this.isCurrency = false,
  });

  String get trend {
    if (prevValue == null || prevValue == 0) return '0%';
    final change = ((value - prevValue!) / prevValue!) * 100;
    return '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%';
  }

  bool get trendUp => (value - (prevValue ?? 0)) >= 0;
}

class ChartDataPoint {
  final String x;
  final double y;
  final String? category;

  ChartDataPoint(this.x, this.y, {this.category});
}

class ExpenseBreakdownItem {
  final String name;
  final double value;
  final Color color;

  ExpenseBreakdownItem({
    required this.name,
    required this.value,
    required this.color,
  });
}

class CalendarAppointmentData {
  final String doctorName;
  final List<dynamic> appointments;

  CalendarAppointmentData({
    required this.doctorName,
    required this.appointments,
  });
}

// ─── Management Dashboard API models (mirrors React's /reports/management-dashboard) ────

/// Per-shift breakdown (qty + amount) used inside DashboardCategory.byShift
class ShiftBreakdown {
  final int qty;
  final double amount;
  final double drShare;
  final double hospitalShare;

  const ShiftBreakdown({
    this.qty = 0,
    this.amount = 0,
    this.drShare = 0,
    this.hospitalShare = 0,
  });

  factory ShiftBreakdown.fromJson(Map<String, dynamic> json) {
    return ShiftBreakdown(
      qty: _parseInt(json['qty']),
      amount: _parseDouble(json['amount']),
      drShare: _parseDouble(json['drShare']),
      hospitalShare: _parseDouble(json['hospitalShare']),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

/// One of: opd, consultation, emergency, lab, expenses
class DashboardCategory {
  final int qty;
  final double amount;
  final double drShare;
  final double hospitalShare;
  final Map<String, ShiftBreakdown> byShift;

  const DashboardCategory({
    this.qty = 0,
    this.amount = 0,
    this.drShare = 0,
    this.hospitalShare = 0,
    this.byShift = const {},
  });

  factory DashboardCategory.fromJson(Map<String, dynamic> json) {
    final byShiftRaw = json['byShift'] as Map<String, dynamic>? ?? {};
    return DashboardCategory(
      qty: ShiftBreakdown._parseInt(json['qty']),
      amount: ShiftBreakdown._parseDouble(json['amount']),
      drShare: ShiftBreakdown._parseDouble(json['drShare']),
      hospitalShare: ShiftBreakdown._parseDouble(json['hospitalShare']),
      byShift: byShiftRaw.map(
        (k, v) => MapEntry(k, ShiftBreakdown.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  static DashboardCategory empty() => const DashboardCategory();
}

/// Revenue summary returned by the API
class DashboardRevenue {
  final double net;
  final double collected;
  final double drShare;
  final double expenses;
  final Map<String, ShiftBreakdown> byShift;

  const DashboardRevenue({
    this.net = 0,
    this.collected = 0,
    this.drShare = 0,
    this.expenses = 0,
    this.byShift = const {},
  });

  factory DashboardRevenue.fromJson(Map<String, dynamic> json) {
    final byShiftRaw = json['byShift'] as Map<String, dynamic>? ?? {};
    return DashboardRevenue(
      net: ShiftBreakdown._parseDouble(json['net']),
      collected: ShiftBreakdown._parseDouble(json['collected']),
      drShare: ShiftBreakdown._parseDouble(json['drShare']),
      expenses: ShiftBreakdown._parseDouble(json['expenses']),
      byShift: byShiftRaw.map(
        (k, v) => MapEntry(k, ShiftBreakdown.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  static DashboardRevenue empty() => const DashboardRevenue();
}

/// A single head row inside the breakdown table
class DashboardHead {
  final String name;
  final int qty;
  final double amount;
  final double drShare;
  final double hospitalShare;
  final Map<String, ShiftBreakdown> byShift;

  const DashboardHead({
    required this.name,
    this.qty = 0,
    this.amount = 0,
    this.drShare = 0,
    this.hospitalShare = 0,
    this.byShift = const {},
  });

  factory DashboardHead.fromJson(Map<String, dynamic> json) {
    final byShiftRaw = json['byShift'] as Map<String, dynamic>? ?? {};
    return DashboardHead(
      name: json['name']?.toString() ?? '',
      qty: ShiftBreakdown._parseInt(json['qty']),
      amount: ShiftBreakdown._parseDouble(json['amount']),
      drShare: ShiftBreakdown._parseDouble(json['drShare']),
      hospitalShare: ShiftBreakdown._parseDouble(json['hospitalShare']),
      byShift: byShiftRaw.map(
        (k, v) => MapEntry(k, ShiftBreakdown.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }
}

/// Full management-dashboard API response wrapper
class ManagementSummary {
  final DashboardCategory opd;
  final DashboardCategory consultation;
  final DashboardCategory emergency;
  final DashboardCategory lab;
  final DashboardCategory expenses;
  final DashboardRevenue revenue;
  // heads: { opd: [...], consultation: [...], ... }
  final Map<String, List<DashboardHead>> heads;

  const ManagementSummary({
    required this.opd,
    required this.consultation,
    required this.emergency,
    required this.lab,
    required this.expenses,
    required this.revenue,
    this.heads = const {},
  });

  factory ManagementSummary.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'] as Map<String, dynamic>? ?? {};
    final headsRaw = json['heads'] as Map<String, dynamic>? ?? {};

    DashboardCategory catFrom(String key) {
      final v = cats[key];
      if (v == null) return DashboardCategory.empty();
      return DashboardCategory.fromJson(v as Map<String, dynamic>);
    }

    return ManagementSummary(
      opd: catFrom('opd'),
      consultation: catFrom('consultation'),
      emergency: catFrom('emergency'),
      lab: catFrom('lab'),
      expenses: catFrom('expenses'),
      revenue: json['revenue'] != null
          ? DashboardRevenue.fromJson(json['revenue'] as Map<String, dynamic>)
          : DashboardRevenue.empty(),
      heads: headsRaw.map((k, v) {
        final list = v as List<dynamic>? ?? [];
        return MapEntry(
          k,
          list.map((e) => DashboardHead.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }),
    );
  }
}

// ─── Attendance ───────────────────────────────────────────────────────────────

class AttendanceRecord {
  final String id;
  final String empId;
  final String employeeName;
  final String departmentName;
  final String status;
  final String? timeIn;
  final String? timeOut;
  final int lateMinutes;

  const AttendanceRecord({
    required this.id,
    this.empId = '',
    this.employeeName = '',
    this.departmentName = '',
    this.status = '',
    this.timeIn,
    this.timeOut,
    this.lateMinutes = 0,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      empId: json['emp_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? '',
      departmentName: json['department_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      timeIn: json['time_in']?.toString(),
      timeOut: json['time_out']?.toString(),
      lateMinutes: ShiftBreakdown._parseInt(json['late_minutes']),
    );
  }

  /// Sort rank: Absent=0, Leave=1, Half Day=2, Late=3, Present=4
  int get sortRank {
    if (status == 'Absent') return 0;
    if (status == 'Leave') return 1;
    if (status == 'Half Day') return 2;
    if (lateMinutes > 0) return 3;
    return 4;
  }

  bool get isException => sortRank <= 3;
}
