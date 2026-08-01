class ExpenseReportItem {
  final dynamic id;
  final String expenseName;
  final String expenseDescription;
  final double expenseAmount;
  final String expenseDate;
  final String expenseTime;
  final String expenseShift;
  final String expenseBy;
  final int expenseCount;

  ExpenseReportItem({
    this.id,
    required this.expenseName,
    required this.expenseDescription,
    required this.expenseAmount,
    required this.expenseDate,
    required this.expenseTime,
    required this.expenseShift,
    required this.expenseBy,
    this.expenseCount = 1,
  });

  factory ExpenseReportItem.fromJson(Map<String, dynamic> json) {
    final amt = json['expense_amount'] ?? json['amount'] ?? 0;
    return ExpenseReportItem(
      id: json['id'] ?? json['srl_no'],
      expenseName: (json['expense_name'] ?? json['name'] ?? 'Unknown').toString(),
      expenseDescription: (json['expense_description'] ?? json['description'] ?? '—').toString(),
      expenseAmount: double.tryParse(amt.toString()) ?? 0.0,
      expenseDate: (json['expense_date'] ?? json['date'] ?? '').toString(),
      expenseTime: (json['expense_time'] ?? json['time'] ?? '').toString(),
      expenseShift: (json['expense_shift'] ?? json['shift'] ?? '').toString(),
      expenseBy: (json['expense_by'] ?? json['by'] ?? '').toString(),
      expenseCount: int.tryParse((json['expense_count'] ?? 1).toString()) ?? 1,
    );
  }
}
