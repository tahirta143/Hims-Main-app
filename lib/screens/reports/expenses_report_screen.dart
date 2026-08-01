import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/reports/expenses_report_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class ExpensesReportScreen extends StatefulWidget {
  const ExpensesReportScreen({super.key});

  @override
  State<ExpensesReportScreen> createState() => _ExpensesReportScreenState();
}

class _ExpensesReportScreenState extends State<ExpensesReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableVertCtrl = ScrollController();
  final ScrollController _tableHorizCtrl = ScrollController();
  final ScrollController _headerHorizCtrl = ScrollController();

  int _visibleCount = 10;

  @override
  void initState() {
    super.initState();
    _tableVertCtrl.addListener(_onTableScroll);
    _tableHorizCtrl.addListener(_syncHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpensesReportProvider>().fetchReport();
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
    if (_tableVertCtrl.hasClients) {
      if (_tableVertCtrl.position.pixels >= _tableVertCtrl.position.maxScrollExtent - 80) {
        final total = context.read<ExpensesReportProvider>().filteredExpenses.length;
        if (_visibleCount < total) {
          setState(() {
            _visibleCount = (_visibleCount + 10).clamp(10, total);
          });
        }
      }
    }
  }

  String _formatMoney(double val) {
    return 'PKR ${NumberFormat('#,##0').format(val)}';
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final provider = context.read<ExpensesReportProvider>();
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
        if (provider.dateTo.isEmpty) {
          provider.setDateTo(formatted);
        }
      } else {
        provider.setDateTo(formatted);
      }
      setState(() => _visibleCount = 10);
      provider.fetchReport();
    }
  }

  // ── CSV Export Function ──────────────────────────────────────────────────
  Future<void> _handleExportCSV(BuildContext context) async {
    final provider = context.read<ExpensesReportProvider>();
    final items = provider.filteredExpenses;
    final isSummarized = provider.summarized;

    final List<String> headers = isSummarized
        ? ["Sr", "Expenses Name", "Combined Records", "Amount (PKR)"]
        : ["Sr", "Expenses Name", "Expenses Details", "Date", "Time", "Shift", "Amount (PKR)", "Recorded By"];

    final List<List<String>> rows = items.asMap().entries.map((entry) {
      final item = entry.value;
      final idx = entry.key + 1;
      if (isSummarized) {
        return [
          '$idx',
          item.expenseName,
          '${item.expenseCount}',
          item.expenseAmount.toStringAsFixed(2),
        ];
      } else {
        return [
          '$idx',
          item.expenseName,
          item.expenseDescription,
          item.expenseDate,
          item.expenseTime,
          item.expenseShift,
          item.expenseAmount.toStringAsFixed(2),
          item.expenseBy,
        ];
      }
    }).toList();

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Expenses Report CSV Export", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'expenses_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ── Print Function matching React generateExpensesReportHtml ───────────────
  Future<void> _handlePrint(BuildContext context) async {
    final provider = context.read<ExpensesReportProvider>();
    final items = provider.filteredExpenses;
    final isSummarized = provider.summarized;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Expenses Details Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      pw.Text("Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Filter summary box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.red200),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Date Range: ${provider.dateFrom.isEmpty ? 'All' : provider.dateFrom} - ${provider.dateTo.isEmpty ? 'All' : provider.dateTo}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Shift: ${provider.selectedShift.isEmpty ? 'All Shifts' : provider.selectedShift}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Records: ${items.length}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Total: PKR ${NumberFormat('#,##0').format(provider.totalExpenseAmount)}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Table
              pw.TableHelper.fromTextArray(
                headers: isSummarized
                    ? ["Sr", "Expenses Name", "Combined Records", "Amount (PKR)"]
                    : ["Sr", "Expenses Name", "Expenses Details", "Date", "Time", "Shift", "Amount (PKR)", "Recorded By"],
                data: items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  if (isSummarized) {
                    return [
                      '$idx',
                      item.expenseName,
                      '${item.expenseCount} records',
                      'PKR ${NumberFormat('#,##0').format(item.expenseAmount)}',
                    ];
                  } else {
                    return [
                      '$idx',
                      item.expenseName,
                      item.expenseDescription,
                      item.expenseDate,
                      item.expenseTime,
                      item.expenseShift,
                      'PKR ${NumberFormat('#,##0').format(item.expenseAmount)}',
                      item.expenseBy,
                    ];
                  }
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL (${items.length} items)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text("Total Expenses: PKR ${NumberFormat('#,##0').format(provider.totalExpenseAmount)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.red900)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  Widget _buildDashboardCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cell(String text, double width, {bool isHeader = false, bool isBold = false, Color? color, TextAlign textAlign = TextAlign.left}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? 12 : 13,
            fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? Colors.black87 : (color ?? Colors.black87),
          ),
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter(int totalItems) {
    if (totalItems <= 0) return const SizedBox.shrink();

    final isAllLoaded = _visibleCount >= totalItems;
    final currentShowing = _visibleCount.clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $currentShowing of $totalItems expenses',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          if (!isAllLoaded)
            InkWell(
              onTap: () {
                setState(() {
                  _visibleCount = (_visibleCount + 10).clamp(10, totalItems);
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: const [
                    Text('Load More (+10)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _teal)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_downward, size: 12, color: _teal),
                  ],
                ),
              ),
            )
          else
            const Text(
              'All loaded',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;

    final provider = context.watch<ExpensesReportProvider>();
    final items = provider.filteredExpenses;
    final totalItems = items.length;
    final visibleItems = items.take(_visibleCount).toList();

    return BaseScaffold(
      title: 'Expenses Report',
      drawerIndex: 30,
      body: RefreshIndicator(
        onRefresh: () => provider.fetchReport(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Card (Teal Gradient matching app theme)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 14 : 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_teal, Color(0xFF00897B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL EXPENSES',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${provider.totalExpenseCount} Record(s)',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatMoney(provider.totalExpenseAmount),
                      style: TextStyle(color: Colors.white, fontSize: isMobile ? 22 : 26, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filters Card (Structured in 2-Column Grid Rows)
              _buildDashboardCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FILTER EXPENSES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _teal, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 12),

                      // Row 1 (2 Columns Grid): Search & Date From
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) {
                                provider.setSearchQuery(val);
                                setState(() => _visibleCount = 10);
                              },
                              decoration: InputDecoration(
                                hintText: 'Search expense name, description, person...',
                                prefixIcon: const Icon(Icons.search, color: _teal, size: 18),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          provider.setSearchQuery('');
                                          setState(() => _visibleCount = 10);
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: () => _pickDate(context, true),
                              icon: const Icon(Icons.calendar_today, size: 14, color: _teal),
                              label: Text(
                                provider.dateFrom.isEmpty ? 'Date From' : provider.dateFrom,
                                style: TextStyle(fontSize: 11, color: provider.dateFrom.isEmpty ? Colors.grey : Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Row 2 (2 Columns Grid): Date To & Shift Dropdown
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: () => _pickDate(context, false),
                              icon: const Icon(Icons.calendar_today, size: 14, color: _teal),
                              label: Text(
                                provider.dateTo.isEmpty ? 'Date To' : provider.dateTo,
                                style: TextStyle(fontSize: 11, color: provider.dateTo.isEmpty ? Colors.grey : Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: provider.selectedShift.isEmpty ? '' : provider.selectedShift,
                              decoration: InputDecoration(
                                labelText: 'Shift',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: '', child: Text('All Shifts', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Morning', child: Text('Morning', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Evening', child: Text('Evening', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Night', child: Text('Night', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                provider.setSelectedShift(val ?? '');
                                setState(() => _visibleCount = 10);
                                provider.fetchReport();
                              },
                            ),
                          ),
                        ],
                      ),

                      // Row 3: Summarize Button (Shown ONLY when provider.hasActiveFilters is true!) & Clear Filters
                      if (provider.hasActiveFilters) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: provider.summarized ? _teal : _teal.withValues(alpha: 0.1),
                                  foregroundColor: provider.summarized ? Colors.white : _teal,
                                  elevation: provider.summarized ? 2 : 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  provider.setSummarized(!provider.summarized);
                                  setState(() => _visibleCount = 10);
                                },
                                icon: const Icon(Icons.compress_rounded, size: 16),
                                label: Text(
                                  provider.summarized ? 'Summarized' : 'Summarize Data',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            TextButton.icon(
                              onPressed: () {
                                _searchCtrl.clear();
                                provider.resetFilters();
                                setState(() => _visibleCount = 10);
                              },
                              icon: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                              label: const Text('Clear Filters', style: TextStyle(color: Colors.red, fontSize: 11)),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Row 4: Action Buttons Row (Refresh, Export CSV, Print)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => provider.fetchReport(),
                              icon: const Icon(Icons.refresh, size: 14, color: _teal),
                              label: const Text('Refresh', style: TextStyle(fontSize: 11, color: _teal)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _handleExportCSV(context),
                              icon: const Icon(Icons.download, size: 14),
                              label: const Text('Export CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF374151),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _handlePrint(context),
                              icon: const Icon(Icons.print, size: 14),
                              label: const Text('Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Data Table Container (Sticky Header + Internal Body Scroll)
              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CustomLoader(size: 46, color: _teal),
                )
              else if (provider.errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                )
              else if (items.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No expenses found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else
                _buildDashboardCard(
                  child: SizedBox(
                    height: 440,
                    child: Column(
                      children: [
                        // FIXED STICKY TABLE HEADER
                        SingleChildScrollView(
                          controller: _headerHorizCtrl,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _teal.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                topRight: Radius.circular(14),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              children: provider.summarized
                                  ? [
                                      _cell('S.No', 60, isHeader: true),
                                      _cell('Expense Name', 200, isHeader: true),
                                      _cell('Combined Records', 140, isHeader: true, textAlign: TextAlign.center),
                                      _cell('Amount', 140, isHeader: true, textAlign: TextAlign.right),
                                    ]
                                  : [
                                      _cell('S.No', 60, isHeader: true),
                                      _cell('Expense Name', 150, isHeader: true),
                                      _cell('Description', 180, isHeader: true),
                                      _cell('Date & Time', 150, isHeader: true),
                                      _cell('Shift', 100, isHeader: true),
                                      _cell('By', 120, isHeader: true),
                                      _cell('Amount', 120, isHeader: true, textAlign: TextAlign.right),
                                    ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),

                        // SCROLLABLE TABLE BODY
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _tableVertCtrl,
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              controller: _tableHorizCtrl,
                              scrollDirection: Axis.horizontal,
                              child: Column(
                                children: visibleItems.asMap().entries.map((entry) {
                                  final item = entry.value;
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    child: Row(
                                      children: provider.summarized
                                          ? [
                                              _cell('${entry.key + 1}', 60),
                                              _cell(item.expenseName, 200, isBold: true),
                                              SizedBox(
                                                width: 140,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _teal.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '${item.expenseCount} records',
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _teal),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _cell(_formatMoney(item.expenseAmount), 140, color: Colors.red, isBold: true, textAlign: TextAlign.right),
                                            ]
                                          : [
                                              _cell('${entry.key + 1}', 60),
                                              _cell(item.expenseName, 150, isBold: true),
                                              _cell(item.expenseDescription, 180),
                                              _cell('${item.expenseDate} ${item.expenseTime}'.trim(), 150),
                                              _cell(item.expenseShift, 100),
                                              _cell(item.expenseBy, 120),
                                              _cell(_formatMoney(item.expenseAmount), 120, color: Colors.red, isBold: true, textAlign: TextAlign.right),
                                            ],
                                    ),
                                  );
                                }).toList(),
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
          ),
        ),
      ),
    );
  }
}
