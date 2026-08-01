class YearlyBreakdownRawItem {
  final String? service;
  final String? head;
  final String? doctorName;
  final int month;
  final double amount;
  final String? shift;

  YearlyBreakdownRawItem({
    this.service,
    this.head,
    this.doctorName,
    required this.month,
    required this.amount,
    this.shift,
  });

  factory YearlyBreakdownRawItem.fromJson(Map<String, dynamic> json) {
    final amt = json['amount'] ?? json['total'] ?? 0;
    return YearlyBreakdownRawItem(
      service: json['service']?.toString(),
      head: json['head']?.toString(),
      doctorName: json['doctorName']?.toString() ?? json['doctor_name']?.toString(),
      month: int.tryParse((json['month'] ?? 1).toString()) ?? 1,
      amount: double.tryParse(amt.toString()) ?? 0.0,
      shift: json['shift']?.toString(),
    );
  }
}

class YearlyRowData {
  final String key;
  final String title;
  final List<double> months; // 12 elements
  final double total;

  YearlyRowData({
    required this.key,
    required this.title,
    required this.months,
    required this.total,
  });
}
