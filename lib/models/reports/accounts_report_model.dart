class AccountsReceipt {
  final String type;
  final String label;
  final double amount;
  final double doctorShare;
  final double hospitalShare;
  final bool cancelled;

  AccountsReceipt({required this.type, required this.label, required this.amount, required this.doctorShare, required this.hospitalShare, required this.cancelled});

  factory AccountsReceipt.fromJson(Map<String, dynamic> json) {
    final service = (json['opd_service'] ?? '').toString().trim();
    final normalized = service.toLowerCase();
    final type = json['is_emergency_service'] == true || normalized == 'emergency'
        ? 'Emergency'
        : normalized == 'consultation'
            ? 'Consultation'
            : normalized == 'laboratory'
                ? 'Laboratory'
                : 'OPD';
    final double amount = double.tryParse((json['service_amount'] ?? json['total_amount'] ?? 0).toString()) ?? 0.0;
    final double doctorShare = type == 'Consultation' ? double.tryParse((json['dr_share_amount'] ?? 0).toString()) ?? 0.0 : 0.0;
    final hospitalShare = type == 'Consultation'
        ? double.tryParse((json['hospital_share'] ?? amount - doctorShare).toString()) ?? amount - doctorShare
        : amount;
    final detail = (json['service_detail'] ?? '').toString().trim();
    final label = detail.isNotEmpty ? detail : (service.isNotEmpty ? service : 'Other');
    return AccountsReceipt(
      type: type,
      label: label,
      amount: amount,
      doctorShare: doctorShare,
      hospitalShare: hospitalShare,
      cancelled: json['opd_cancelled'] == true || json['opd_cancelled'].toString() == '1',
    );
  }
}

class AccountsRevenueGroup {
  final String key;
  final String type;
  final String label;
  final int count;
  final double total;
  final double doctorShare;
  final double hospitalShare;

  AccountsRevenueGroup({required this.key, required this.type, required this.label, required this.count, required this.total, required this.doctorShare, required this.hospitalShare});
}

class AccountsExpense {
  final dynamic id;
  final String date;
  final String name;
  final String description;
  final double amount;

  AccountsExpense({this.id, required this.date, required this.name, required this.description, required this.amount});

  factory AccountsExpense.fromJson(Map<String, dynamic> json) => AccountsExpense(
        id: json['srl_no'] ?? json['expense_id'],
        date: (json['shift_date'] ?? json['expense_date'] ?? '').toString(),
        name: (json['expense_name'] ?? json['expense_head'] ?? '-').toString(),
        description: (json['expense_description'] ?? '-').toString(),
        amount: double.tryParse((json['expense_amount'] ?? 0).toString()) ?? 0,
      );
}
