import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/reports/shares_report_provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class SharesReportScreen extends StatefulWidget {
  const SharesReportScreen({super.key});

  @override
  State<SharesReportScreen> createState() => _SharesReportScreenState();
}

class _SharesReportScreenState extends State<SharesReportScreen> {
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
      context.read<SharesReportProvider>().fetchReport();
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
        final total = context.read<SharesReportProvider>().filteredRows.length;
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

  Widget _buildSummaryCard(String title, int count, IconData icon, Color textColor, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: textColor.withValues(alpha: 0.12),
            radius: isMobile ? 16 : 20,
            child: Icon(icon, color: textColor, size: isMobile ? 16 : 20),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: isMobile ? 8 : 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: TextStyle(color: textColor, fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
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
            'Showing $currentShowing of $totalItems shares',
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
    final screenWidth = mediaQuery.size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final double tableHeight = isMobile ? 380 : (isTablet ? 440 : 500);

    final provider = context.watch<SharesReportProvider>();
    final rows = provider.filteredRows;
    final totals = provider.totals;
    final totalItems = rows.length;
    final visibleRows = rows.take(_visibleCount).toList();

    final departments = provider.availableDepartments;

    return BaseScaffold(
      title: 'Shares Report',
      drawerIndex: 32,
      body: RefreshIndicator(
        onRefresh: () => provider.fetchReport(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 16, isMobile ? 12 : 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards Grid with MediaQuery Adaptation
              if (totals != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard('Total Shares', totals.totalRecords, Icons.account_balance_wallet, _teal, isMobile),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryCard('Doctors', totals.doctorRecords, Icons.people, const Color(0xFF2E7D32), isMobile),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard('Employees', totals.employeeRecords, Icons.badge, const Color(0xFF7B1FA2), isMobile),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryCard('Indoor', totals.indoorRecords, Icons.bed, const Color(0xFFF57F17), isMobile),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Filter Controls Card (Structured 2-Column Grid Layout)
              _buildDashboardCard(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FILTER SHARES REPORT',
                        style: TextStyle(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.bold, color: _teal, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 12),

                      // Row 1 (2-Column Grid): Search & Person Type
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
                                hintText: isMobile ? 'Search...' : 'Search name, code, service...',
                                hintStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                                prefixIcon: Icon(Icons.search, color: _teal, size: isMobile ? 16 : 18),
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
                            child: DropdownButtonFormField<String>(
                              initialValue: provider.personType,
                              decoration: InputDecoration(
                                labelText: 'Person Type',
                                labelStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Types', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'doctor', child: Text('Doctors', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'employee', child: Text('Employees', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                provider.setPersonType(val ?? 'all');
                                setState(() => _visibleCount = 10);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Row 2 (2-Column Grid): Service Type & Department
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: provider.serviceType,
                              decoration: InputDecoration(
                                labelText: 'Service Type',
                                labelStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Services', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'opd', child: Text('OPD', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'indoor', child: Text('Indoor', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                provider.setServiceType(val ?? 'all');
                                setState(() => _visibleCount = 10);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: provider.department.isEmpty ? '' : provider.department,
                              decoration: InputDecoration(
                                labelText: 'Department',
                                labelStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('All Departments', style: TextStyle(fontSize: 12))),
                                ...departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))),
                              ],
                              onChanged: (val) {
                                provider.setDepartment(val ?? '');
                                setState(() => _visibleCount = 10);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Row 3: Action Buttons Row (Apply Filters & Reset)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
                              ),
                              onPressed: () => provider.fetchReport(),
                              icon: const Icon(Icons.filter_alt, size: 16),
                              label: Text('Apply Filters', style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                provider.resetFilters();
                                setState(() => _visibleCount = 10);
                              },
                              icon: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                              label: Text('Reset', style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.red)),
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
              else if (rows.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.badge_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No shares records found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else
                _buildDashboardCard(
                  child: SizedBox(
                    height: tableHeight,
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
                              children: [
                                _cell('Sr#', 50, isHeader: true, isMobile: isMobile),
                                _cell('Person', 160, isHeader: true, isMobile: isMobile),
                                _cell('Department', 130, isHeader: true, isMobile: isMobile),
                                _cell('Service', 180, isHeader: true, isMobile: isMobile),
                                _cell('Rate', 110, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
                                _cell('Share', 110, isHeader: true, textAlign: TextAlign.right, isMobile: isMobile),
                                _cell('Followup', 100, isHeader: true, isMobile: isMobile),
                                _cell('Editable', 80, isHeader: true, textAlign: TextAlign.center, isMobile: isMobile),
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
                                children: visibleRows.asMap().entries.map((entry) {
                                  final row = entry.value;
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    child: Row(
                                      children: [
                                        _cell('${entry.key + 1}', 50, isMobile: isMobile),
                                        SizedBox(
                                          width: 160,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(row.personName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13), overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: row.personType.toLowerCase() == 'doctor' ? Colors.blue.shade100 : Colors.purple.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(row.personType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: row.personType.toLowerCase() == 'doctor' ? Colors.blue.shade800 : Colors.purple.shade800)),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(row.personCode, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        _cell(row.department.isEmpty ? '-' : row.department, 130, isMobile: isMobile),
                                        SizedBox(
                                          width: 180,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(row.serviceName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13), overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: row.serviceType.toLowerCase() == 'opd' ? Colors.green.shade100 : Colors.amber.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(row.serviceType.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: row.serviceType.toLowerCase() == 'opd' ? Colors.green.shade800 : Colors.amber.shade800)),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text('${row.serviceId ?? ''}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        _cell(
                                          _formatMoney(row.customCharge ?? row.masterRate),
                                          110,
                                          isBold: true,
                                          textAlign: TextAlign.right,
                                          isMobile: isMobile,
                                        ),
                                        _cell(
                                          row.shareType.toLowerCase() == 'percentage' ? '${row.shareValue}%' : _formatMoney(row.shareValue),
                                          110,
                                          color: _teal,
                                          isBold: true,
                                          textAlign: TextAlign.right,
                                          isMobile: isMobile,
                                        ),
                                        _cell(row.followupDays != null && row.followupDays! > 0 ? '${row.followupDays} days' : '-', 100, isMobile: isMobile),
                                        _cell(
                                          row.priceEditable ? 'Yes' : 'No',
                                          80,
                                          color: row.priceEditable ? Colors.green : Colors.grey,
                                          isBold: row.priceEditable,
                                          textAlign: TextAlign.center,
                                          isMobile: isMobile,
                                        ),
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
