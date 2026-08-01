import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/reports/yearly_report_provider.dart';
import '../../models/reports/yearly_report_model.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class YearlyReportScreen extends StatefulWidget {
  const YearlyReportScreen({super.key});

  @override
  State<YearlyReportScreen> createState() => _YearlyReportScreenState();
}

class _YearlyReportScreenState extends State<YearlyReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final ScrollController _tableVertCtrl = ScrollController();
  final ScrollController _tableHorizCtrl = ScrollController();
  final ScrollController _headerHorizCtrl = ScrollController();

  int _opdVisible = 10;
  int _expVisible = 10;
  int _conVisible = 10;

  final List<String> _months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  final List<Color> _chartColors = const [
    Color(0xFF00B5AD), Color(0xFF0891B2), Color(0xFF3B82F6), Color(0xFF6366F1),
    Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFEC4899), Color(0xFFF43F5E),
    Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFF14B8A6), Color(0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tableVertCtrl.addListener(_onTableScroll);
    _tableHorizCtrl.addListener(_syncHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<YearlyReportProvider>().loadYearlyReport();
    });
  }

  @override
  void dispose() {
    _tableVertCtrl.removeListener(_onTableScroll);
    _tableHorizCtrl.removeListener(_syncHorizontalScroll);
    _tableVertCtrl.dispose();
    _tableHorizCtrl.dispose();
    _headerHorizCtrl.dispose();
    _tabCtrl.dispose();
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
        final provider = context.read<YearlyReportProvider>();
        if (_tabCtrl.index == 0) {
          final List rows = provider.opdMatrix['rows'] ?? [];
          if (_opdVisible < rows.length) {
            setState(() => _opdVisible = (_opdVisible + 10).clamp(10, rows.length));
          }
        } else if (_tabCtrl.index == 2) {
          final List rows = provider.consultationMatrix['rows'] ?? [];
          if (_conVisible < rows.length) {
            setState(() => _conVisible = (_conVisible + 10).clamp(10, rows.length));
          }
        }
      }
    }
  }

  String _formatMoney(double val) {
    if (val == 0) return '-';
    return NumberFormat('#,##0').format(val);
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

  Widget _buildSummaryCard(String title, double numericValue, IconData icon, Color color, String trend, bool trendUp, String subtitle, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 11),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: isMobile ? 8 : 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: isMobile ? 11 : 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'PKR ${_formatMoney(numericValue)}',
            style: TextStyle(
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: isMobile ? 8 : 9, color: Colors.grey.shade400)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                trendUp ? Icons.arrow_outward_rounded : Icons.south_east_rounded,
                size: 10,
                color: trendUp ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
              ),
              const SizedBox(width: 2),
              Text(
                trend,
                style: TextStyle(
                  fontSize: isMobile ? 9 : 10,
                  fontWeight: FontWeight.bold,
                  color: trendUp ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {bool isHeader = false, bool isBold = false, Color? color, bool isMobile = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? (isMobile ? 10 : 11) : (isMobile ? 11 : 12),
            fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? Colors.black87 : (color ?? Colors.black87),
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: isHeader || isBold ? TextAlign.left : TextAlign.right,
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter(int visible, int total, VoidCallback onLoadMore) {
    if (total <= 0) return const SizedBox.shrink();

    final isAllLoaded = visible >= total;
    final showing = visible.clamp(0, total);

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
            'Showing $showing of $total rows',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          if (!isAllLoaded)
            InkWell(
              onTap: onLoadMore,
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
            const Text('All loaded', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMatrixTable(Map<String, dynamic> matrixData, String title, Color color, int visibleCount, VoidCallback onLoadMore, double tableHeight, bool isMobile) {
    final List<YearlyRowData> rows = matrixData['rows'] ?? [];
    final List<double> monthlyTotals = matrixData['monthlyTotals'] ?? List.filled(12, 0.0);
    final double grandTotal = matrixData['grandTotal'] ?? 0.0;

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('No data available for selected filters', style: TextStyle(color: Colors.grey)),
      );
    }

    final visibleRows = rows.take(visibleCount).toList();

    return _buildDashboardCard(
      child: SizedBox(
        height: tableHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(color: color, fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('Total: PKR ${_formatMoney(grandTotal)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isMobile ? 10 : 11)),
                    backgroundColor: color.withValues(alpha: 0.1),
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                  ),
                ],
              ),
            ),

            // FIXED STICKY TABLE HEADER
            SingleChildScrollView(
              controller: _headerHorizCtrl,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Container(
                color: color.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Row(
                  children: [
                    _cell('Particulars', 150, isHeader: true, isMobile: isMobile),
                    ..._months.map((m) => _cell(m, 70, isHeader: true, isMobile: isMobile)),
                    _cell('Total', 100, isHeader: true, isMobile: isMobile),
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
                    children: [
                      ...visibleRows.map((row) {
                        return Container(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            children: [
                              _cell(row.title, 150, isBold: true, isMobile: isMobile),
                              ...row.months.map((val) => _cell(_formatMoney(val), 70, isMobile: isMobile)),
                              _cell('PKR ${_formatMoney(row.total)}', 100, color: color, isBold: true, isMobile: isMobile),
                            ],
                          ),
                        );
                      }),

                      // Monthly Totals Summary Row
                      Container(
                        color: Colors.grey.shade100,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: Row(
                          children: [
                            _cell('MONTHLY TOTAL', 150, isBold: true, isMobile: isMobile),
                            ...monthlyTotals.map((t) => _cell(_formatMoney(t), 70, color: color, isBold: true, isMobile: isMobile)),
                            _cell('PKR ${_formatMoney(grandTotal)}', 100, color: color, isBold: true, isMobile: isMobile),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildLoadMoreFooter(visibleCount, rows.length, onLoadMore),
          ],
        ),
      ),
    );
  }

  Widget _buildOpdAnalysisChart(Map<String, dynamic> opdMatrix, bool isMobile) {
    final List<YearlyRowData> rows = opdMatrix['rows'] ?? [];
    final List<double> monthlyTotals = opdMatrix['monthlyTotals'] ?? List.filled(12, 0.0);

    if (rows.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No OPD data available for analysis chart')));
    }

    double maxY = 0;
    for (final t in monthlyTotals) {
      if (t > maxY) maxY = t;
    }
    if (maxY == 0) maxY = 1000;

    final barGroups = List.generate(12, (mIdx) {
      final total = monthlyTotals[mIdx];
      return BarChartGroupData(
        x: mIdx,
        barRods: [
          BarChartRodData(
            toY: total,
            gradient: const LinearGradient(
              colors: [_teal, Color(0xFF0891B2)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: isMobile ? 14 : 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return _buildDashboardCard(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OPD Monthly Revenue Breakdown',
              style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: _teal),
            ),
            Text(
              'Revenue distribution across 12 months (Jan - Dec) — Tap bar for details',
              style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: isMobile ? 240 : 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.15,
                  // Touch Tooltip Details matching React YearlyReport.jsx!
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final mName = _months[group.x.toInt()];
                        final amtStr = NumberFormat('#,##0').format(rod.toY);
                        return BarTooltipItem(
                          '$mName\nRevenue: PKR $amtStr',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < 12) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(_months[idx], style: TextStyle(fontSize: isMobile ? 8 : 10, fontWeight: FontWeight.bold)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: isMobile ? 35 : 45,
                        getTitlesWidget: (val, meta) {
                          if (val == 0) return const SizedBox();
                          final kVal = (val / 1000).toStringAsFixed(0);
                          return Text('${kVal}k', style: TextStyle(fontSize: isMobile ? 8 : 10, color: Colors.grey));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Top Services Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: rows.take(6).map((row) {
                final idx = rows.indexOf(row) % _chartColors.length;
                return Chip(
                  avatar: CircleAvatar(backgroundColor: _chartColors[idx], radius: 6),
                  label: Text('${row.title}: PKR ${_formatMoney(row.total)}', style: TextStyle(fontSize: isMobile ? 10 : 11)),
                  backgroundColor: Colors.grey.shade100,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final double tableHeight = isMobile ? 380 : (isTablet ? 440 : 500);

    final provider = context.watch<YearlyReportProvider>();
    final currentYearInt = DateTime.now().year;
    final yearOptions = List.generate(6, (i) => (currentYearInt + 1 - i).toString());

    final double opdGrand = provider.opdMatrix['grandTotal'] ?? 0.0;
    final double expGrand = provider.expensesMatrix['grandTotal'] ?? 0.0;
    final double netRevenue = opdGrand - expGrand;

    return BaseScaffold(
      title: 'Yearly Report',
      drawerIndex: 35,
      body: RefreshIndicator(
        onRefresh: () => provider.loadYearlyReport(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 16, isMobile ? 12 : 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Controls Card
              _buildDashboardCard(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  child: isMobile
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: provider.selectedCategory,
                                    decoration: InputDecoration(
                                      labelText: 'Category',
                                      labelStyle: const TextStyle(fontSize: 11),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'All', child: Text('All Categories', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'OPD', child: Text('OPD Only', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'Expenses', child: Text('Expenses Only', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _opdVisible = 10;
                                        _expVisible = 10;
                                        _conVisible = 10;
                                        provider.setSelectedCategory(val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: provider.selectedShift,
                                    decoration: InputDecoration(
                                      labelText: 'Shift',
                                      labelStyle: const TextStyle(fontSize: 11),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'All', child: Text('All Shifts', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'Morning', child: Text('Morning', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'Evening', child: Text('Evening', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'Night', child: Text('Night', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        _opdVisible = 10;
                                        _expVisible = 10;
                                        _conVisible = 10;
                                        provider.setSelectedShift(val);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: provider.selectedYear,
                              decoration: InputDecoration(
                                labelText: 'Year',
                                labelStyle: const TextStyle(fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: yearOptions.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 11)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  _opdVisible = 10;
                                  _expVisible = 10;
                                  _conVisible = 10;
                                  provider.setSelectedYear(val);
                                }
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: provider.selectedCategory,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'All', child: Text('All Categories', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'OPD', child: Text('OPD Only', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'Expenses', child: Text('Expenses Only', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    _opdVisible = 10;
                                    _expVisible = 10;
                                    _conVisible = 10;
                                    provider.setSelectedCategory(val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: provider.selectedShift,
                                decoration: InputDecoration(
                                  labelText: 'Shift',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'All', child: Text('All Shifts', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'Morning', child: Text('Morning', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'Evening', child: Text('Evening', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'Night', child: Text('Night', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    _opdVisible = 10;
                                    _expVisible = 10;
                                    _conVisible = 10;
                                    provider.setSelectedShift(val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 90,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: provider.selectedYear,
                                decoration: InputDecoration(
                                  labelText: 'Year',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: yearOptions.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    _opdVisible = 10;
                                    _expVisible = 10;
                                    _conVisible = 10;
                                    provider.setSelectedYear(val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Summary Metric Cards (Perfect 3-Column Grid preserved)
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'OPD Revenue',
                      opdGrand,
                      Icons.trending_up,
                      const Color(0xFF10B981),
                      '+Annual',
                      true,
                      'OPD Gross',
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildSummaryCard(
                      'Expenses',
                      expGrand,
                      Icons.trending_down,
                      const Color(0xFFF43F5E),
                      '-Annual',
                      false,
                      'Outflow',
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildSummaryCard(
                      'Net Revenue',
                      netRevenue,
                      Icons.account_balance_wallet,
                      _teal,
                      'Net Profit',
                      netRevenue >= 0,
                      'Balance',
                      isMobile,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tab Bar Navigation
              TabBar(
                controller: _tabCtrl,
                labelColor: _teal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _teal,
                isScrollable: isMobile,
                tabs: const [
                  Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: 'Matrix View'),
                  Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'OPD Analysis'),
                  Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Consultations'),
                ],
              ),

              const SizedBox(height: 16),

              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: CustomLoader(size: 46, color: _teal),
                )
              else if (provider.errorMessage != null)
                Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red))))
              else
                SizedBox(
                  height: tableHeight,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // 1. Matrix View
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            if (provider.selectedCategory == 'All' || provider.selectedCategory == 'OPD')
                              _buildMatrixTable(
                                provider.opdMatrix,
                                'OPD Revenue Matrix',
                                _teal,
                                _opdVisible,
                                () {
                                  final List rows = provider.opdMatrix['rows'] ?? [];
                                  setState(() => _opdVisible = (_opdVisible + 10).clamp(10, rows.length));
                                },
                                tableHeight,
                                isMobile,
                              ),
                            const SizedBox(height: 16),
                            if (provider.selectedCategory == 'All' || provider.selectedCategory == 'Expenses')
                              _buildMatrixTable(
                                provider.expensesMatrix,
                                'Expenses Matrix',
                                Colors.red,
                                _expVisible,
                                () {
                                  final List rows = provider.expensesMatrix['rows'] ?? [];
                                  setState(() => _expVisible = (_expVisible + 10).clamp(10, rows.length));
                                },
                                tableHeight,
                                isMobile,
                              ),
                          ],
                        ),
                      ),

                      // 2. OPD Analysis (with Touch Tooltip details!)
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildOpdAnalysisChart(provider.opdMatrix, isMobile),
                      ),

                      // 3. Consultation Report
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildMatrixTable(
                          provider.consultationMatrix,
                          provider.selectedCategory == 'Expenses' ? 'Doctor Share (Expense) - Doctor Wise' : 'Consultation Revenue - Doctor Wise',
                          Colors.indigo,
                          _conVisible,
                          () {
                            final List rows = provider.consultationMatrix['rows'] ?? [];
                            setState(() => _conVisible = (_conVisible + 10).clamp(10, rows.length));
                          },
                          tableHeight,
                          isMobile,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
