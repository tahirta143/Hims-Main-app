class PayrollAttendanceRow {
  final String empId;
  final String employeeName;
  final String departmentId;
  final String departmentName;
  final String dutyShiftId;
  final String dutyShiftName;
  final String machineCode;
  final String date;
  final DateTime? parsedDate;
  final String timeIn;
  final String timeOut;
  final String status;
  final double payableSalary;

  PayrollAttendanceRow({
    required this.empId,
    required this.employeeName,
    required this.departmentId,
    required this.departmentName,
    required this.dutyShiftId,
    required this.dutyShiftName,
    required this.machineCode,
    required this.date,
    this.parsedDate,
    required this.timeIn,
    required this.timeOut,
    required this.status,
    required this.payableSalary,
  });

  factory PayrollAttendanceRow.fromJson(Map<String, dynamic> json) {
    final dtStr = (json['date'] ?? json['attendance_date'] ?? '').toString();
    final parsed = DateTime.tryParse(dtStr);

    return PayrollAttendanceRow(
      empId: (json['emp_id'] ?? json['employee_id'] ?? json['id'] ?? '-').toString(),
      employeeName: (json['employee_name'] ?? json['name'] ?? '-').toString(),
      departmentId: (json['department_id'] ?? '').toString(),
      departmentName: (json['department_name'] ?? json['dept_name'] ?? '-').toString(),
      dutyShiftId: (json['duty_shift_id'] ?? '').toString(),
      dutyShiftName: (json['duty_shift_name'] ?? json['shift_name'] ?? '-').toString(),
      machineCode: (json['employee_machine_code'] ?? json['machine_code'] ?? '-').toString(),
      date: dtStr,
      parsedDate: parsed,
      timeIn: (json['time_in'] ?? '-').toString(),
      timeOut: (json['time_out'] ?? '-').toString(),
      status: (json['status'] ?? 'Present').toString(),
      payableSalary: (json['payable_salary'] != null)
          ? double.tryParse(json['payable_salary'].toString()) ?? 0.0
          : 0.0,
    );
  }
}

class PayrollLookupItem {
  final String id;
  final String name;

  PayrollLookupItem({required this.id, required this.name});

  factory PayrollLookupItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['srl_no'] ?? json['id'] ?? json['department_id'] ?? json['employee_id'] ?? json['duty_shift_id'] ?? json['shift_id'] ?? json['code'] ?? '';
    final rawName = json['department_name'] ?? json['name'] ?? json['employee_name'] ?? json['shift_name'] ?? json['duty_shift_name'] ?? json['title'] ?? '-';
    return PayrollLookupItem(
      id: rawId.toString().trim(),
      name: rawName.toString().trim(),
    );
  }
}

class PayrollReportSummaryRow {
  final int srlNo;
  final String employeeName;
  final String empId;
  final int totalDays;
  final int presentDays;
  final int lateDays;
  final int absentDays;

  PayrollReportSummaryRow({
    required this.srlNo,
    required this.employeeName,
    required this.empId,
    required this.totalDays,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
  });
}
