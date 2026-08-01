import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/reports/shift_report_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class ShiftReportScreen extends StatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _tableVertCtrl = ScrollController();
  final ScrollController _tableHorizCtrl = ScrollController();
  final ScrollController _headerHorizCtrl = ScrollController();

  int _conVisible = 10;
  int _otherVisible = 10;
  int _expVisible = 10;
  int _emergVisible = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tableVertCtrl.addListener(_onTableScroll);
    _tableHorizCtrl.addListener(_syncHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShiftReportProvider>().loadShiftDataForDate();
    });
  }

  @override
  void dispose() {
    _tableVertCtrl.removeListener(_onTableScroll);
    _tableHorizCtrl.removeListener(_syncHorizontalScroll);
    _tableVertCtrl.dispose();
    _tableHorizCtrl.dispose();
    _headerHorizCtrl.dispose();
    _tabController.dispose();
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
        final provider = context.read<ShiftReportProvider>();
        if (_tabController.index == 0) {
          final total = provider.consultationData.length;
          if (_conVisible < total) {
            setState(() => _conVisible = (_conVisible + 10).clamp(10, total));
          }
        } else if (_tabController.index == 1) {
          final total = provider.otherData.length;
          if (_otherVisible < total) {
            setState(() => _otherVisible = (_otherVisible + 10).clamp(10, total));
          }
        } else if (_tabController.index == 2) {
          final total = provider.expenses.length;
          if (_expVisible < total) {
            setState(() => _expVisible = (_expVisible + 10).clamp(10, total));
          }
        } else if (_tabController.index == 3) {
          final total = provider.emergencyData.length;
          if (_emergVisible < total) {
            setState(() => _emergVisible = (_emergVisible + 10).clamp(10, total));
          }
        }
      }
    }
  }

  String _formatMoney(double val) {
    return 'PKR ${NumberFormat('#,##0').format(val)}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final provider = context.read<ShiftReportProvider>();
    final initialDate = DateTime.tryParse(provider.selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      _conVisible = 10;
      _otherVisible = 10;
      _expVisible = 10;
      _emergVisible = 10;
      provider.setSelectedDate(formatted);
    }
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

  Widget _buildSummaryMetricCard(String label, double amount, IconData icon, Color color, String subtitle, bool isMobile) {
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
              Text(label.toUpperCase(), style: TextStyle(color: Colors.grey.shade500, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), radius: isMobile ? 10 : 12, child: Icon(icon, color: color, size: isMobile ? 12 : 14)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_formatMoney(amount), style: TextStyle(color: color, fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: isMobile ? 8 : 9)),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {bool isHeader = false, bool isBold = false, Color? color, TextAlign textAlign = TextAlign.left, bool isMobile = false}) {
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

    final provider = context.watch<ShiftReportProvider>();

    final consultList = provider.consultationData;
    final otherList = provider.otherData;
    final expList = provider.expenses;
    final emergList = provider.emergencyData;

    final visibleConsult = consultList.take(_conVisible).toList();
    final visibleOther = otherList.take(_otherVisible).toList();
    final visibleExp = expList.take(_expVisible).toList();
    final visibleEmerg = emergList.take(_emergVisible).toList();

    return BaseScaffold(
      title: 'Shift Report',
      drawerIndex: 33,
      body: RefreshIndicator(
        onRefresh: () => provider.fetchData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 16, isMobile ? 12 : 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & Shift Selection Card
              _buildDashboardCard(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onPressed: () => _selectDate(context),
                          icon: const Icon(Icons.calendar_today, size: 16, color: _teal),
                          label: Text(
                            provider.selectedDate,
                            style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<dynamic>(
                          initialValue: provider.selectedShiftId,
                          decoration: InputDecoration(
                            labelText: 'Select Shift',
                            labelStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Shifts', style: TextStyle(fontSize: 12))),
                            ...provider.availableShifts.map((s) {
                              return DropdownMenuItem(
                                value: s.shiftId,
                                child: Text('Shift #${s.shiftId} (${s.shiftType})', style: const TextStyle(fontSize: 12)),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              _conVisible = 10;
                              _otherVisible = 10;
                              _expVisible = 10;
                              _emergVisible = 10;
                              provider.setSelectedShiftId(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Summary Stats Cards (No borders, soft shadow, matching UI)
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetricCard('Revenue', provider.totalRevenue, Icons.trending_up, const Color(0xFF10B981), 'OPD + Emergency', isMobile),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryMetricCard('Expenses', provider.totalExpensesWithDocShare, Icons.trending_down, Colors.red, 'Direct + Dr. Shares', isMobile),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryMetricCard('Net Revenue', provider.netHospitalRevenue, Icons.account_balance_wallet, _teal, 'Revenue − Expenses', isMobile),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
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
                              Text('CANCELLED', style: TextStyle(color: Colors.grey.shade500, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                              CircleAvatar(backgroundColor: Colors.orange.shade100, radius: isMobile ? 10 : 12, child: Icon(Icons.block, color: Colors.orange, size: isMobile ? 12 : 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('${provider.cancelledCount}', style: TextStyle(color: Colors.orange, fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('PKR ${NumberFormat('#,##0').format(provider.cancelledTotal)} (excluded)', style: TextStyle(color: Colors.grey, fontSize: isMobile ? 8 : 9)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tab Bar Navigation: Consultations, Other Services, Direct Expenses, Emergency Services
              TabBar(
                controller: _tabController,
                labelColor: _teal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _teal,
                isScrollable: isMobile,
                tabs: [
                  Tab(text: 'Consultations (${consultList.length})'),
                  Tab(text: 'Other Services (${otherList.length})'),
                  Tab(text: 'Expenses (${expList.length})'),
                  Tab(text: 'Emergency (${emergList.length})'),
                ],
              ),

              const SizedBox(height: 12),

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
                    controller: _tabController,
                    children: [
                      // 1. Consultations Tab
                      _buildDashboardCard(
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
                                    _cell('Doctor', 180, isHeader: true, isMobile: isMobile),
                                    _cell('Total', 120, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
                                    _cell('Dr. Share', 120, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
                                    _cell('Hospital', 120, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
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
                                      ...visibleConsult.map((rec) {
                                        return Container(
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                          child: Row(
                                            children: [
                                              _cell(rec.name, 180, isBold: true, isMobile: isMobile),
                                              _cell(_formatMoney(rec.total), 120, textAlign: TextAlign.right, isMobile: isMobile),
                                              _cell(_formatMoney(rec.share), 120, color: Colors.red, textAlign: TextAlign.right, isMobile: isMobile),
                                              _cell(_formatMoney(rec.hospital), 120, color: const Color(0xFF2E7D32), isBold: true, textAlign: TextAlign.right, isMobile: isMobile),
                                            ],
                                          ),
                                        );
                                      }),
                                      ...provider.cancelledConsultations.map((rec) {
                                        return Container(
                                          color: Colors.orange.shade50.withValues(alpha: 0.5),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          child: Row(
                                            children: [
                                              _cell('${rec.doctorName} (CANCELLED)', 180, color: Colors.orange.shade800, isMobile: isMobile),
                                              _cell(_formatMoney(rec.feeAmount), 120, color: Colors.orange.shade400, textAlign: TextAlign.right, isMobile: isMobile),
                                              _cell(_formatMoney(rec.drShareAmount), 120, color: Colors.orange.shade400, textAlign: TextAlign.right, isMobile: isMobile),
                                              _cell('—', 120, color: Colors.orange.shade400, textAlign: TextAlign.right, isMobile: isMobile),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            _buildLoadMoreFooter(_conVisible, consultList.length, () => setState(() => _conVisible = (_conVisible + 10).clamp(10, consultList.length))),
                          ],
                        ),
                      ),

                      // 2. Other Services Tab
                      _buildDashboardCard(
                        child: Column(
                          children: [
                            // FIXED STICKY TABLE HEADER
                            SingleChildScrollView(
                              controller: _headerHorizCtrl,
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Container(
                                color: Colors.indigo.withValues(alpha: 0.1),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Row(
                                  children: [
                                    _cell('Service', 180, isHeader: true, isMobile: isMobile),
                                    _cell('Total', 120, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
                                    _cell('Share', 120, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
                                    _cell('Hospital', 120, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
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
                                      ...visibleOther.map((rec) {
                                        return Container(
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                          child: Row(
                                            children: [
                                              _cell(rec.name, 180, isBold: true, isMobile: isMobile),
                                              _cell(_formatMoney(rec.total), 120, textAlign: TextAlign.right, isMobile: isMobile),
                                              _cell(_formatMoney(rec.share), 120, color: Colors.red, textAlign: TextAlign.right, isMobile: isMobile),
                                              _cell(_formatMoney(rec.hospital), 120, color: const Color(0xFF2E7D32), isBold: true, textAlign: TextAlign.right, isMobile: isMobile),
                                            ],
                                          ),
                                        );
                                      }),
                                      ...provider.cancelledOther.map((rec) {
                                        return Container(
                                          color: Colors.orange.shade50.withValues(alpha: 0.5),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          child: Row(
                                            children: [
                                              _cell('${rec.opdService} (CANCELLED)', 180, color: Colors.orange.shade800, isMobile: isMobile),
                                              _cell(_formatMoney(rec.feeAmount), 120, color: Colors.orange.shade400, textAlign: TextAlign.right, isMobile: isMobile),
                                              _cell(_formatMoney(rec.drShareAmount), 120, color: Colors.orange.shade400, textAlign: TextAlign.right, isMobile: isMobile),
                                              _cell('—', 120, color: Colors.orange.shade400, textAlign: TextAlign.right, isMobile: isMobile),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            _buildLoadMoreFooter(_otherVisible, otherList.length, () => setState(() => _otherVisible = (_otherVisible + 10).clamp(10, otherList.length))),
                          ],
                        ),
                      ),

                      // 3. Direct Expenses Tab
                      _buildDashboardCard(
                        child: Column(
                          children: [
                            // FIXED STICKY TABLE HEADER
                            SingleChildScrollView(
                              controller: _headerHorizCtrl,
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Container(
                                color: Colors.red.withValues(alpha: 0.1),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Row(
                                  children: [
                                    _cell('Expense', 160, isHeader: true, isMobile: isMobile),
                                    _cell('Description', 200, isHeader: true, isMobile: isMobile),
                                    _cell('Amount', 140, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
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
                                    children: visibleExp.map((exp) {
                                      return Container(
                                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        child: Row(
                                          children: [
                                            _cell(exp.expenseName, 160, isBold: true, isMobile: isMobile),
                                            _cell(exp.expenseDescription.isEmpty ? '-' : exp.expenseDescription, 200, isMobile: isMobile),
                                            _cell(_formatMoney(exp.expenseAmount), 140, color: Colors.red, isBold: true, textAlign: TextAlign.right, isMobile: isMobile),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            _buildLoadMoreFooter(_expVisible, expList.length, () => setState(() => _expVisible = (_expVisible + 10).clamp(10, expList.length))),
                          ],
                        ),
                      ),

                      // 4. Emergency Services Tab
                      _buildDashboardCard(
                        child: Column(
                          children: [
                            // FIXED STICKY TABLE HEADER
                            SingleChildScrollView(
                              controller: _headerHorizCtrl,
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Container(
                                color: Colors.amber.withValues(alpha: 0.1),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Row(
                                  children: [
                                    _cell('Service', 240, isHeader: true, isMobile: isMobile),
                                    _cell('Amount', 180, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
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
                                    children: visibleEmerg.map((bill) {
                                      return Container(
                                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        child: Row(
                                          children: [
                                            _cell(bill.name, 240, isBold: true, isMobile: isMobile),
                                            _cell(_formatMoney(bill.total), 180, color: Colors.amber.shade900, isBold: true, textAlign: TextAlign.right, isMobile: isMobile),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            _buildLoadMoreFooter(_emergVisible, emergList.length, () => setState(() => _emergVisible = (_emergVisible + 10).clamp(10, emergList.length))),
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
