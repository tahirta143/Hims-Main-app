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
  
  // New fields from React code
  final String mrNumber;
  final String patientName;
  final String opdService;
  final String serviceDetail;

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
    this.mrNumber = '—',
    this.patientName = '—',
    this.opdService = 'Laboratory',
    this.serviceDetail = '—',
  });

  factory LabReportItem.fromJson(Map<String, dynamic> json) {
    final amt = json['test_amount'] ?? json['total_amount'] ?? json['amount'] ?? 0;
    final share = json['company_share'] ?? json['share'] ?? 0;
    
    // Mapping logic following React implementation
    final mr = json['patient_mr_number'] ?? json['mr_number'] ?? json['mr_no'] ?? json['mr'] ?? '—';
    final patient = json['patient_name'] ?? json['patient'] ?? '—';
    final service = json['opd_service'] ?? 'Laboratory';
    final detail = json['service_detail'] ?? json['test_name'] ?? '—';
    
    final date = json['test_date'] ?? json['shift_date'] ?? json['date'] ?? json['created_at'] ?? '';
    final time = json['test_time'] ?? json['time'] ?? json['created_at'] ?? '';

    return LabReportItem(
      id: json['id'] ?? json['receipt_srl'] ?? json['srl_no'],
      receiptSrl: json['receipt_srl'] ?? json['srl_no'] ?? json['id'] ?? '—',
      testName: (json['test_name'] ?? json['name'] ?? 'Unknown Test').toString(),
      testAmount: double.tryParse(amt.toString()) ?? 0.0,
      companyShare: double.tryParse(share.toString()) ?? 0.0,
      testDate: date.toString(),
      testTime: time.toString(),
      shiftType: (json['shift_type'] ?? json['shift'] ?? '—').toString(),
      testCount: int.tryParse((json['test_count'] ?? 1).toString()) ?? 1,
      mrNumber: mr.toString(),
      patientName: patient.toString(),
      opdService: service.toString(),
      serviceDetail: detail.toString(),
    );
  }
}
