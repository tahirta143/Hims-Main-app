class OpdReportRow {
  final String date;
  final String time;
  final DateTime? parsedDate;
  final String mrNumber;
  final String patientName;
  final String serviceName;
  final String serviceDetail;
  final String doctorName;
  final String shiftType;
  final double amount;
  final String status;
  final String type; // 'opd' | 'consultation' | 'emergency'

  OpdReportRow({
    required this.date,
    required this.time,
    this.parsedDate,
    required this.mrNumber,
    required this.patientName,
    required this.serviceName,
    required this.serviceDetail,
    required this.doctorName,
    required this.shiftType,
    required this.amount,
    required this.status,
    required this.type,
  });

  factory OpdReportRow.fromJson(Map<String, dynamic> json, {required String type}) {
    final dateStr = (json['shift_date'] ?? json['bill_date'] ?? json['created_at'] ?? json['date'] ?? json['appointment_date'] ?? '').toString();
    final timeStr = (json['shift_time'] ?? json['bill_time'] ?? json['created_at'] ?? json['time'] ?? json['slot_time'] ?? '').toString();
    final mr = (json['patient_mr_number'] ?? json['mr_number'] ?? json['mr_no'] ?? json['mrNumber'] ?? json['patientMrNumber'] ?? json['mr'] ?? '-').toString();
    final patient = (json['patient_name'] ?? json['name'] ?? '-').toString();
    final service = (json['opd_service'] ?? json['service_head'] ?? json['service_name'] ?? '-').toString();
    final detail = (json['service_detail'] ?? json['doctor_name'] ?? json['details'] ?? '-').toString();
    final doctor = (json['doctor_name'] ?? '-').toString();
    final shift = (json['shift_type'] ?? '-').toString();
    
    double parseAmount(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }
    
    final amt = parseAmount(json['total_amount'] ?? json['service_amount'] ?? json['amount'] ?? json['fee']);
    final st = (json['status'] ?? (json['opd_cancelled'] == true ? 'cancelled' : 'Completed')).toString();
    final parsed = DateTime.tryParse(dateStr);

    return OpdReportRow(
      date: dateStr,
      time: timeStr,
      parsedDate: parsed,
      mrNumber: mr,
      patientName: patient,
      serviceName: service,
      serviceDetail: detail,
      doctorName: doctor,
      shiftType: shift,
      amount: amt,
      status: st,
      type: type,
    );
  }
}

class OpdReportSummaryRow {
  final int srlNo;
  final String label;
  final int combinedRecords;
  final double amountTotal;

  OpdReportSummaryRow({
    required this.srlNo,
    required this.label,
    required this.combinedRecords,
    required this.amountTotal,
  });
}
