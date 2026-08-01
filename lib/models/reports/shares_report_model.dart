class SharesReportRow {
  final String personType;
  final String personCode;
  final String personName;
  final String department;
  final String serviceType;
  final dynamic serviceId;
  final String serviceName;
  final double masterRate;
  final double? customCharge;
  final String shareType;
  final double shareValue;
  final int? followupDays;
  final bool priceEditable;

  SharesReportRow({
    required this.personType,
    required this.personCode,
    required this.personName,
    required this.department,
    required this.serviceType,
    this.serviceId,
    required this.serviceName,
    required this.masterRate,
    this.customCharge,
    required this.shareType,
    required this.shareValue,
    this.followupDays,
    required this.priceEditable,
  });

  factory SharesReportRow.fromJson(Map<String, dynamic> json) {
    return SharesReportRow(
      personType: (json['person_type'] ?? '').toString(),
      personCode: (json['person_code'] ?? '').toString(),
      personName: (json['person_name'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      serviceType: (json['service_type'] ?? '').toString(),
      serviceId: json['service_id'],
      serviceName: (json['service_name'] ?? '').toString(),
      masterRate: double.tryParse((json['master_rate'] ?? 0).toString()) ?? 0.0,
      customCharge: json['custom_charge'] != null
          ? double.tryParse(json['custom_charge'].toString())
          : null,
      shareType: (json['share_type'] ?? '').toString(),
      shareValue: double.tryParse((json['share_value'] ?? 0).toString()) ?? 0.0,
      followupDays: json['followup_days'] != null
          ? int.tryParse(json['followup_days'].toString())
          : null,
      priceEditable: json['price_editable'] == true || json['price_editable'] == 1,
    );
  }
}

class SharesReportTotals {
  final int totalRecords;
  final int doctorRecords;
  final int employeeRecords;
  final int indoorRecords;

  SharesReportTotals({
    required this.totalRecords,
    required this.doctorRecords,
    required this.employeeRecords,
    required this.indoorRecords,
  });

  factory SharesReportTotals.fromJson(Map<String, dynamic> json) {
    return SharesReportTotals(
      totalRecords: int.tryParse((json['total_records'] ?? 0).toString()) ?? 0,
      doctorRecords: int.tryParse((json['doctor_records'] ?? 0).toString()) ?? 0,
      employeeRecords: int.tryParse((json['employee_records'] ?? 0).toString()) ?? 0,
      indoorRecords: int.tryParse((json['indoor_records'] ?? 0).toString()) ?? 0,
    );
  }
}
