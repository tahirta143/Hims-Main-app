class LabReportItem {
  final dynamic id;
  final dynamic receiptSrl;
  final String testName;
  final double testAmount;
  final double companyShare;
  final String testDate;
  final String testTime;
  final String shiftType;
  final int testCount;

  LabReportItem({
    this.id,
    this.receiptSrl,
    required this.testName,
    required this.testAmount,
    this.companyShare = 0.0,
    required this.testDate,
    required this.testTime,
    required this.shiftType,
    this.testCount = 1,
  });

  factory LabReportItem.fromJson(Map<String, dynamic> json) {
    final amt = json['test_amount'] ?? json['total_amount'] ?? json['amount'] ?? 0;
    final share = json['company_share'] ?? json['share'] ?? 0;
    return LabReportItem(
      id: json['id'] ?? json['receipt_srl'] ?? json['srl_no'],
      receiptSrl: json['receipt_srl'] ?? json['srl_no'] ?? json['id'] ?? '—',
      testName: (json['test_name'] ?? json['name'] ?? 'Unknown Test').toString(),
      testAmount: double.tryParse(amt.toString()) ?? 0.0,
      companyShare: double.tryParse(share.toString()) ?? 0.0,
      testDate: (json['test_date'] ?? json['date'] ?? '').toString(),
      testTime: (json['test_time'] ?? json['time'] ?? '').toString(),
      shiftType: (json['shift_type'] ?? json['shift'] ?? '').toString(),
      testCount: int.tryParse((json['test_count'] ?? 1).toString()) ?? 1,
    );
  }
}
