import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/reports/opd_report_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class OpdReportScreen extends StatefulWidget {
  const OpdReportScreen({super.key});

  @override
  State<OpdReportScreen> createState() => _OpdReportScreenState();
}

class _OpdReportScreenState extends State<OpdReportScreen> {
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
      context.read<OpdReportProvider>().fetchReport();
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
        final provider = context.read<OpdReportProvider>();
        final total = provider.summarized
            ? provider.summarizedRows.length
            : provider.activeTabRows.length;
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

  String _formatDateStr(String val) {
    if (val.isEmpty) return '-';
    final d = DateTime.tryParse(val);
    if (d == null) return val;
    return DateFormat('dd MMM yyyy').format(d);
  }

  String _formatTime12(String val) {
    if (val.isEmpty) return '-';
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
    final provider = context.read<OpdReportProvider>();
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
      setState(() => _visibleCount = 12);
      provider.fetchReport();
    }
  }

  // ── PDF Print Function ──────────────────────────────────────────────────
  Future<void> _handlePrintPdf(BuildContext context) async {
    final provider = context.read<OpdReportProvider>();
    final doc = pw.Document();

    final activeTabLabel = provider.activeTab.toUpperCase();
    final isSummarized = provider.summarized;
    final isEmergency = provider.activeTab == 'emergency';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context pdfContext) {
          return [
            pw.Text('$activeTabLabel Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Date Range: ${provider.dateFrom} - ${provider.dateTo}  |  Shift: ${provider.selectedShift}'),
            pw.SizedBox(height: 10),
            if (isSummarized)
              pw.TableHelper.fromTextArray(
                headers: ['Sr #', 'Service / Detail', 'Combined Records', 'Total Amount'],
                data: provider.summarizedRows.map((r) => [
                  r.srlNo.toString(),
                  r.label,
                  r.combinedRecords.toString(),
                  _formatMoney(r.amountTotal),
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              )
            else if (isEmergency)
              pw.TableHelper.fromTextArray(
                headers: ['Sr #', 'Date', 'Time', 'Patient', 'MR No', 'Service', 'Shift', 'Amount', 'Status'],
                data: provider.emergencyTabRows.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value;
                  return [
                    idx.toString(),
                    _formatDateStr(r.date),
                    _formatTime12(r.time),
                    r.patientName,
                    r.mrNumber,
                    r.serviceName,
                    r.shiftType,
                    _formatMoney(r.amount),
                    r.status,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Sr #', 'Date', 'Time', 'MR No', 'Patient', 'Service', 'Detail', 'Shift', 'Amount', 'Status'],
                data: provider.activeTabRows.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value;
                  return [
                    idx.toString(),
                    _formatDateStr(r.date),
                    _formatTime12(r.time),
                    r.mrNumber,
                    r.patientName,
                    r.serviceName,
                    r.serviceDetail,
                    r.shiftType,
                    _formatMoney(r.amount),
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
      name: 'opd_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  Widget _cell(String text, double width, {bool isHeader = false, bool isBold = false, Color? color, TextAlign textAlign = TextAlign.left}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isHeader ? 11 : 11,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? _teal : (color ?? Colors.black87),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLoadMoreFooter(int total) {
    final loaded = _visibleCount.clamp(0, total);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $loaded of $total records',
            style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
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
            const Text('All loaded', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpdReportProvider>();
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 360;

    final totalItems = provider.summarized
        ? provider.summarizedRows.length
        : provider.activeTabRows.length;
    final visibleCount = _visibleCount.clamp(0, totalItems);

    return BaseScaffold(
      title: 'OPD Report',
      drawerIndex: 36,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 10 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Overview Cards
              Row(
                children: [
                  Expanded(
                    child: _buildDashboardCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL OPD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${provider.totalOpdCount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _teal)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDashboardCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CONSULTATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${provider.totalConsultationCount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDashboardCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('EMERGENCY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('${provider.totalEmergencyCount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Filter Card Section
              _buildDashboardCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FILTER OPD REPORT',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _teal, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 10),

                      // Search input
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (val) {
                          provider.setSearchQuery(val);
                          setState(() => _visibleCount = 12);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search MR, patient, service...',
                          prefixIcon: const Icon(Icons.search, color: _teal, size: 18),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    provider.setSearchQuery('');
                                    setState(() => _visibleCount = 12);
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
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: () => _pickDate(context, true),
                              icon: const Icon(Icons.calendar_today, size: 14, color: _teal),
                              label: Text(
                                provider.dateFrom.isEmpty ? 'From Date' : provider.dateFrom,
                                style: TextStyle(fontSize: 11, color: provider.dateFrom.isEmpty ? Colors.grey : Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: () => _pickDate(context, false),
                              icon: const Icon(Icons.calendar_today, size: 14, color: _teal),
                              label: Text(
                                provider.dateTo.isEmpty ? 'To Date' : provider.dateTo,
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
                              value: const ['All', 'Morning', 'Evening', 'Night'].contains(provider.selectedShift) ? provider.selectedShift : 'All',
                              decoration: InputDecoration(
                                labelText: 'Shift',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Shifts', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Morning', child: Text('Morning', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Evening', child: Text('Evening', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'Night', child: Text('Night', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                provider.setSelectedShift(val ?? 'All');
                                setState(() => _visibleCount = 12);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: () {
                                provider.setDateSortOrder(provider.dateSortOrder == 'desc' ? 'asc' : 'desc');
                                setState(() => _visibleCount = 12);
                              },
                              icon: Icon(provider.dateSortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: _teal),
                              label: Text(
                                provider.dateSortOrder == 'desc' ? 'Sort: Desc' : 'Sort: Asc',
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Summarize Toggle & Reset Row
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
                                setState(() => _visibleCount = 12);
                              },
                              icon: const Icon(Icons.compress_rounded, size: 16),
                              label: Text(
                                provider.summarized ? 'Summarized' : 'Summarize Data',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              _searchCtrl.clear();
                              provider.clearFilters();
                              setState(() => _visibleCount = 12);
                            },
                            icon: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                            label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 11)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Actions Row (Refresh, Print PDF)
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
                                backgroundColor: const Color(0xFF374151),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () => _handlePrintPdf(context),
                              icon: const Icon(Icons.print, size: 14),
                              label: const Text('Print PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tab Selector
              _buildTabSelector(context, provider),

              const SizedBox(height: 12),

              // Data Table Container (Sticky Header + Scrollable Table Body)
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
              else if (provider.activeTab == 'dental')
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Dental Report - Blank page for now.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                )
              else if (totalItems == 0)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.folder_off_outlined, size: 44, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No records found for selected filters', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                _buildDashboardCard(
                  child: SizedBox(
                    height: 450,
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
                                      _cell('Sr.', 50, isHeader: true),
                                      _cell('Service / Detail', 220, isHeader: true),
                                      _cell('Combined Records', 130, isHeader: true, textAlign: TextAlign.center),
                                      _cell('Total Amount', 130, isHeader: true, textAlign: TextAlign.right),
                                    ]
                                  : provider.activeTab == 'emergency'
                                      ? [
                                          _cell('Sr.', 50, isHeader: true),
                                          _cell('Date', 100, isHeader: true),
                                          _cell('Time', 80, isHeader: true),
                                          _cell('Patient', 140, isHeader: true),
                                          _cell('MR No', 100, isHeader: true),
                                          _cell('Service Head', 130, isHeader: true),
                                          _cell('Shift', 90, isHeader: true),
                                          _cell('Amount', 110, isHeader: true, textAlign: TextAlign.right),
                                          _cell('Status', 90, isHeader: true),
                                        ]
                                      : [
                                          _cell('Sr.', 50, isHeader: true),
                                          _cell('Date', 100, isHeader: true),
                                          _cell('Time', 80, isHeader: true),
                                          _cell('MR No', 100, isHeader: true),
                                          _cell('Patient', 140, isHeader: true),
                                          _cell('Service', 120, isHeader: true),
                                          _cell('Detail', 140, isHeader: true),
                                          _cell('Shift', 90, isHeader: true),
                                          _cell('Amount', 110, isHeader: true, textAlign: TextAlign.right),
                                          _cell('Status', 90, isHeader: true),
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
                                children: provider.summarized
                                    ? provider.summarizedRows.take(visibleCount).toList().asMap().entries.map((entry) {
                                        final r = entry.value;
                                        return Container(
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                          child: Row(
                                            children: [
                                              _cell('${r.srlNo}', 50),
                                              _cell(r.label, 220, isBold: true),
                                              SizedBox(
                                                width: 130,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _teal.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '${r.combinedRecords} records',
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _teal),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _cell(_formatMoney(r.amountTotal), 130, color: const Color(0xFF2E7D32), isBold: true, textAlign: TextAlign.right),
                                            ],
                                          ),
                                        );
                                      }).toList()
                                    : provider.activeTabRows.take(visibleCount).toList().asMap().entries.map((entry) {
                                        final r = entry.value;
                                        return Container(
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                          child: Row(
                                            children: provider.activeTab == 'emergency'
                                                ? [
                                                    _cell('${entry.key + 1}', 50),
                                                    _cell(_formatDateStr(r.date), 100),
                                                    _cell(_formatTime12(r.time), 80),
                                                    _cell(r.patientName, 140, isBold: true),
                                                    _cell(r.mrNumber, 100),
                                                    _cell(r.serviceName, 130),
                                                    _cell(r.shiftType, 90),
                                                    _cell(_formatMoney(r.amount), 110, color: const Color(0xFF2E7D32), isBold: true, textAlign: TextAlign.right),
                                                    _cell(r.status, 90),
                                                  ]
                                                : [
                                                    _cell('${entry.key + 1}', 50),
                                                    _cell(_formatDateStr(r.date), 100),
                                                    _cell(_formatTime12(r.time), 80),
                                                    _cell(r.mrNumber, 100),
                                                    _cell(r.patientName, 140, isBold: true),
                                                    _cell(r.serviceName, 120),
                                                    _cell(r.serviceDetail, 140),
                                                    _cell(r.shiftType, 90),
                                                    _cell(_formatMoney(r.amount), 110, color: const Color(0xFF2E7D32), isBold: true, textAlign: TextAlign.right),
                                                    _cell(r.status, 90),
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

  Widget _buildTabSelector(BuildContext context, OpdReportProvider provider) {
    final tabs = [
      {'id': 'opd', 'label': 'OPD (${provider.totalOpdCount})'},
      {'id': 'consultation', 'label': 'Consultation (${provider.totalConsultationCount})'},
      {'id': 'dental', 'label': 'Dental (0)'},
      {'id': 'emergency', 'label': 'Emergency (${provider.totalEmergencyCount})'},
    ];

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: tabs.map((t) {
          final isSelected = provider.activeTab == t['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                provider.setActiveTab(t['id']!);
                setState(() => _visibleCount = 12);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _teal : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? _teal : Colors.grey.shade300),
                ),
                child: Text(
                  t['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
