class ShiftSummaryValues {
  final double opdTotal;
  final double expensesTotal;

  ShiftSummaryValues({
    required this.opdTotal,
    required this.expensesTotal,
  });

  factory ShiftSummaryValues.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ShiftSummaryValues(opdTotal: 0, expensesTotal: 0);
    return ShiftSummaryValues(
      opdTotal: double.tryParse((json['opd_total'] ?? 0).toString()) ?? 0.0,
      expensesTotal: double.tryParse((json['expenses_total'] ?? 0).toString()) ?? 0.0,
    );
  }
}

class MonthlyDaySummary {
  final String date;
  final ShiftSummaryValues morning;
  final ShiftSummaryValues evening;
  final ShiftSummaryValues night;

  MonthlyDaySummary({
    required this.date,
    required this.morning,
    required this.evening,
    required this.night,
  });

  factory MonthlyDaySummary.fromJson(Map<String, dynamic> json) {
    return MonthlyDaySummary(
      date: (json['date'] ?? '').toString(),
      morning: ShiftSummaryValues.fromJson(json['morning']),
      evening: ShiftSummaryValues.fromJson(json['evening']),
      night: ShiftSummaryValues.fromJson(json['night']),
    );
  }
}

class MonthlyParticularItem {
  final String service;
  final double morning;
  final double evening;
  final double night;
  final double total;

  MonthlyParticularItem({
    required this.service,
    required this.morning,
    required this.evening,
    required this.night,
    required this.total,
  });

  factory MonthlyParticularItem.fromJson(Map<String, dynamic> json) {
    return MonthlyParticularItem(
      service: (json['service'] ?? json['name'] ?? 'Other').toString(),
      morning: double.tryParse((json['morning'] ?? 0).toString()) ?? 0.0,
      evening: double.tryParse((json['evening'] ?? 0).toString()) ?? 0.0,
      night: double.tryParse((json['night'] ?? 0).toString()) ?? 0.0,
      total: double.tryParse((json['total'] ?? 0).toString()) ?? 0.0,
    );
  }
}
