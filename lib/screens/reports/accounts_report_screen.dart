import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/reports/accounts_report_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class AccountsReportScreen extends StatefulWidget {
  const AccountsReportScreen({super.key});

  @override
  State<AccountsReportScreen> createState() => _AccountsReportScreenState();
}

class _AccountsReportScreenState extends State<AccountsReportScreen> {
  static const _pageSize = 10;
  final ScrollController _revenueScrollController = ScrollController();
  final ScrollController _expenseScrollController = ScrollController();
  int _revenueVisible = _pageSize;
  int _expenseVisible = _pageSize;

  @override
  void initState() {
    super.initState();
    _revenueScrollController.addListener(_loadMoreRevenue);
    _expenseScrollController.addListener(_loadMoreExpenses);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AccountsReportProvider>().fetchReport());
  }

  @override
  void dispose() {
    _revenueScrollController.removeListener(_loadMoreRevenue);
    _expenseScrollController.removeListener(_loadMoreExpenses);
    _revenueScrollController.dispose();
    _expenseScrollController.dispose();
    super.dispose();
  }

  void _loadMoreRevenue() {
    if (!_revenueScrollController.hasClients || _revenueVisible >= context.read<AccountsReportProvider>().revenueRows.length) return;
    if (_revenueScrollController.position.pixels >= _revenueScrollController.position.maxScrollExtent - 60) {
      setState(() => _revenueVisible += _pageSize);
    }
  }

  void _loadMoreExpenses() {
    if (!_expenseScrollController.hasClients || _expenseVisible >= context.read<AccountsReportProvider>().expenses.length) return;
    if (_expenseScrollController.position.pixels >= _expenseScrollController.position.maxScrollExtent - 60) {
      setState(() => _expenseVisible += _pageSize);
    }
  }

  String _money(double value) => 'PKR ${NumberFormat('#,##0.##').format(value)}';

  Future<void> _pickDate(BuildContext context, bool from) async {
    final provider = context.read<AccountsReportProvider>();
    final current = DateTime.tryParse(from ? provider.dateFrom : provider.dateTo) ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked == null) return;
    final value = DateFormat('yyyy-MM-dd').format(picked);
    if (from) provider.setDateFrom(value); else provider.setDateTo(value);
    setState(() {
      _revenueVisible = _pageSize;
      _expenseVisible = _pageSize;
    });
  }

  Future<void> _exportCsv(BuildContext context) async {
    final p = context.read<AccountsReportProvider>();
    final rows = <List<Object?>>[
      ['Day Book', p.rangeLabel], [], ['Revenue'], ['Sr.', 'Type', 'Service / Doctor', 'Qty', 'Total', 'Dr. Share', 'Hospital'],
      ...p.revenueRows.asMap().entries.map((e) => [e.key + 1, e.value.type, e.value.label, e.value.count, e.value.total, e.value.doctorShare, e.value.hospitalShare]),
      ['', '', 'Total', p.revenueCount, p.revenueTotal, p.doctorShare, p.hospitalShare], [], ['Cancelled'], ['Sr.', 'Type', 'Service / Doctor', 'Amount'],
      ...p.cancelledRows.asMap().entries.map((e) => [e.key + 1, e.value.type, e.value.label, e.value.amount]), [], ['Expenses'], ['Sr.', 'Date', 'Expense', 'Description', 'Amount'],
      ...p.expenses.asMap().entries.map((e) => [e.key + 1, e.value.date, e.value.name, e.value.description, e.value.amount]),
      ['', '', '', 'Total', p.expenseTotal],
    ];
    final csv = rows.map((row) => row.map((cell) => '"${cell ?? ''}"').join(',')).join('\n');
    await Printing.sharePdf(bytes: Uint8List.fromList(csv.codeUnits), filename: 'day-book-${p.dateFrom}_${p.dateTo}.csv');
  }

  Future<void> _print(BuildContext context) async {
    final p = context.read<AccountsReportProvider>();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (_) => [
      pw.Text('Day Book', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Date: ${p.rangeLabel}'), pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: const ['Sr.', 'Service / Doctor', 'Qty', 'Total', 'Dr. Share', 'Hospital'],
        data: p.revenueRows.asMap().entries.map((e) => [e.key + 1, '${e.value.label} (${e.value.type})', e.value.count, _money(e.value.total), _money(e.value.doctorShare), _money(e.value.hospitalShare)]).toList(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), cellStyle: const pw.TextStyle(fontSize: 8),
      ),
      pw.SizedBox(height: 12), pw.Text('Revenue: ${_money(p.revenueTotal)}   Doctor Share: ${_money(p.doctorShare)}   Hospital: ${_money(p.hospitalShare)}   Expenses: ${_money(p.expenseTotal)}'),
      pw.SizedBox(height: 12), pw.Text('Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.TableHelper.fromTextArray(
        headers: const ['Sr.', 'Date', 'Expense', 'Description', 'Amount'],
        data: p.expenses.asMap().entries.map((e) => [e.key + 1, e.value.date, e.value.name, e.value.description, _money(e.value.amount)]).toList(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), cellStyle: const pw.TextStyle(fontSize: 8),
      ),
    ]));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: 'day-book.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AccountsReportProvider>();
    final compact = MediaQuery.of(context).size.width < 650;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return BaseScaffold(
      title: 'Accounts Report', drawerIndex: 41,
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 24 + bottomInset + 70),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildFilters(context, p, compact), const SizedBox(height: 8),
            if (p.isLoading) const Padding(padding: EdgeInsets.all(50), child: Center(child: CustomLoader(size: 46, color: _teal)))
            else if (p.errorMessage != null) _errorState(p.errorMessage!)
            else ...[_buildSummary(p, compact), const SizedBox(height: 8), _buildRevenue(p), const SizedBox(height: 8), _buildExpenses(p)],
          ]),
        ),
      ),
    );
  }

  // ── Filters card — compact wrap-style chips, matches dashboard's filter bar ──
  Widget _buildFilters(BuildContext context, AccountsReportProvider p, bool compact) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _pickDate(context, true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(p.dateFrom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ]),
          ),
        ),
        GestureDetector(
          onTap: () => _pickDate(context, false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_available_rounded, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(p.dateTo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ]),
          ),
        ),
        GestureDetector(
          onTap: () => _exportCsv(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.download_rounded, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              const Text('CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ]),
          ),
        ),
        GestureDetector(
          onTap: () => _print(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.print_rounded, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              const Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ]),
          ),
        ),
      ],
    ),
  );

  // ── Summary stat cards — fixed-height rows instead of GridView aspect
  //    ratio. Aspect ratio depends on the cell WIDTH, which is unpredictable
  //    across screen sizes, and was forcing extra height → the big gap you
  //    saw between the cards and "Revenue". Fixed height removes that. ─────
  Widget _buildSummary(AccountsReportProvider p, bool compact) {
    final stats = [
      _stat('Total Revenue', _money(p.revenueTotal), const Color(0xFF047857)),
      _stat('Dr. Share', _money(p.doctorShare), const Color(0xFF4F46E5)),
      _stat('Expenses', _money(p.expenseTotal), const Color(0xFFE11D48)),
      _stat('Cancelled', '${p.cancelledRows.length} / ${_money(p.cancelledTotal)}', const Color(0xFFC2410C)),
    ];
    const cardHeight = 54.0;
    if (compact) {
      return Column(children: [
        SizedBox(
          height: cardHeight,
          child: Row(children: [
            Expanded(child: stats[0]),
            const SizedBox(width: 4),
            Expanded(child: stats[1]),
          ]),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: cardHeight,
          child: Row(children: [
            Expanded(child: stats[2]),
            const SizedBox(width: 4),
            Expanded(child: stats[3]),
          ]),
        ),
      ]);
    }
    return SizedBox(
      height: cardHeight,
      child: Row(children: [
        Expanded(child: stats[0]),
        const SizedBox(width: 4),
        Expanded(child: stats[1]),
        const SizedBox(width: 4),
        Expanded(child: stats[2]),
        const SizedBox(width: 4),
        Expanded(child: stats[3]),
      ]),
    );
  }

  // ── Generic sticky-header table built from plain Rows with FIXED pixel
  //    widths per column. Header and body share the exact same width list,
  //    so columns always line up — and widths are generous/readable instead
  //    of DataTable's cramped auto-sizing. Only ONE horizontal scroller
  //    wraps header+body together so they can never drift apart. ──────────
  Widget _stickyTable({
    required String title,
    required Color dotColor,
    required List<String> headers,
    required List<double> widths, // one width per column, same order as headers
    required List<List<String>> rows, // each inner list = cell text per column
    required List<List<Color>>? cellColors, // optional per-cell color, same shape as rows
    required List<bool> boldCols, // whether a column's text is bold, per column
    required ScrollController vController,
  }) {
    final totalWidth = widths.fold<double>(0, (a, b) => a + b) + 20; // + horizontal padding

    Widget headerRow() => Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(children: [
        for (var i = 0; i < headers.length; i++)
          SizedBox(
            width: widths[i],
            child: Text(
              headers[i],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
      ]),
    );

    Widget dataRow(int rowIndex) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(children: [
        for (var i = 0; i < headers.length; i++)
          SizedBox(
            width: widths[i],
            child: Text(
              rows[rowIndex][i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cellColors?[rowIndex][i] ?? const Color(0xFF334155),
                fontFamily: i == 0 ? 'monospace' : null,
              ),
            ),
          ),
      ]),
    );

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFF1F5F9)),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(children: [
            headerRow(),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            SizedBox(
              height: 300,
              child: rows.isEmpty
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No data', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              )
                  : ListView.builder(
                controller: vController,
                itemCount: rows.length,
                itemBuilder: (_, i) => dataRow(i),
              ),
            ),
          ]),
        ),
      ),
    ]));
  }

  Widget _buildRevenue(AccountsReportProvider p) {
    final source = p.revenueRows.take(_revenueVisible).toList();
    final rows = source.asMap().entries.map((e) => [
      '${e.key + 1}',
      e.value.type,
      e.value.label,
      '${e.value.count}',
      _money(e.value.total),
      _money(e.value.doctorShare),
      _money(e.value.hospitalShare),
    ]).toList();
    final colors = source
        .map((v) => [
      const Color(0xFF64748B),
      const Color(0xFF475569),
      const Color(0xFF334155),
      const Color(0xFF64748B),
      const Color(0xFF0F172A),
      const Color(0xFFE11D48),
      const Color(0xFF059669),
    ])
        .toList();

    return _stickyTable(
      title: 'Revenue',
      dotColor: const Color(0xFF4F46E5),
      headers: const ['Sr.', 'Type', 'Service / Doctor', 'Qty', 'Total', 'Dr. Share', 'Hospital'],
      widths: const [36, 70, 150, 46, 90, 90, 90],
      rows: rows,
      cellColors: colors,
      boldCols: const [false, false, true, false, true, true, true],
      vController: _revenueScrollController,
    );
  }

  Widget _buildExpenses(AccountsReportProvider p) {
    final source = p.expenses.take(_expenseVisible).toList();
    final rows = source.asMap().entries.map((e) => [
      '${e.key + 1}',
      e.value.date,
      e.value.name,
      e.value.description,
      _money(e.value.amount),
    ]).toList();
    final colors = source
        .map((v) => [
      const Color(0xFF64748B),
      const Color(0xFF334155),
      const Color(0xFF334155),
      const Color(0xFF64748B),
      const Color(0xFFC2410C),
    ])
        .toList();

    return _stickyTable(
      title: 'Expenses',
      dotColor: const Color(0xFFC2410C),
      headers: const ['Sr.', 'Date', 'Expense', 'Description', 'Amount'],
      widths: const [36, 90, 110, 160, 100],
      rows: rows,
      cellColors: colors,
      boldCols: const [false, false, true, false, true],
      vController: _expenseScrollController,
    );
  }

  // ── Stat mini-card — same visual language as dashboard's _StatCard ───────
  Widget _stat(String label, String value, Color color) => _card(Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.4),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace', letterSpacing: -0.3),
        overflow: TextOverflow.ellipsis,
      ),
    ]),
  ));

  Widget _errorState(String text) => _card(Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 20),
        ),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE11D48)), textAlign: TextAlign.center),
      ]),
    ),
  ));

  // ── Card wrapper — matches dashboard's _buildGlassPanel styling ──────────
  Widget _card(Widget child) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEDF2F7)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, 4)),
      ],
    ),
    child: child,
  );
}