import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/reports/lab_report_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class LabReportScreen extends StatefulWidget {
  const LabReportScreen({super.key});

  @override
  State<LabReportScreen> createState() => _LabReportScreenState();
}

class _LabReportScreenState extends State<LabReportScreen> {
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
    // Removed automatic fetchReport() to match React behavior:
    // Page starts empty until filters are applied.
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
        final total = context.read<LabReportProvider>().filteredTests.length;
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

  String _formatDateStr(String val) {
    if (val.isEmpty || val == '—') return val;
    final d = DateTime.tryParse(val);
    if (d == null) return val;
    return DateFormat('d MMM yyyy').format(d);
  }

  String _formatTime12(String val) {
    if (val.isEmpty || val == '—') return val;
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
    final provider = context.read<LabReportProvider>();
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
    final provider = context.read<LabReportProvider>();
    final items = provider.filteredTests;
    final isSummarized = provider.summarized;

    final List<String> headers = isSummarized
        ? ["Sr", "Test Name", "Combined Records", "Amount (PKR)", "Company Share (PKR)"]
        : ["Sr", "Date", "Time", "MR No", "Patient", "Service", "Detail", "Shift", "Amount (PKR)", "Company Share (PKR)"];

    final List<List<String>> rows = items.asMap().entries.map((entry) {
      final item = entry.value;
      final idx = entry.key + 1;
      if (isSummarized) {
        return [
          '$idx',
          item.serviceDetail,
          '${item.testCount}',
          item.testAmount.toStringAsFixed(2),
          item.companyShare.toStringAsFixed(2),
        ];
      } else {
        return [
          '$idx',
          _formatDateStr(item.testDate),
          _formatTime12(item.testTime),
          item.mrNumber,
          item.patientName,
          item.opdService,
          item.serviceDetail,
          item.shiftType,
          item.testAmount.toStringAsFixed(2),
          item.companyShare.toStringAsFixed(2),
        ];
      }
    }).toList();
    // ... remaining logic for CSV (PDF-based)

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Lab Report CSV Export", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
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
      name: 'lab_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ── Print Function matching React generateLabReportHtml ──────────────────
  Future<void> _handlePrint(BuildContext context) async {
    final provider = context.read<LabReportProvider>();
    final items = provider.filteredTests;
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
                      pw.Text("Lab Test Details Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
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
                  color: PdfColors.teal50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.teal200),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Date Range: ${provider.dateFrom.isEmpty ? 'All' : provider.dateFrom} - ${provider.dateTo.isEmpty ? 'All' : provider.dateTo}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Shift: ${provider.selectedShift.isEmpty ? 'All Shifts' : provider.selectedShift}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Records: ${items.length}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Total: PKR ${NumberFormat('#,##0').format(provider.totalTestAmount)}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Table
              pw.TableHelper.fromTextArray(
                headers: isSummarized
                    ? ["Sr", "Test Name", "Combined Records", "Amount (PKR)", "Company Share (PKR)"]
                    : ["Sr", "Date", "Time", "MR No", "Patient", "Service", "Detail", "Shift", "Amount (PKR)", "Company Share (PKR)"],
                data: items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  if (isSummarized) {
                    return [
                      '$idx',
                      item.serviceDetail,
                      '${item.testCount} records',
                      'PKR ${NumberFormat('#,##0').format(item.testAmount)}',
                      'PKR ${NumberFormat('#,##0').format(item.companyShare)}',
                    ];
                  } else {
                    return [
                      '$idx',
                      _formatDateStr(item.testDate),
                      _formatTime12(item.testTime),
                      item.mrNumber,
                      item.patientName,
                      item.opdService,
                      item.serviceDetail,
                      item.shiftType,
                      'PKR ${NumberFormat('#,##0').format(item.testAmount)}',
                      'PKR ${NumberFormat('#,##0').format(item.companyShare)}',
                    ];
                  }
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL (${items.length} items)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text("Revenue: PKR ${NumberFormat('#,##0').format(provider.totalTestAmount)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.green800)),
                  pw.Text("Share: PKR ${NumberFormat('#,##0').format(provider.totalCompanyShare)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.grey900)),
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
            'Showing $currentShowing of $totalItems tests',
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
    final isCompact = mediaQuery.size.width < 360;

    final provider = context.watch<LabReportProvider>();
    final items = provider.filteredTests;
    final totalItems = items.length;
    final visibleItems = items.take(_visibleCount).toList();

    return BaseScaffold(
      title: 'Lab Report',
      drawerIndex: 31,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.fetchReport(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isCompact ? 10 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Filters Card at the top
                _buildDashboardCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FILTER LAB REPORTS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _teal, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 12),

                        // Search input
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (val) {
                            provider.setSearchQuery(val);
                            setState(() => _visibleCount = 10);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search MR, patient, test, service...',
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

                        const SizedBox(height: 10),

                        // Date Pickers Row
                        Row(
                          children: [
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
                            const SizedBox(width: 10),
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
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Shift & Sort Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: ['Morning', 'Evening', 'Night'].contains(provider.selectedShift) ? provider.selectedShift : '',
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
                            const SizedBox(width: 10),
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
                                  provider.summarized ? 'Summarized' : 'Summarize',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Action Buttons Row (Refresh, Export CSV, Print)
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
                                label: const Text('CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

                // 2. Stats Cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    _buildStatCard('Lab Records', provider.totalTestCount.toString(), Colors.blue.shade50, Colors.blue.shade700),
                    _buildStatCard('Visible Rows', totalItems.toString(), Colors.grey.shade50, Colors.grey.shade700),
                    _buildStatCard('Total Amount', _formatMoney(provider.totalTestAmount), Colors.green.shade50, Colors.green.shade700),
                    _buildStatCard('Company Share', _formatMoney(provider.totalCompanyShare), Colors.deepPurple.shade50, Colors.deepPurple.shade700),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Data Table
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
                else if (!provider.hasActiveFilters && items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: Column(
                        children: [
                          Icon(Icons.filter_list_alt, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'Apply filters or search to load report',
                            style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Use the search bar or date filters above',
                            style: TextStyle(color: Colors.black26, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.biotech_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No lab records found', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                                        _cell('Sr.', 60, isHeader: true),
                                        _cell('Test Name', 200, isHeader: true),
                                        _cell('Records', 100, isHeader: true, textAlign: TextAlign.center),
                                        _cell('Amount', 130, isHeader: true, textAlign: TextAlign.right),
                                        _cell('Company Share', 130, isHeader: true, textAlign: TextAlign.right),
                                      ]
                                    : [
                                        _cell('Sr.', 50, isHeader: true),
                                        _cell('Date', 100, isHeader: true),
                                        _cell('Time', 80, isHeader: true),
                                        _cell('MR No', 100, isHeader: true),
                                        _cell('Patient', 140, isHeader: true),
                                        _cell('Service', 120, isHeader: true),
                                        _cell('Detail', 160, isHeader: true),
                                        _cell('Shift', 90, isHeader: true),
                                        _cell('Amount', 110, isHeader: true, textAlign: TextAlign.right),
                                        _cell('Share', 110, isHeader: true, textAlign: TextAlign.right),
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
                                                _cell(item.serviceDetail, 200),
                                                _cell('${item.testCount}', 100, textAlign: TextAlign.center),
                                                _cell(_formatMoney(item.testAmount), 130, textAlign: TextAlign.right, color: const Color(0xFF2E7D32)),
                                                _cell(_formatMoney(item.companyShare), 130, textAlign: TextAlign.right),
                                              ]
                                            : [
                                                _cell('${entry.key + 1}', 50),
                                                _cell(_formatDateStr(item.testDate), 100),
                                                _cell(_formatTime12(item.testTime), 80),
                                                _cell(item.mrNumber, 100),
                                                _cell(item.patientName, 140),
                                                _cell(item.opdService, 120),
                                                _cell(item.serviceDetail, 160),
                                                _cell(item.shiftType, 90),
                                                _cell(_formatMoney(item.testAmount), 110, textAlign: TextAlign.right, color: const Color(0xFF2E7D32)),
                                                _cell(_formatMoney(item.companyShare), 110, textAlign: TextAlign.right),
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
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.8), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor))),
        ],
      ),
    );
  }
}
