import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/reports/monthly_report_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> with SingleTickerProviderStateMixin {
  late TabController _viewTabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableVertCtrl = ScrollController();
  final ScrollController _tableHorizCtrl = ScrollController();
  final ScrollController _headerHorizCtrl = ScrollController();

  int _summaryVisible = 10;
  int _opdVisible = 10;
  int _expVisible = 10;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _viewTabCtrl = TabController(length: 4, vsync: this);
    _tableVertCtrl.addListener(_onTableScroll);
    _tableHorizCtrl.addListener(_syncHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonthlyReportProvider>().loadMonthlyData();
    });
  }

  @override
  void dispose() {
    _tableVertCtrl.removeListener(_onTableScroll);
    _tableHorizCtrl.removeListener(_syncHorizontalScroll);
    _tableVertCtrl.dispose();
    _tableHorizCtrl.dispose();
    _headerHorizCtrl.dispose();
    _viewTabCtrl.dispose();
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
        final provider = context.read<MonthlyReportProvider>();
        if (_viewTabCtrl.index == 0) {
          final total = provider.dailySummary.length;
          if (_summaryVisible < total) {
            setState(() => _summaryVisible = (_summaryVisible + 10).clamp(10, total));
          }
        } else if (_viewTabCtrl.index == 1) {
          final total = provider.opdParticulars.length;
          if (_opdVisible < total) {
            setState(() => _opdVisible = (_opdVisible + 10).clamp(10, total));
          }
        } else if (_viewTabCtrl.index == 2) {
          final total = provider.expenseParticulars.length;
          if (_expVisible < total) {
            setState(() => _expVisible = (_expVisible + 10).clamp(10, total));
          }
        }
      }
    }
  }

  String _formatMoney(double val) {
    return 'PKR ${NumberFormat('#,##0').format(val)}';
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

  Widget _buildSummaryCard(String title, dynamic value, IconData icon, Color color, String subtitle, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              Text(
                title.toUpperCase(),
                style: TextStyle(color: Colors.grey.shade500, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                overflow: TextOverflow.ellipsis,
              ),
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), radius: isMobile ? 10 : 12, child: Icon(icon, color: color, size: isMobile ? 12 : 14)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value is double ? _formatMoney(value) : '$value',
            style: TextStyle(color: color, fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: isMobile ? 8 : 9)),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {bool isHeader = false, bool isBold = false, Color? color, bool isMobile = false, TextAlign textAlign = TextAlign.left}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? (isMobile ? 11 : 12) : (isMobile ? 12 : 13),
            fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? Colors.black87 : (color ?? Colors.black87),
          ),
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
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
            'Showing $showing of $total items',
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final double tableHeight = isMobile ? 380 : (isTablet ? 440 : 500);

    final provider = context.watch<MonthlyReportProvider>();
    final currentYearInt = DateTime.now().year;
    final yearOptions = List.generate(6, (i) => (currentYearInt + 1 - i).toString());

    final dailySummaryList = provider.dailySummary;
    final opdList = provider.opdParticulars.where((s) => provider.searchQuery.isEmpty || s.service.toLowerCase().contains(provider.searchQuery.toLowerCase())).toList();
    final expList = provider.expenseParticulars.where((s) => provider.searchQuery.isEmpty || s.service.toLowerCase().contains(provider.searchQuery.toLowerCase())).toList();

    final visibleSummary = dailySummaryList.take(_summaryVisible).toList();
    final visibleOpd = opdList.take(_opdVisible).toList();
    final visibleExp = expList.take(_expVisible).toList();

    return BaseScaffold(
      title: 'Monthly Report',
      drawerIndex: 34,
      body: RefreshIndicator(
        onRefresh: () => provider.loadMonthlyData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 16, isMobile ? 12 : 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year & Month Selectors Card
              _buildDashboardCard(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: provider.selectedYear,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            labelStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: yearOptions.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _summaryVisible = 10;
                              _opdVisible = 10;
                              _expVisible = 10;
                              provider.setSelectedYear(val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: provider.selectedMonth,
                          decoration: InputDecoration(
                            labelText: 'Month',
                            labelStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: List.generate(12, (i) {
                            return DropdownMenuItem(
                              value: (i + 1).toString(),
                              child: Text(_months[i], style: const TextStyle(fontSize: 12)),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              _summaryVisible = 10;
                              _opdVisible = 10;
                              _expVisible = 10;
                              provider.setSelectedMonth(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Summary Stats Cards (2-Column Grid matching React)
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard('Total OPD', provider.totalOpdRevenue, Icons.trending_up, _teal, 'OPD Gross Collection', isMobile),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard('Total Expenses', provider.totalExpenses, Icons.trending_down, Colors.red, 'Total Outflow', isMobile),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard('Net Amount', provider.netRevenue, Icons.account_balance_wallet, const Color(0xFF2E7D32), 'OPD − Expenses', isMobile),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard('Active Days', '${dailySummaryList.length} days', Icons.calendar_today, const Color(0xFF5C6BC0), 'Recorded Days', isMobile),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tab Bar Navigation (Daily Summary, Detailed Breakdown, Calendar View, Monthly Overview)
              TabBar(
                controller: _viewTabCtrl,
                labelColor: _teal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _teal,
                isScrollable: isMobile,
                tabs: const [
                  Tab(text: 'Daily Summary'),
                  Tab(text: 'Detailed Breakdown'),
                  Tab(text: 'Calendar View'),
                  Tab(text: 'Monthly Overview'),
                ],
              ),

              const SizedBox(height: 12),

              // Search bar for Detailed & Calendar views
              if (_viewTabCtrl.index == 1 || _viewTabCtrl.index == 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => provider.setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Search services...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: _teal),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                  ),
                ),

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
                    controller: _viewTabCtrl,
                    children: [
                      // 1. Daily Summary Tab
                      dailySummaryList.isEmpty
                          ? const Center(child: Text('No monthly summary data', style: TextStyle(color: Colors.grey)))
                          : _buildDashboardCard(
                              child: Column(
                                children: [
                                  // FIXED STICKY TABLE HEADER
                                  SingleChildScrollView(
                                    controller: _headerHorizCtrl,
                                    scrollDirection: Axis.horizontal,
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: Container(
                                      color: _teal.withValues(alpha: 0.1),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Row(
                                        children: [
                                          _cell('Date', 90, isHeader: true, isMobile: isMobile),
                                          _cell('Morning OPD', 110, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                          _cell('Evening OPD', 110, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                          _cell('Night OPD', 110, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                          _cell('Expenses', 110, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                          _cell('Net Cash', 120, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 1),

                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _tableVertCtrl,
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        controller: _tableHorizCtrl,
                                        scrollDirection: Axis.horizontal,
                                        child: Column(
                                          children: visibleSummary.map((day) {
                                            final opdTotal = day.morning.opdTotal + day.evening.opdTotal + day.night.opdTotal;
                                            final expTotal = day.morning.expensesTotal + day.evening.expensesTotal + day.night.expensesTotal;
                                            final net = opdTotal - expTotal;
                                            return Container(
                                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                              child: Row(
                                                children: [
                                                  _cell(day.date, 90, isBold: true, isMobile: isMobile),
                                                  _cell(_formatMoney(day.morning.opdTotal), 110, isMobile: isMobile, textAlign: TextAlign.right),
                                                  _cell(_formatMoney(day.evening.opdTotal), 110, isMobile: isMobile, textAlign: TextAlign.right),
                                                  _cell(_formatMoney(day.night.opdTotal), 110, isMobile: isMobile, textAlign: TextAlign.right),
                                                  _cell(_formatMoney(expTotal), 110, color: Colors.red, isMobile: isMobile, textAlign: TextAlign.right),
                                                  _cell(_formatMoney(net), 120, color: net >= 0 ? const Color(0xFF2E7D32) : Colors.red, isBold: true, isMobile: isMobile, textAlign: TextAlign.right),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildLoadMoreFooter(_summaryVisible, dailySummaryList.length, () => setState(() => _summaryVisible = (_summaryVisible + 10).clamp(10, dailySummaryList.length))),
                                ],
                              ),
                            ),

                      // 2. Detailed Breakdown Tab
                      opdList.isEmpty && expList.isEmpty
                          ? const Center(child: Text('No detailed particulars match search', style: TextStyle(color: Colors.grey)))
                          : _buildDashboardCard(
                              child: Column(
                                children: [
                                  // FIXED STICKY TABLE HEADER
                                  SingleChildScrollView(
                                    controller: _headerHorizCtrl,
                                    scrollDirection: Axis.horizontal,
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: Container(
                                      color: _teal.withValues(alpha: 0.1),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Row(
                                        children: [
                                          _cell('Service / Particular', 180, isHeader: true, isMobile: isMobile),
                                          _cell('Morning', 110, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                          _cell('Evening', 110, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                          _cell('Night', 110, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                          _cell('Total Amount', 130, isHeader: true, isMobile: isMobile, textAlign: TextAlign.right),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 1),

                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _tableVertCtrl,
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        controller: _tableHorizCtrl,
                                        scrollDirection: Axis.horizontal,
                                        child: Column(
                                          children: [
                                            ...visibleOpd.map((item) {
                                              return Container(
                                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                child: Row(
                                                  children: [
                                                    _cell(item.service, 180, isBold: true, isMobile: isMobile),
                                                    _cell(_formatMoney(item.morning), 110, isMobile: isMobile, textAlign: TextAlign.right),
                                                    _cell(_formatMoney(item.evening), 110, isMobile: isMobile, textAlign: TextAlign.right),
                                                    _cell(_formatMoney(item.night), 110, isMobile: isMobile, textAlign: TextAlign.right),
                                                    _cell(_formatMoney(item.total), 130, color: _teal, isBold: true, isMobile: isMobile, textAlign: TextAlign.right),
                                                  ],
                                                ),
                                              );
                                            }),
                                            ...visibleExp.map((item) {
                                              return Container(
                                                color: Colors.red.shade50.withValues(alpha: 0.3),
                                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                child: Row(
                                                  children: [
                                                    _cell('${item.service} (Expense)', 180, color: Colors.red.shade900, isMobile: isMobile),
                                                    _cell(_formatMoney(item.morning), 110, color: Colors.red, isMobile: isMobile, textAlign: TextAlign.right),
                                                    _cell(_formatMoney(item.evening), 110, color: Colors.red, isMobile: isMobile, textAlign: TextAlign.right),
                                                    _cell(_formatMoney(item.night), 110, color: Colors.red, isMobile: isMobile, textAlign: TextAlign.right),
                                                    _cell(_formatMoney(item.total), 130, color: Colors.red.shade700, isBold: true, isMobile: isMobile, textAlign: TextAlign.right),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildLoadMoreFooter(_opdVisible, opdList.length, () => setState(() => _opdVisible = (_opdVisible + 10).clamp(10, opdList.length))),
                                ],
                              ),
                            ),

                      // 3. Calendar View Tab
                      provider.opdCalendar.isEmpty
                          ? const Center(child: Text('No calendar matrix data', style: TextStyle(color: Colors.grey)))
                          : _buildDashboardCard(
                              child: Column(
                                children: [
                                  // FIXED STICKY TABLE HEADER FOR CALENDAR
                                  SingleChildScrollView(
                                    controller: _headerHorizCtrl,
                                    scrollDirection: Axis.horizontal,
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: Container(
                                      color: _teal.withValues(alpha: 0.1),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Row(
                                        children: [
                                          _cell('Service', 160, isHeader: true, isMobile: isMobile),
                                          ...List.generate(31, (i) => _cell('${i + 1}', 45, isHeader: true, textAlign: TextAlign.center, isMobile: isMobile)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 1),

                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _tableVertCtrl,
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        controller: _tableHorizCtrl,
                                        scrollDirection: Axis.horizontal,
                                        child: Column(
                                          children: provider.opdCalendar.keys
                                              .where((s) => provider.searchQuery.isEmpty || s.toLowerCase().contains(provider.searchQuery.toLowerCase()))
                                              .map((serviceKey) {
                                            final daysMap = provider.opdCalendar[serviceKey] ?? {};
                                            return Container(
                                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                              child: Row(
                                                children: [
                                                  _cell(serviceKey, 160, isBold: true, isMobile: isMobile),
                                                  ...List.generate(31, (i) {
                                                    final val = daysMap[i + 1] ?? 0.0;
                                                    return _cell(val > 0 ? NumberFormat('#,##0').format(val) : '-', 45, textAlign: TextAlign.center, isMobile: isMobile);
                                                  }),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                      // 4. Monthly Overview Tab (Bar & Pie Charts)
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildDashboardCard(
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 12 : 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('OPD Services by Shift', style: TextStyle(fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.bold, color: _teal)),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 260,
                                      child: BarChart(
                                        BarChartData(
                                          alignment: BarChartAlignment.spaceAround,
                                          barTouchData: BarTouchData(
                                            touchTooltipData: BarTouchTooltipData(
                                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                final service = opdList.length > groupIndex ? opdList[groupIndex].service : 'Service';
                                                return BarTooltipItem(
                                                  '$service\nPKR ${NumberFormat('#,##0').format(rod.toY)}',
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
                                                  if (idx >= 0 && idx < opdList.length) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        opdList[idx].service.length > 6 ? '${opdList[idx].service.substring(0, 6)}..' : opdList[idx].service,
                                                        style: TextStyle(fontSize: isMobile ? 8 : 10),
                                                      ),
                                                    );
                                                  }
                                                  return const SizedBox();
                                                },
                                              ),
                                            ),
                                          ),
                                          borderData: FlBorderData(show: false),
                                          barGroups: opdList.take(8).toList().asMap().entries.map((e) {
                                            return BarChartGroupData(
                                              x: e.key,
                                              barRods: [
                                                BarChartRodData(
                                                  toY: e.value.total,
                                                  color: _teal,
                                                  width: isMobile ? 12 : 16,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
