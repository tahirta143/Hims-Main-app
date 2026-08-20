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
  final int employeeSrlNo;

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
    required this.employeeSrlNo,
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
      employeeSrlNo: int.tryParse((json['employee_srl_no'] ?? 0).toString()) ?? 0,
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

class MonthlyAttendanceEmployee {
  final int employeeSrlNo;
  final String empId;
  final String employeeName;
  final String departmentName;
  final Map<int, String> days;
  final double present;
  final int absent;

  MonthlyAttendanceEmployee({
    required this.employeeSrlNo,
    required this.empId,
    required this.employeeName,
    required this.departmentName,
    required this.days,
    required this.present,
    required this.absent,
  });
}

class PayrollRun {
  final dynamic id;
  final dynamic periodYear;
  final dynamic periodMonth;
  final String status;
  final String? finalizedAt;

  PayrollRun({required this.id, required this.periodYear, required this.periodMonth, required this.status, this.finalizedAt});

  factory PayrollRun.fromJson(Map<String, dynamic> json) {
    return PayrollRun(
      id: json['id'],
      periodYear: json['period_year'],
      periodMonth: json['period_month'],
      status: json['status'] ?? 'Draft',
      finalizedAt: json['finalized_at'],
    );
  }
}

class SalarySheetLine {
  final dynamic id;
  final String employeeName;
  final String employeeCode;
  final String designation;
  final String departmentName;
  final int presentDays;
  final int absentDays;
  final int lateCount;
  final double basicSalary;
  final double houseRentAllowance;
  final double medicalAllowance;
  final double conveyanceAllowance;
  final double overtimeAmount;
  final double grossEarnings;
  final double absentDeduction;
  final double lateDeduction;
  final double eobiDeduction;
  final double incomeTax;
  final double totalDeductions;
  final double netPayable;
  final int employeeSrlNo;
  final int overtimeMinutes;

  SalarySheetLine({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.designation,
    required this.departmentName,
    required this.presentDays,
    required this.absentDays,
    required this.lateCount,
    required this.basicSalary,
    required this.houseRentAllowance,
    required this.medicalAllowance,
    required this.conveyanceAllowance,
    required this.overtimeAmount,
    required this.grossEarnings,
    required this.absentDeduction,
    required this.lateDeduction,
    required this.eobiDeduction,
    required this.incomeTax,
    required this.totalDeductions,
    required this.netPayable,
    required this.employeeSrlNo,
    required this.overtimeMinutes,
  });

  factory SalarySheetLine.fromJson(Map<String, dynamic> json) {
    return SalarySheetLine(
      id: json['id'],
      employeeName: json['employee_name'] ?? '-',
      employeeCode: json['employee_code'] ?? '-',
      designation: json['designation'] ?? '-',
      departmentName: json['department_name'] ?? '-',
      presentDays: int.tryParse((json['present_days'] ?? 0).toString()) ?? 0,
      absentDays: int.tryParse((json['absent_days'] ?? 0).toString()) ?? 0,
      lateCount: int.tryParse((json['late_count'] ?? 0).toString()) ?? 0,
      basicSalary: double.tryParse(json['basic_salary'].toString()) ?? 0.0,
      houseRentAllowance: double.tryParse(json['house_rent_allowance'].toString()) ?? 0.0,
      medicalAllowance: double.tryParse(json['medical_allowance'].toString()) ?? 0.0,
      conveyanceAllowance: double.tryParse(json['conveyance_allowance'].toString()) ?? 0.0,
      overtimeAmount: double.tryParse(json['overtime_amount'].toString()) ?? 0.0,
      grossEarnings: double.tryParse(json['gross_earnings'].toString()) ?? 0.0,
      absentDeduction: double.tryParse(json['absent_deduction'].toString()) ?? 0.0,
      lateDeduction: double.tryParse(json['late_deduction'].toString()) ?? 0.0,
      eobiDeduction: double.tryParse(json['eobi_deduction'].toString()) ?? 0.0,
      incomeTax: double.tryParse(json['income_tax'].toString()) ?? 0.0,
      totalDeductions: double.tryParse(json['total_deductions'].toString()) ?? 0.0,
      netPayable: double.tryParse(json['net_payable'].toString()) ?? 0.0,
      employeeSrlNo: int.tryParse((json['employee_srl_no'] ?? 0).toString()) ?? 0,
      overtimeMinutes: int.tryParse((json['overtime_minutes'] ?? 0).toString()) ?? 0,
    );
  }
}

class EmployeewiseAttendanceRow {
  final int employeeSrlNo;
  final String empId;
  final String employeeName;
  final String employeeMachineCode;
  final String departmentName;
  final double presentDays;
  final int absentDays;
  final int halfDays;
  final int leaveDays;
  final int holidayDays;
  final int weeklyOffDays;
  final int lateCount;
  final int lateMinutes;
  final int earlyMinutes;
  final int overtimeMinutes;
  final int flaggedDays;

  EmployeewiseAttendanceRow({
    required this.employeeSrlNo,
    required this.empId,
    required this.employeeName,
    required this.employeeMachineCode,
    required this.departmentName,
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.leaveDays,
    required this.holidayDays,
    required this.weeklyOffDays,
    required this.lateCount,
    required this.lateMinutes,
    required this.earlyMinutes,
    required this.overtimeMinutes,
    required this.flaggedDays,
  });

  factory EmployeewiseAttendanceRow.fromJson(Map<String, dynamic> json) {
    return EmployeewiseAttendanceRow(
      employeeSrlNo: int.tryParse((json['employee_srl_no'] ?? 0).toString()) ?? 0,
      empId: json['emp_id'] ?? '-',
      employeeName: json['employee_name'] ?? '-',
      employeeMachineCode: (json['employee_machine_code'] ?? '-').toString(),
      departmentName: json['department_name'] ?? '-',
      presentDays: double.tryParse(json['present_days'].toString()) ?? 0.0,
      absentDays: int.tryParse((json['absent_days'] ?? 0).toString()) ?? 0,
      halfDays: int.tryParse((json['half_days'] ?? 0).toString()) ?? 0,
      leaveDays: int.tryParse((json['leave_days'] ?? 0).toString()) ?? 0,
      holidayDays: int.tryParse((json['holiday_days'] ?? 0).toString()) ?? 0,
      weeklyOffDays: int.tryParse((json['weekly_off_days'] ?? 0).toString()) ?? 0,
      lateCount: int.tryParse((json['late_count'] ?? 0).toString()) ?? 0,
      lateMinutes: int.tryParse((json['late_minutes'] ?? 0).toString()) ?? 0,
      earlyMinutes: int.tryParse((json['early_minutes'] ?? 0).toString()) ?? 0,
      overtimeMinutes: int.tryParse((json['overtime_minutes'] ?? 0).toString()) ?? 0,
      flaggedDays: int.tryParse((json['flagged_days'] ?? 0).toString()) ?? 0,
    );
  }
}
