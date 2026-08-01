class AvailableShift {
  final dynamic shiftId;
  final String shiftType;
  final String shiftDate;

  AvailableShift({
    required this.shiftId,
    required this.shiftType,
    required this.shiftDate,
  });

  factory AvailableShift.fromJson(Map<String, dynamic> json) {
    return AvailableShift(
      shiftId: json['shift_id'],
      shiftType: (json['shift_type'] ?? 'Unknown').toString(),
      shiftDate: (json['shift_date'] ?? '').toString(),
    );
  }
}

class ShiftOpdRecord {
  final dynamic srlNo;
  final String patientName;
  final String mrNo;
  final String doctorName;
  final String feeType;
  final double feeAmount;
  final double drShareAmount;
  final double hospitalShare;
  final String opdService;
  final String serviceDetail;
  final bool isCancelled;
  final String shiftDate;
  final String shiftType;

  ShiftOpdRecord({
    this.srlNo,
    required this.patientName,
    required this.mrNo,
    required this.doctorName,
    required this.feeType,
    required this.feeAmount,
    this.drShareAmount = 0.0,
    this.hospitalShare = 0.0,
    this.opdService = '',
    this.serviceDetail = '',
    this.isCancelled = false,
    required this.shiftDate,
    required this.shiftType,
  });

  bool get isConsultation => opdService.toLowerCase() == 'consultation' || feeType.toLowerCase().contains('consultation');

  factory ShiftOpdRecord.fromJson(Map<String, dynamic> json) {
    final amt = double.tryParse((json['service_amount'] ?? json['total_amount'] ?? json['fee_amount'] ?? json['amount'] ?? 0).toString()) ?? 0.0;
    final share = double.tryParse((json['dr_share_amount'] ?? json['share_amount'] ?? 0).toString()) ?? 0.0;
    final hosp = double.tryParse((json['hospital_share'] ?? (amt - share)).toString()) ?? (amt - share);
    final cancelled = json['opd_cancelled'] == true || json['opd_cancelled'] == 1;

    return ShiftOpdRecord(
      srlNo: json['srl_no'] ?? json['id'],
      patientName: (json['patient_name'] ?? json['name'] ?? '').toString(),
      mrNo: (json['mr_no'] ?? json['mr_number'] ?? '').toString(),
      doctorName: (json['doctor_name'] ?? json['doctor'] ?? json['service_detail'] ?? '').toString(),
      feeType: (json['fee_type'] ?? json['type'] ?? '').toString(),
      feeAmount: amt,
      drShareAmount: share,
      hospitalShare: hosp,
      opdService: (json['opd_service'] ?? json['service'] ?? '').toString(),
      serviceDetail: (json['service_detail'] ?? '').toString(),
      isCancelled: cancelled,
      shiftDate: (json['shift_date'] ?? '').toString(),
      shiftType: (json['shift_type'] ?? '').toString(),
    );
  }
}

class ShiftExpenseRecord {
  final dynamic id;
  final String expenseName;
  final double expenseAmount;
  final String expenseDescription;
  final String expenseDate;
  final String expenseBy;

  ShiftExpenseRecord({
    this.id,
    required this.expenseName,
    required this.expenseAmount,
    required this.expenseDescription,
    required this.expenseDate,
    required this.expenseBy,
  });

  factory ShiftExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ShiftExpenseRecord(
      id: json['id'] ?? json['srl_no'],
      expenseName: (json['expense_name'] ?? json['expense_head'] ?? json['name'] ?? '').toString(),
      expenseAmount: double.tryParse((json['expense_amount'] ?? json['amount'] ?? 0).toString()) ?? 0.0,
      expenseDescription: (json['expense_description'] ?? '').toString(),
      expenseDate: (json['expense_date'] ?? json['date'] ?? '').toString(),
      expenseBy: (json['expense_by'] ?? '').toString(),
    );
  }
}

class ShiftEmergencyBill {
  final dynamic id;
  final String patientName;
  final String mrNo;
  final String serviceHead;
  final double netAmount;
  final String createdAt;

  ShiftEmergencyBill({
    this.id,
    required this.patientName,
    required this.mrNo,
    this.serviceHead = '',
    required this.netAmount,
    required this.createdAt,
  });

  factory ShiftEmergencyBill.fromJson(Map<String, dynamic> json) {
    return ShiftEmergencyBill(
      id: json['id'] ?? json['bill_id'],
      patientName: (json['patient_name'] ?? '').toString(),
      mrNo: (json['mr_no'] ?? '').toString(),
      serviceHead: (json['service_head'] ?? json['service_name'] ?? 'Emergency Service').toString(),
      netAmount: double.tryParse((json['net_amount'] ?? json['total_amount'] ?? json['amount'] ?? 0).toString()) ?? 0.0,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
