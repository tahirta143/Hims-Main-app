import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/reports/payroll_report_provider.dart';
import '../../models/reports/payroll_report_model.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class PayrollReportScreen extends StatefulWidget {
  const PayrollReportScreen({super.key});

  @override
  State<PayrollReportScreen> createState() => _PayrollReportScreenState();
}

class _PayrollReportScreenState extends State<PayrollReportScreen> with WidgetsBindingObserver {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableVertCtrl = ScrollController();
  final ScrollController _tableHorizCtrl = ScrollController();
  final ScrollController _headerHorizCtrl = ScrollController();

  int _visibleCount = 12;

  @override
  void initState() {
    super.initState();
    _tableVertCtrl.addListener(_onTableScroll);
    _tableHorizCtrl.addListener(_syncHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ── Fix: always start this screen with a clean slate so that
      // returning to it (e.g. after visiting another tab/screen) never
      // shows stale filters or stale filtered data. ──
      final provider = context.read<PayrollReportProvider>();
      _searchCtrl.clear();
      provider.clearFilters();
      provider.loadLookups();
      provider.fetchReport();
      if (mounted) setState(() => _visibleCount = 12);
    });
  }

  @override
  void dispose() {
    _tableVertCtrl.removeListener(_onTableScroll);
    _tableHorizCtrl.removeListener(_syncHorizontalScroll);
    _tableVertCtrl.dispose();
    _tableHorizCtrl.dispose();
    _headerHorizCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _syncHorizontalScroll() {
    if (_headerHorizCtrl.hasClients && _tableHorizCtrl.hasClients) {
      if (_headerHorizCtrl.offset != _tableHorizCtrl.offset) {
        _headerHorizCtrl.jumpTo(_tableHorizCtrl.offset);
      }
    }
  }

  void _onTableScroll() {
    if (_tableVertCtrl.hasClients && _tableVertCtrl.position.maxScrollExtent > 0) {
      if (_tableVertCtrl.position.pixels >= _tableVertCtrl.position.maxScrollExtent - 80) {
        final provider = context.read<PayrollReportProvider>();
        final total = provider.summarized
            ? provider.summarizedRows.length
            : provider.filteredRows.length;
        if (_visibleCount < total) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _visibleCount < total) {
              setState(() {
                _visibleCount = (_visibleCount + 12).clamp(12, total);
              });
            }
          });
        }
      }
    }
  }

  String _formatMoney(double val) {
    return 'PKR ${NumberFormat('#,##0').format(val)}';
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatDateStr(String val) {
    if (val.isEmpty) return '-';
    final d = DateTime.tryParse(val);
    if (d == null) return val;
    return DateFormat('dd MMM yyyy').format(d);
  }

  String _formatTime12(String val) {
    if (val.isEmpty || val == '-') return '-';
    final parts = val.split(':');
    if (parts.length < 2) return val;
    final hour = int.tryParse(parts[0]);
    final min = int.tryParse(parts[1]);
    if (hour == null || min == null) return val;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${min.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final provider = context.read<PayrollReportProvider>();
    final initialDate = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      if (isFrom) {
        provider.setDateFrom(formatted);
      } else {
        provider.setDateTo(formatted);
      }
      provider.fetchReport();
      setState(() => _visibleCount = 12);
    }
  }

  // ── CSV Export Function ──────────────────────────────────────────────────
  Future<void> _handleExportCSV(BuildContext context) async {
    final provider = context.read<PayrollReportProvider>();
    if (provider.activeTab == 'employeewise') {
      final headers = ['Emp ID', 'Employee', 'Code', 'Department', 'Present', 'Absent', 'Half', 'Leave', 'Holiday', 'Off', 'Lates', 'Late Minutes', 'Early Minutes', 'Overtime Minutes'];
      final rows = provider.filteredEmployeewiseRows.map((row) => [
        row.empId, row.employeeName, row.employeeMachineCode, row.departmentName, row.presentDays, row.absentDays,
        row.halfDays, row.leaveDays, row.holidayDays, row.weeklyOffDays, row.lateCount, row.lateMinutes, row.earlyMinutes, row.overtimeMinutes,
      ]).toList();
      final csvString = [headers.join(','), ...rows.map((row) => row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(','))].join('\n');
      await Printing.sharePdf(bytes: Uint8List.fromList(csvString.codeUnits), filename: 'employeewise_attendance.csv');
      return;
    }
    final isSummarized = provider.summarized;
    final headers = isSummarized
        ? ['Sr', 'Employee Name', 'Emp ID', 'Total Days', 'Present', 'Late', 'Absent']
        : ['Sr', 'Date', 'Time In', 'Time Out', 'Emp ID', 'Employee Name', 'Department', 'Shift', 'Machine Code', 'Status'];

    final rows = isSummarized
        ? provider.summarizedRows.map((r) => [r.srlNo, r.employeeName, r.empId, r.totalDays, r.presentDays, r.lateDays, r.absentDays]).toList()
        : provider.filteredRows.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final r = entry.value;
      return [
        idx,
        _formatDateStr(r.date),
        _formatTime12(r.timeIn),
        _formatTime12(r.timeOut),
        r.empId,
        r.employeeName,
        r.departmentName,
        r.dutyShiftName,
        r.machineCode,
        r.status,
      ];
    }).toList();

    final csvString = [
      headers.join(','),
      ...rows.map((row) => row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(',')),
    ].join('\n');

    await Printing.sharePdf(
      bytes: Uint8List.fromList(csvString.codeUnits),
      filename: 'payroll_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }

  // ── PDF Export Function ──────────────────────────────────────────────────
  Future<void> _handlePrintPdf(BuildContext context) async {
    final provider = context.read<PayrollReportProvider>();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context pdfContext) {
          return [
            pw.Text('Payroll Attendance Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Total Attendance Records: ${provider.totalRecords}'),
            pw.SizedBox(height: 10),
            if (provider.summarized)
              pw.TableHelper.fromTextArray(
                headers: ['Sr #', 'Emp ID', 'Employee Name', 'Total Days', 'Present', 'Late', 'Absent'],
                data: provider.summarizedRows.map((r) => [
                  r.srlNo.toString(),
                  r.empId,
                  r.employeeName,
                  r.totalDays.toString(),
                  r.presentDays.toString(),
                  r.lateDays.toString(),
                  r.absentDays.toString(),
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Sr #', 'Date', 'Time In', 'Time Out', 'Emp ID', 'Employee Name', 'Department', 'Shift', 'Machine Code', 'Status'],
                data: provider.filteredRows.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value;
                  return [
                    idx.toString(),
                    _formatDateStr(r.date),
                    _formatTime12(r.timeIn),
                    _formatTime12(r.timeOut),
                    r.empId,
                    r.employeeName,
                    r.departmentName,
                    r.dutyShiftName,
                    r.machineCode,
                    r.status,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'payroll_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  Color _monthlyStatusColor(String? code) {
    switch (code) {
      case 'P': return Colors.green.shade700;
      case 'A': return Colors.red.shade700;
      case 'H': return Colors.orange.shade800;
      case 'L': return Colors.lightBlue.shade700;
      case '*': return Colors.deepPurple.shade700;
      case 'O': return Colors.blueGrey.shade600;
      default: return Colors.grey.shade400;
    }
  }

  Future<void> _handleMonthlyExport(BuildContext context) async {
    final provider = context.read<PayrollReportProvider>();
    final dayCount = DateTime(provider.selectedYear, provider.selectedMonth + 1, 0).day;
    final rows = provider.monthlyRows.map((employee) => [
      employee.empId, employee.employeeName, employee.departmentName,
      ...List.generate(dayCount, (index) => employee.days[index + 1] ?? ''), employee.present, employee.absent,
    ]).toList();
    final csv = [
      ['Emp ID', 'Employee', 'Department', ...List.generate(dayCount, (index) => '${index + 1}'), 'Present', 'Absent'].join(','),
      ...rows.map((row) => row.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(',')),
    ].join('\n');
    await Printing.sharePdf(bytes: Uint8List.fromList(csv.codeUnits), filename: 'monthly_attendance.csv');
  }

  Future<void> _handleMonthlyPrint(BuildContext context) async {
    final provider = context.read<PayrollReportProvider>();
    final dayCount = DateTime(provider.selectedYear, provider.selectedMonth + 1, 0).day;
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (_) => [
      pw.Text('Monthly Attendance Sheet', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: ['Employee', ...List.generate(dayCount, (index) => '${index + 1}'), 'P', 'A'],
        data: provider.monthlyRows.map((employee) => [employee.employeeName, ...List.generate(dayCount, (index) => employee.days[index + 1] ?? ''), employee.present.toString(), employee.absent.toString()]).toList(),
        cellStyle: const pw.TextStyle(fontSize: 7),
        headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      ),
    ]));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'monthly_attendance.pdf');
  }

  Future<void> _handleSalaryExport(BuildContext context) async {
    final provider = context.read<PayrollReportProvider>();
    final query = _searchCtrl.text.trim().toLowerCase();
    final lines = provider.salaryLines.where((line) => query.isEmpty || [line.employeeName, line.employeeCode, line.departmentName, line.designation].any((value) => value.toLowerCase().contains(query))).toList();
    final csv = [
      ['Emp ID', 'Employee', 'Designation', 'Present', 'Absent', 'Lates', 'Basic', 'HRA', 'Medical', 'Conveyance', 'Overtime', 'Gross', 'Absent Ded.', 'Late Ded.', 'EOBI', 'Tax', 'Deductions', 'Net Payable'].join(','),
      ...lines.map((line) => [line.employeeCode, line.employeeName, line.designation, line.presentDays, line.absentDays, line.lateCount, line.basicSalary, line.houseRentAllowance, line.medicalAllowance, line.conveyanceAllowance, line.overtimeAmount, line.grossEarnings, line.absentDeduction, line.lateDeduction, line.eobiDeduction, line.incomeTax, line.totalDeductions, line.netPayable].map((cell) => '"$cell"').join(',')),
    ].join('\n');
    await Printing.sharePdf(bytes: Uint8List.fromList(csv.codeUnits), filename: 'salary_sheet.csv');
  }

  Future<void> _handleSalaryPrint(BuildContext context) async {
    final provider = context.read<PayrollReportProvider>();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (_) => [
      pw.Text('Monthly Salary Sheet', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: const ['Emp ID', 'Employee', 'Designation', 'P', 'A', 'L', 'Basic', 'Gross', 'Deductions', 'Net Payable'],
        data: provider.salaryLines.map((line) => [line.employeeCode, line.employeeName, line.designation, line.presentDays.toString(), line.absentDays.toString(), line.lateCount.toString(), _formatMoney(line.basicSalary), _formatMoney(line.grossEarnings), _formatMoney(line.totalDeductions), _formatMoney(line.netPayable)]).toList(),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    ]));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'salary_sheet.pdf');
  }

  // ── Table cell (unchanged sizing, header tone aligned to dashboard tables) ──
  Widget _cell(String text, double width, {bool isHeader = false, bool isBold = false, Color? color, TextAlign textAlign = TextAlign.left}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isHeader ? 9 : 11,
          fontWeight: isHeader ? FontWeight.w700 : (isBold ? FontWeight.w700 : FontWeight.normal),
          color: isHeader ? Colors.grey.shade400 : (color ?? const Color(0xFF334155)),
          letterSpacing: isHeader ? 0.6 : 0,
          fontFamily: isHeader ? null : 'monospace',
        ),
      ),
    );
  }

  // ── Card wrapper — matches dashboard's _buildGlassPanel styling ──────────
  Widget _buildDashboardCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _filterHeader(String title) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: _teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.filter_alt_outlined, color: _teal, size: 18),
      ),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    ]);
  }

  // ── Filter input styling aligned to dashboard's filter-bar chips ─────────
  InputDecoration _filterDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      prefixIcon: icon == null ? null : Icon(icon, size: 17, color: const Color(0xFFB0BEC5)),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _teal, width: 1.5)),
    );
  }

  ButtonStyle _smallButtonStyle({Color? background, Color? foreground}) {
    return OutlinedButton.styleFrom(
      backgroundColor: background ?? Colors.white,
      foregroundColor: foreground ?? const Color(0xFF334155),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildLoadMoreFooter(int total) {
    final loaded = _visibleCount.clamp(0, total);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $loaded of $total records',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
          if (loaded < total)
            TextButton(
              onPressed: () {
                setState(() {
                  _visibleCount = (_visibleCount + 12).clamp(12, total);
                });
              },
              child: const Text('Load More', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _teal)),
            )
          else
            Text('All loaded', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildLookupItems(List<PayrollLookupItem> list, String defaultLabel) {
    final seen = <String>{''};
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text(defaultLabel, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    ];
    for (final item in list) {
      if (item.id.isNotEmpty && !seen.contains(item.id)) {
        seen.add(item.id);
        items.add(DropdownMenuItem(
          value: item.id,
          child: Text(item.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
        ));
      }
    }
    return items;
  }

  String _getValidValue(List<DropdownMenuItem<String>> items, String desiredValue) {
    if (items.any((item) => item.value == desiredValue)) {
      return desiredValue;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayrollReportProvider>();
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 360;

    return BaseScaffold(
      title: 'Payroll Report',
      drawerIndex: 40,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Tab Switcher
            _buildTabSwitcher(provider),

            Expanded(
              child: Container(
                color: const Color(0xFFF8F9FA),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isCompact ? 10 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (provider.activeTab == 'register') _buildDailyRegisterTab(context, provider),
                      if (provider.activeTab == 'employeewise') _buildEmployeewiseTab(context, provider),
                      if (provider.activeTab == 'monthly') _buildMonthlyTab(context, provider),
                      if (provider.activeTab == 'salary-sheet') _buildSalarySheetTab(context, provider),
                      if (provider.activeTab == 'salary-slip') _buildSalarySlipTab(context, provider),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(PayrollReportProvider provider) {
    final tabs = [
      {'id': 'register', 'label': 'Daily Register', 'icon': Icons.assignment_outlined},
      {'id': 'employeewise', 'label': 'Employeewise', 'icon': Icons.person_search_outlined},
      {'id': 'monthly', 'label': 'Monthly', 'icon': Icons.calendar_month_outlined},
      {'id': 'salary-sheet', 'label': 'Salary Sheet', 'icon': Icons.payments_outlined},
      {'id': 'salary-slip', 'label': 'Salary Slip', 'icon': Icons.receipt_long_outlined},
    ];

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = provider.activeTab == tab['id'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: InkWell(
              onTap: () {
                provider.setActiveTab(tab['id'] as String);
                setState(() => _visibleCount = 12);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? _teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [BoxShadow(color: _teal.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(tab['icon'] as IconData, size: 16, color: isSelected ? Colors.white : const Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyRegisterTab(BuildContext context, PayrollReportProvider provider) {
    final empItems = _buildLookupItems(provider.employees, 'All Emps');
    final selectedEmp = _getValidValue(empItems, provider.selectedEmployee);

    final shiftItems = _buildLookupItems(provider.shifts, 'All Shifts');
    final selectedShift = _getValidValue(shiftItems, provider.selectedShift);

    final totalItems = provider.summarized ? provider.summarizedRows.length : provider.filteredRows.length;
    final visibleCount = _visibleCount.clamp(0, totalItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Filters Card
        _buildDashboardCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // _filterHeader('Daily Register Filters'),
                const SizedBox(height: 12),

                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => provider.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search ID, name, machine...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, color: _teal, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _teal, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 10),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.8,
                  children: [
                    OutlinedButton.icon(
                      style: _smallButtonStyle(),
                      onPressed: () => _pickDate(context, true),
                      icon: const Icon(Icons.calendar_today, size: 14, color: _teal),
                      label: Text(provider.dateFrom, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    ),
                    OutlinedButton.icon(
                      style: _smallButtonStyle(),
                      onPressed: () => _pickDate(context, false),
                      icon: const Icon(Icons.calendar_today, size: 14, color: _teal),
                      label: Text(provider.dateTo, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width < 700 ? 2 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.8,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedEmp,
                      isExpanded: true,
                      decoration: _filterDecoration('Employee'),
                      items: empItems,
                      onChanged: (v) { provider.setSelectedEmployee(v ?? ''); provider.fetchReport(); },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedShift,
                      isExpanded: true,
                      decoration: _filterDecoration('Shift'),
                      items: shiftItems,
                      onChanged: (v) { provider.setSelectedShift(v ?? ''); provider.fetchReport(); },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: provider.summarized ? _teal : _teal.withValues(alpha: 0.1),
                          foregroundColor: provider.summarized ? Colors.white : _teal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => provider.setSummarized(!provider.summarized),
                        icon: const Icon(Icons.compress, size: 16),
                        label: const Text('Summarize', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _smallButtonStyle(),
                        onPressed: () => _handleExportCSV(context),
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('CSV', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _smallButtonStyle(),
                        onPressed: () => _handlePrintPdf(context),
                        icon: const Icon(Icons.print, size: 14),
                        label: const Text('Print', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        provider.clearFilters();
                        setState(() => _visibleCount = 12);
                      },
                      child: const Text('Clear', style: TextStyle(color: Color(0xFFE11D48), fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Stats Row
        if (provider.isFilterApplied)
          Row(
            children: [
              _buildSimpleStatCard('Total Records', provider.totalRecords.toString(), const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Employees', provider.uniqueEmployees.toString(), const Color(0xFF0D9488)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Departments', provider.uniqueDepartments.toString(), const Color(0xFFC2410C)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Shifts', provider.uniqueShifts.toString(), const Color(0xFF7C3AED)),
            ],
          ),

        const SizedBox(height: 16),

        // 3. Data Table
        if (!provider.isFilterApplied)
          _buildInitialState()
        else if (provider.isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CustomLoader(size: 40, color: _teal)))
        else if (totalItems == 0)
            _buildEmptyState()
          else
            _buildDashboardCard(
              child: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    _buildStickyHeader(provider),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _tableVertCtrl,
                        child: SingleChildScrollView(
                          controller: _tableHorizCtrl,
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: provider.summarized
                                ? provider.summarizedRows.take(visibleCount).map((r) => _buildSummaryRow(r)).toList()
                                : provider.filteredRows.asMap().entries.take(visibleCount).map((e) => _buildAttendanceRow(e.value, e.key + 1)).toList(),
                          ),
                        ),
                      ),
                    ),
                    _buildLoadMoreFooter(totalItems),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  // ── Stat card — restyled to match dashboard's compact _StatCard look ─────
  Widget _buildSimpleStatCard(String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDF2F7)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1.5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                fontFamily: 'monospace',
                letterSpacing: -0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return _buildDashboardCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.filter_list_alt, color: Colors.grey.shade300, size: 20),
              ),
              const SizedBox(height: 8),
              Text('Apply filters or search to load report',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
              const SizedBox(height: 3),
              Text('Use the search bar or date filters above',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildDashboardCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.inbox_rounded, color: Colors.grey.shade300, size: 20),
              ),
              const SizedBox(height: 8),
              Text('No records found', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyHeader(PayrollReportProvider provider) {
    return SingleChildScrollView(
      controller: _headerHorizCtrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        width: provider.summarized ? 700 : 980,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ...provider.summarized
                    ? [
                  _cell('Sr.', 50, isHeader: true),
                  _cell('Employee Name', 160, isHeader: true),
                  _cell('Emp ID', 90, isHeader: true),
                  _cell('Dept', 120, isHeader: true),
                  _cell('Shift', 100, isHeader: true),
                  _cell('Records', 80, isHeader: true, textAlign: TextAlign.center),
                ]
                    : [
                  _cell('Sr.', 50, isHeader: true),
                  _cell('Date', 100, isHeader: true),
                  _cell('Time In', 85, isHeader: true),
                  _cell('Time Out', 85, isHeader: true),
                  _cell('Emp ID', 90, isHeader: true),
                  _cell('Employee Name', 150, isHeader: true),
                  _cell('Department', 130, isHeader: true),
                  _cell('Shift', 100, isHeader: true),
                  _cell('Machine', 100, isHeader: true),
                ],
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => provider.setDateSortOrder(provider.dateSortOrder == 'desc' ? 'asc' : 'desc'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(provider.dateSortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward, size: 11, color: _teal),
                        const SizedBox(width: 3),
                        Text(provider.dateSortOrder == 'desc' ? 'Desc' : 'Asc', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRow(PayrollAttendanceRow r, int index) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC)))),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          _cell(index.toString(), 50),
          _cell(_formatDateStr(r.date), 100),
          _cell(_formatTime12(r.timeIn), 85),
          _cell(_formatTime12(r.timeOut), 85),
          _cell(r.empId, 90),
          _cell(r.employeeName, 150),
          _cell(r.departmentName, 130),
          _cell(r.dutyShiftName, 100),
          _cell(r.machineCode, 100),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(PayrollReportSummaryRow r) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC)))),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          _cell(r.srlNo.toString(), 50),
          _cell(r.employeeName, 160),
          _cell(r.empId, 90),
          _cell('-', 120), // summary lookup for dept/shift needed
          _cell('-', 100),
          _cell(r.totalDays.toString(), 80, textAlign: TextAlign.center),
          _cell(r.presentDays.toString(), 80, color: const Color(0xFF0D9488), textAlign: TextAlign.center),
          _cell(r.lateDays.toString(), 80, color: const Color(0xFFB45309), textAlign: TextAlign.center),
          _cell(r.absentDays.toString(), 80, color: const Color(0xFFE11D48), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmployeewiseTab(BuildContext context, PayrollReportProvider provider) {
    final totalItems = provider.filteredEmployeewiseRows.length;
    final visibleCount = _visibleCount.clamp(0, totalItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Filters Card
        _buildDashboardCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterHeader('Employeewise Filters'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.8,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => provider.setSearchQuery(val),
                      decoration: _filterDecoration('Search', icon: Icons.search),
                    ),
                    OutlinedButton.icon(style: _smallButtonStyle(), onPressed: () => _pickDate(context, true), icon: const Icon(Icons.calendar_today, size: 14, color: _teal), label: Text(provider.dateFrom, style: const TextStyle(fontSize: 11))),
                    OutlinedButton.icon(style: _smallButtonStyle(), onPressed: () => _pickDate(context, false), icon: const Icon(Icons.calendar_today, size: 14, color: _teal), label: Text(provider.dateTo, style: const TextStyle(fontSize: 11))),
                    OutlinedButton.icon(style: _smallButtonStyle(), onPressed: () => _handleExportCSV(context), icon: const Icon(Icons.download, size: 14), label: const Text('CSV', style: TextStyle(fontSize: 11))),
                    OutlinedButton.icon(style: _smallButtonStyle(), onPressed: () => _handlePrintPdf(context), icon: const Icon(Icons.print, size: 14), label: const Text('Print', style: TextStyle(fontSize: 11))),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Stats Row
        if (provider.isFilterApplied)
          Row(
            children: [
              _buildSimpleStatCard('Employees', totalItems.toString(), const Color(0xFF334155)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Present Days', provider.totalPresentDays.toStringAsFixed(1), const Color(0xFF0D9488)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Absent Days', provider.totalAbsentDays.toString(), const Color(0xFFE11D48)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Overtime', _formatMinutes(provider.totalOvertimeMinutes), const Color(0xFFC2410C)),
            ],
          ),

        const SizedBox(height: 16),

        // 3. Data Table
        if (!provider.isFilterApplied)
          _buildInitialState()
        else if (provider.isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CustomLoader(size: 40, color: _teal)))
        else if (totalItems == 0)
            _buildEmptyState()
          else
            _buildDashboardCard(
              child: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    _buildStickyHeaderEmployeewise(),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _tableVertCtrl,
                        child: SingleChildScrollView(
                          controller: _tableHorizCtrl,
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: provider.filteredEmployeewiseRows.take(visibleCount).map((r) => _buildEmployeewiseRow(r)).toList(),
                          ),
                        ),
                      ),
                    ),
                    _buildLoadMoreFooter(totalItems),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildStickyHeaderEmployeewise() {
    return SingleChildScrollView(
      controller: _headerHorizCtrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            _cell('Emp ID', 90, isHeader: true),
            _cell('Employee', 150, isHeader: true),
            _cell('Code', 70, isHeader: true),
            _cell('Dept', 120, isHeader: true),
            _cell('Present', 70, isHeader: true, textAlign: TextAlign.center),
            _cell('Absent', 70, isHeader: true, textAlign: TextAlign.center),
            _cell('Half', 60, isHeader: true, textAlign: TextAlign.center),
            _cell('Leave', 60, isHeader: true, textAlign: TextAlign.center),
            _cell('Holiday', 70, isHeader: true, textAlign: TextAlign.center),
            _cell('Off', 60, isHeader: true, textAlign: TextAlign.center),
            _cell('Lates', 60, isHeader: true, textAlign: TextAlign.center),
            _cell('Late (m)', 80, isHeader: true, textAlign: TextAlign.center),
            _cell('Early (m)', 80, isHeader: true, textAlign: TextAlign.center),
            _cell('OT (m)', 80, isHeader: true, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeewiseRow(EmployeewiseAttendanceRow r) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC)))),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          _cell(r.empId, 90),
          _cell(r.employeeName, 150),
          _cell(r.employeeMachineCode, 70),
          _cell(r.departmentName, 120),
          _cell(r.presentDays.toStringAsFixed(1), 70, textAlign: TextAlign.center),
          _cell(r.absentDays.toString(), 70, textAlign: TextAlign.center),
          _cell(r.halfDays.toString(), 60, textAlign: TextAlign.center),
          _cell(r.leaveDays.toString(), 60, textAlign: TextAlign.center),
          _cell(r.holidayDays.toString(), 70, textAlign: TextAlign.center),
          _cell(r.weeklyOffDays.toString(), 60, textAlign: TextAlign.center),
          _cell(r.lateCount.toString(), 60, textAlign: TextAlign.center),
          _cell(r.lateMinutes.toString(), 80, textAlign: TextAlign.center),
          _cell(r.earlyMinutes.toString(), 80, textAlign: TextAlign.center),
          _cell(r.overtimeMinutes.toString(), 80, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab(BuildContext context, PayrollReportProvider provider) {
    final media = MediaQuery.of(context);
    final compact = media.size.width < 600;
    final dayCount = DateTime(provider.selectedYear, provider.selectedMonth + 1, 0).day;
    final days = List<int>.generate(dayCount, (index) => index + 1);
    const codes = {'P': 'Present', 'A': 'Absent', 'H': 'Half Day', 'L': 'Leave', '*': 'Holiday', 'O': 'Weekly Off'};
    final years = List<int>.generate(7, (index) => DateTime.now().year - 3 + index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboardCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterHeader('Monthly Attendance Filters'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: compact ? 2 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: compact ? 2.8 : 3.8,
                  children: [
                    DropdownButtonFormField<int>(
                      value: provider.selectedMonth,
                      isExpanded: true,
                      decoration: _filterDecoration('Month'),
                      items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(DateFormat('MMMM').format(DateTime(2024, index + 1)), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                      onChanged: (value) {
                        if (value != null) { provider.setSelectedMonth(value); provider.fetchReport(); }
                      },
                    ),
                    DropdownButtonFormField<int>(
                      value: years.contains(provider.selectedYear) ? provider.selectedYear : years.last,
                      isExpanded: true,
                      decoration: _filterDecoration('Year'),
                      items: years.map((value) => DropdownMenuItem(value: value, child: Text('$value', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (value) {
                        if (value != null) { provider.setSelectedYear(value); provider.fetchReport(); }
                      },
                    ),
                    OutlinedButton.icon(style: _smallButtonStyle(), onPressed: () => _handleMonthlyExport(context), icon: const Icon(Icons.download, size: 14), label: const Text('CSV', style: TextStyle(fontSize: 11))),
                    OutlinedButton.icon(style: _smallButtonStyle(), onPressed: () => _handleMonthlyPrint(context), icon: const Icon(Icons.print, size: 14), label: const Text('Print', style: TextStyle(fontSize: 11))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: codes.entries.map((entry) => Chip(
            label: Text('${entry.key} = ${entry.value}', style: TextStyle(fontSize: 10, color: _monthlyStatusColor(entry.key))),
            backgroundColor: _monthlyStatusColor(entry.key).withValues(alpha: 0.1),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
          )).toList(),
        ),
        const SizedBox(height: 16),
        _buildDashboardCard(
          child: SizedBox(
            height: media.size.height < 700 ? 420 : 520,
            child: provider.isLoading
                ? const Center(child: CustomLoader(size: 40, color: _teal))
                : provider.monthlyRows.isEmpty
                ? Center(child: Text('No attendance for ${DateFormat('MMMM').format(DateTime(2024, provider.selectedMonth))} ${provider.selectedYear}.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)))
                : Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
                    columnSpacing: compact ? 8 : 14,
                    dataRowMinHeight: 34,
                    dataRowMaxHeight: 38,
                    columns: [
                      const DataColumn(label: Text('Employee', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey))),
                      ...days.map((day) => DataColumn(label: Text('$day', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)))),
                      const DataColumn(label: Text('P', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey))),
                      const DataColumn(label: Text('A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey))),
                    ],
                    rows: provider.monthlyRows.map((employee) => DataRow(cells: [
                      DataCell(SizedBox(width: compact ? 145 : 190, child: Text('${employee.empId}  ${employee.employeeName}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))))),
                      ...days.map((day) => DataCell(Text(employee.days[day] ?? '·', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _monthlyStatusColor(employee.days[day]))))),
                      DataCell(Text(employee.present.toStringAsFixed(employee.present % 1 == 0 ? 0 : 1), style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w700))),
                      DataCell(Text('${employee.absent}', style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w700))),
                    ])).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalarySheetTab(BuildContext context, PayrollReportProvider provider) {
    final run = provider.currentRun;
    final lines = provider.salaryLines;
    final query = _searchCtrl.text.trim().toLowerCase();
    final displayedLines = query.isEmpty ? lines : lines.where((line) => [line.employeeName, line.employeeCode, line.departmentName, line.designation].any((value) => value.toLowerCase().contains(query))).toList();
    final stats = _calculateSalaryStats(displayedLines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Filters Card
        _buildDashboardCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterHeader('Salary Sheet Filters'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width < 700 ? 2 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.8,
                  children: [
                    DropdownButtonFormField<int>(
                      value: provider.selectedMonth,
                      isExpanded: true,
                      decoration: _filterDecoration('Month'),
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM').format(DateTime(2024, i + 1)), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                      onChanged: (v) => provider.setSelectedMonth(v ?? 1),
                    ),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: _filterDecoration('Year'),
                      controller: TextEditingController(text: provider.selectedYear.toString()),
                      onChanged: (v) => provider.setSelectedYear(int.tryParse(v) ?? 2024),
                    ),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: _filterDecoration('Search employee', icon: Icons.search),
                    ),
                    ElevatedButton.icon(onPressed: () => provider.generatePayroll(), icon: const Icon(Icons.play_arrow, size: 14), label: Text(run == null ? 'Generate' : 'Regenerate', style: const TextStyle(fontSize: 11)), style: _smallButtonStyle(background: _teal, foreground: Colors.white)),
                    if (run != null && run.status != 'Finalized') ElevatedButton.icon(onPressed: () => provider.finalizePayroll(run.id), icon: const Icon(Icons.lock, size: 14), label: const Text('Finalise', style: TextStyle(fontSize: 11)), style: _smallButtonStyle(background: const Color(0xFF7C3AED), foreground: Colors.white)),
                    OutlinedButton.icon(style: _smallButtonStyle(), onPressed: () => _handleSalaryExport(context), icon: const Icon(Icons.download, size: 14), label: const Text('CSV', style: TextStyle(fontSize: 11))),
                    OutlinedButton.icon(style: _smallButtonStyle(), onPressed: () => _handleSalaryPrint(context), icon: const Icon(Icons.print, size: 14), label: const Text('Print', style: TextStyle(fontSize: 11))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (run != null && run.status != 'Finalized') ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => provider.deletePayroll(run.id),
                        icon: const Icon(Icons.delete_forever, size: 16),
                        label: const Text('Delete', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                if (run != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      run.status == 'Finalized'
                          ? 'Finalized. Figures are locked.'
                          : 'Draft. Regenerate freely until finalized.',
                      style: TextStyle(fontSize: 11, color: run.status == 'Finalized' ? const Color(0xFF7C3AED) : const Color(0xFFC2410C), fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Stats Row
        if (provider.isFilterApplied && run != null)
          Row(
            children: [
              _buildSimpleStatCard('Employees', displayedLines.length.toString(), const Color(0xFF334155)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Gross', _formatMoney(stats['gross']!), const Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Deductions', _formatMoney(stats['deductions']!), const Color(0xFFE11D48)),
              const SizedBox(width: 8),
              _buildSimpleStatCard('Net Payable', _formatMoney(stats['net']!), const Color(0xFF0D9488)),
            ],
          ),

        const SizedBox(height: 16),

        // 3. Table
        if (!provider.isFilterApplied)
          _buildInitialState()
        else if (provider.isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CustomLoader(size: 40, color: _teal)))
        else if (run == null)
            _buildDashboardCard(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: Text('No payroll run found for this period.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))),
              ),
            )
          else
            _buildDashboardCard(
              child: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    _buildStickyHeaderSalarySheet(),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _tableVertCtrl,
                        child: SingleChildScrollView(
                          controller: _tableHorizCtrl,
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: displayedLines.map((l) => _buildSalaryLineRow(context, provider, l)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Map<String, double> _calculateSalaryStats(List<SalarySheetLine> lines) {
    double gross = 0;
    double deductions = 0;
    double net = 0;
    for (var l in lines) {
      gross += l.grossEarnings;
      deductions += l.totalDeductions;
      net += l.netPayable;
    }
    return {'gross': gross, 'deductions': deductions, 'net': net};
  }

  Widget _buildStickyHeaderSalarySheet() {
    return SingleChildScrollView(
      controller: _headerHorizCtrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            _cell('Emp ID', 65, isHeader: true), _cell('Employee', 115, isHeader: true), _cell('Desig.', 90, isHeader: true),
            _cell('P', 30, isHeader: true, textAlign: TextAlign.center), _cell('A', 30, isHeader: true, textAlign: TextAlign.center), _cell('L', 30, isHeader: true, textAlign: TextAlign.center),
            _cell('Basic', 75, isHeader: true, textAlign: TextAlign.right), _cell('HRA', 75, isHeader: true, textAlign: TextAlign.right), _cell('Medical', 75, isHeader: true, textAlign: TextAlign.right),
            _cell('Convey.', 75, isHeader: true, textAlign: TextAlign.right), _cell('OT', 70, isHeader: true, textAlign: TextAlign.right), _cell('Gross', 80, isHeader: true, textAlign: TextAlign.right),
            _cell('Absent Ded.', 80, isHeader: true, textAlign: TextAlign.right), _cell('Late Ded.', 75, isHeader: true, textAlign: TextAlign.right), _cell('EOBI', 65, isHeader: true, textAlign: TextAlign.right),
            _cell('Tax', 65, isHeader: true, textAlign: TextAlign.right), _cell('Deductions', 80, isHeader: true, textAlign: TextAlign.right), _cell('Net', 85, isHeader: true, textAlign: TextAlign.right), _cell('Slip', 45, isHeader: true, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryLineRow(BuildContext context, PayrollReportProvider provider, SalarySheetLine l) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC)))),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          _cell(l.employeeCode, 65), _cell(l.employeeName, 115), _cell(l.designation, 90),
          _cell(l.presentDays.toString(), 30, textAlign: TextAlign.center), _cell(l.absentDays.toString(), 30, textAlign: TextAlign.center), _cell(l.lateCount.toString(), 30, textAlign: TextAlign.center),
          _cell(_formatMoney(l.basicSalary), 75, textAlign: TextAlign.right), _cell(_formatMoney(l.houseRentAllowance), 75, textAlign: TextAlign.right), _cell(_formatMoney(l.medicalAllowance), 75, textAlign: TextAlign.right),
          _cell(_formatMoney(l.conveyanceAllowance), 75, textAlign: TextAlign.right), _cell(_formatMoney(l.overtimeAmount), 70, textAlign: TextAlign.right), _cell(_formatMoney(l.grossEarnings), 80, textAlign: TextAlign.right),
          _cell(_formatMoney(l.absentDeduction), 80, textAlign: TextAlign.right), _cell(_formatMoney(l.lateDeduction), 75, textAlign: TextAlign.right), _cell(_formatMoney(l.eobiDeduction), 65, textAlign: TextAlign.right),
          _cell(_formatMoney(l.incomeTax), 65, textAlign: TextAlign.right), _cell(_formatMoney(l.totalDeductions), 80, textAlign: TextAlign.right, color: const Color(0xFFE11D48)), _cell(_formatMoney(l.netPayable), 85, textAlign: TextAlign.right, color: const Color(0xFF0D9488), isBold: true),
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.receipt_long, size: 18, color: _teal),
              onPressed: () {
                provider.setActiveTab('salary-slip');
                provider.fetchSlip(provider.currentRun!.id, l.employeeSrlNo);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalarySlipFilters(BuildContext context, PayrollReportProvider provider) {
    final width = MediaQuery.of(context).size.width;
    final current = provider.currentSlip;
    return _buildDashboardCard(child: Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: width < 700 ? 2 : 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: width < 700 ? 3.2 : 4.2,
        children: [
          DropdownButtonFormField<dynamic>(
            value: provider.currentRun?.id,
            isExpanded: true,
            decoration: _filterDecoration('Payroll Period'),
            items: provider.runs.map((run) => DropdownMenuItem(value: run.id, child: Text('${run.periodMonth}/${run.periodYear} (${run.status})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)))).toList(),
            onChanged: (value) { if (value != null) provider.fetchPayrollRun(value); },
          ),
          DropdownButtonFormField<int>(
            isExpanded: true,
            decoration: _filterDecoration('Employee'),
            items: provider.salaryLines.map((line) => DropdownMenuItem(value: line.employeeSrlNo, child: Text('${line.employeeCode} - ${line.employeeName}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)))).toList(),
            onChanged: (value) { if (value != null && provider.currentRun != null) provider.fetchSlip(provider.currentRun!.id, value); },
          ),
          OutlinedButton.icon(style: _smallButtonStyle(), onPressed: current == null ? null : () => provider.fetchSlip(current['run']['id'], current['line']['employee_srl_no']), icon: const Icon(Icons.refresh, size: 14), label: const Text('Reload', style: TextStyle(fontSize: 11))),
          OutlinedButton.icon(style: _smallButtonStyle(), onPressed: current == null ? null : () => _printCurrentSlip(current), icon: const Icon(Icons.print, size: 14), label: const Text('Print', style: TextStyle(fontSize: 11))),
        ],
      ),
    ));
  }

  Widget _buildSalarySlipTab(BuildContext context, PayrollReportProvider provider) {
    final filters = _buildSalarySlipFilters(context, provider);
    if (provider.currentSlip == null && !provider.isLoading) {
      return Column(children: [
        filters,
        const SizedBox(height: 16),
        _buildDashboardCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('Choose a payroll period, then an employee.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ),
          ),
        ),
      ]);
    }
    if (provider.isLoading) return Column(children: [filters, const Padding(padding: EdgeInsets.all(40), child: CustomLoader(size: 40, color: _teal))]);

    final slip = provider.currentSlip!;
    final line = slip['line'] ?? {};
    final run = slip['run'] ?? {};
    final amount = (String key) => double.tryParse((line[key] ?? 0).toString()) ?? 0.0;
    final earnings = <MapEntry<String, String>>[
      const MapEntry('basic_salary', 'Basic Salary'), const MapEntry('house_rent_allowance', 'House Rent Allowance'),
      const MapEntry('medical_allowance', 'Medical Allowance'), const MapEntry('conveyance_allowance', 'Conveyance Allowance'),
      const MapEntry('other_allowance', 'Other Allowance'), const MapEntry('overtime_amount', 'Overtime'),
    ].where((item) => amount(item.key) != 0).toList();
    final deductions = <MapEntry<String, String>>[
      const MapEntry('absent_deduction', 'Absence'), const MapEntry('late_deduction', 'Late Marks'),
      const MapEntry('eobi_deduction', 'EOBI'), const MapEntry('income_tax', 'Income Tax'),
      const MapEntry('advance_deduction', 'Advance'), const MapEntry('other_deduction', 'Other'),
    ].where((item) => amount(item.key) != 0).toList();

    return Column(
      children: [
        filters,
        const SizedBox(height: 16),
        _buildDashboardCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line['employee_name'] ?? '-', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        Text('${line['employee_code']} · ${line['designation'] ?? '-'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: MediaQuery.of(context).size.width < 500 ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                      children: [
                        Text('${DateFormat('MMMM').format(DateTime(2024, run['period_month'] ?? 1))} ${run['period_year']}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10)),
                          child: Text(run['status'] ?? '-', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 30, color: Color(0xFFF1F5F9)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildSlipAmountColumn('Earnings', earnings, amount, const Color(0xFF0D9488))),
                    const SizedBox(width: 20),
                    Expanded(child: _buildSlipAmountColumn('Deductions', deductions, amount, const Color(0xFFE11D48))),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFF047857), borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('NET PAYABLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(_formatMoney(amount('net_payable')), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ]),
                ),
                if ((line['remarks'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(line['remarks'].toString(), style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)))),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _printSalarySlip(line, run, earnings, deductions, amount),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print Slip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _printCurrentSlip(Map<String, dynamic> slip) async {
    final line = slip['line'] as Map<String, dynamic>;
    final run = slip['run'] as Map<String, dynamic>;
    final amount = (String key) => double.tryParse((line[key] ?? 0).toString()) ?? 0.0;
    final earnings = <MapEntry<String, String>>[
      const MapEntry('basic_salary', 'Basic Salary'), const MapEntry('house_rent_allowance', 'House Rent Allowance'),
      const MapEntry('medical_allowance', 'Medical Allowance'), const MapEntry('conveyance_allowance', 'Conveyance Allowance'),
      const MapEntry('other_allowance', 'Other Allowance'), const MapEntry('overtime_amount', 'Overtime'),
    ].where((item) => amount(item.key) != 0).toList();
    final deductions = <MapEntry<String, String>>[
      const MapEntry('absent_deduction', 'Absence'), const MapEntry('late_deduction', 'Late Marks'),
      const MapEntry('eobi_deduction', 'EOBI'), const MapEntry('income_tax', 'Income Tax'),
      const MapEntry('advance_deduction', 'Advance'), const MapEntry('other_deduction', 'Other'),
    ].where((item) => amount(item.key) != 0).toList();
    await _printSalarySlip(line, run, earnings, deductions, amount);
  }

  Widget _buildSlipAmountColumn(String title, List<MapEntry<String, String>> items, double Function(String) amount, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
      const Divider(color: Color(0xFFF1F5F9)),
      ...items.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(item.value, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
        Text(_formatMoney(amount(item.key)), style: TextStyle(fontSize: 11, color: color, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      ]))),
      if (items.isEmpty) Text('None', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
    ]);
  }

  Future<void> _printSalarySlip(Map<String, dynamic> line, Map<String, dynamic> run, List<MapEntry<String, String>> earnings, List<MapEntry<String, String>> deductions, double Function(String) amount) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Salary Slip', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8), pw.Text('${line['employee_name'] ?? '-'} | ${line['employee_code'] ?? '-'}'),
      pw.Text('Period: ${run['period_month'] ?? '-'} / ${run['period_year'] ?? '-'}'), pw.SizedBox(height: 16),
      pw.Table.fromTextArray(headers: const ['Earnings', 'Amount', 'Deductions', 'Amount'], data: List.generate(earnings.length > deductions.length ? earnings.length : deductions.length, (index) => [
        index < earnings.length ? earnings[index].value : '', index < earnings.length ? _formatMoney(amount(earnings[index].key)) : '',
        index < deductions.length ? deductions[index].value : '', index < deductions.length ? _formatMoney(amount(deductions[index].key)) : '',
      ])),
      pw.SizedBox(height: 12), pw.Text('Gross Earnings: ${_formatMoney(amount('gross_earnings'))}'),
      pw.Text('Total Deductions: ${_formatMoney(amount('total_deductions'))}'),
      pw.Text('Net Payable: ${_formatMoney(amount('net_payable'))}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
    ])));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'salary_slip.pdf');
  }
}