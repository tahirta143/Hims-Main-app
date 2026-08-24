import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/task_report_model.dart';
import '../../../providers/task_management/task_report_provider.dart';
import 'package:hims_app/custum%20widgets/task_management/task_app_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_bottom_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_workspace_drawer.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import '../task_workspace_screen.dart';

const Color _kTeal     = Color(0xFF00B5AD);
const Color _kTealDark = Color(0xFF0D9488);
const Color _kSlate    = Color(0xFF334155);
const Color _kBg       = Color(0xFFF8FAFC);
const Color _kBorder   = Color(0xFFEDF2F7);

const List<Color> _kSeries = [
  Color(0xFF00B5AE),
  Color(0xFF4F46E5),
  Color(0xFFF59E0B),
  Color(0xFFE11D48),
  Color(0xFF7C3AED),
  Color(0xFF0EA5E9),
];

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _aiPromptCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskReportProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _aiPromptCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onBottomNavItemBar(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => TaskWorkspaceScreen(initialTabIndex: index)),
      (route) => false,
    );
  }

  void _exportCSV(TaskReportProvider provider) {
    final buffer = StringBuffer();
    buffer.writeln('Employee,Code,Designation,Department,Assigned,Completed,In progress,Pending,Avg rating');
    for (var r in provider.performance) {
      buffer.writeln('"${r.name}","${r.employeeCode ?? ''}","${r.designation ?? ''}","${r.departmentName ?? ''}",${r.assignedCount},${r.completedCount},${r.inProgressCount},${r.pendingCount},${r.avgRating}');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Performance CSV generated (Share/Save logic pending)')),
    );
  }

  // ── Stat tiles row ────────────────────────────────────────────────────────
  Widget _buildStatTiles(OverviewReport? overview) {
    final counts = overview?.counts ?? const OverviewCounts();
    final active = overview?.activeUsers ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 6 : 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
        children: [
          StatTileWidget(
            label: 'TOTAL',
            value: '${counts.total}',
            icon: Icons.bar_chart_rounded,
            accentColor: _kSlate,
            bgColor: Colors.white,
          ),
          StatTileWidget(
            label: 'PENDING',
            value: '${counts.pending}',
            icon: Icons.pause_circle_outline,
            accentColor: const Color(0xFF2563EB),
            bgColor: Colors.white,
          ),
          StatTileWidget(
            label: 'IN PROGRESS',
            value: '${counts.inProgress}',
            icon: Icons.access_time_rounded,
            accentColor: _kTeal,
            bgColor: Colors.white,
          ),
          StatTileWidget(
            label: 'COMPLETED',
            value: '${counts.completed}',
            icon: Icons.check_circle_outline,
            accentColor: const Color(0xFF059669),
            bgColor: Colors.white,
          ),
          StatTileWidget(
            label: 'ON HOLD',
            value: '${counts.onHold}',
            icon: Icons.warning_amber_rounded,
            accentColor: const Color(0xFFD97706),
            bgColor: Colors.white,
          ),
          StatTileWidget(
            label: 'ACTIVE STAFF',
            value: '$active',
            icon: Icons.trending_up_rounded,
            accentColor: const Color(0xFFBE123C),
            bgColor: Colors.white,
          ),
        ],
      ),
    );
  }

  // ── Line chart — Completed per day ────────────────────────────────────────
  Widget _buildLineChart(List<TrendPoint> trend) {
    return TaskGlassPanel(
      title: 'Completed per day',
      subtitle: 'Last 14 days',
      child: trend.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.trending_up_outlined,
              title: 'No activity yet',
            )
          : SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: TaskColors.slateLight)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (trend.length / 4).ceilToDouble().clamp(1, 999),
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(trend[idx].day, style: const TextStyle(fontSize: 8, color: TaskColors.slateMuted)),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _kSlate,
                      getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                        '${trend[s.x.toInt()].day}\n',
                        const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(text: '${s.y.toInt()} completed', style: const TextStyle(color: Color(0xFF99F6E4), fontSize: 10)),
                        ],
                      )).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.completed.toDouble())).toList(),
                      isCurved: true,
                      color: _kTeal,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: _kTeal.withOpacity(0.07)),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
    );
  }

  // ── Bar chart — Tasks by department ──────────────────────────────────────
  Widget _buildDeptBarChart(List<DeptTaskCount> byDept) {
    return TaskGlassPanel(
      title: 'Tasks by department',
      child: byDept.isEmpty
          ? const EmptyStateWidget(icon: Icons.bar_chart_outlined, title: 'No departments yet')
          : SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => _kSlate,
                      getTooltipItem: (group, gi, rod, ri) {
                        final d = byDept[group.x];
                        return BarTooltipItem(
                          '${d.departmentName}\n',
                          const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: '${d.total} tasks', style: const TextStyle(color: Color(0xFF99F6E4), fontSize: 10)),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= byDept.length) return const SizedBox.shrink();
                          final n = byDept[idx].departmentName;
                          final short = n.length > 8 ? '${n.substring(0, 7)}…' : n;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(short, style: const TextStyle(fontSize: 8, color: TaskColors.slateMuted)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: TaskColors.slateLight)),
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
                  ),
                  barGroups: byDept.asMap().entries.map((e) {
                    final color = _kSeries[e.key % _kSeries.length];
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.total.toDouble(),
                          color: color,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }

  // ── Departments table ─────────────────────────────────────────────────────
  Widget _buildDeptTable(List<DepartmentSummaryReport> departments) {
    return TaskGlassPanel(
      title: 'Departments',
      subtitle: 'Staffing and workload per department',
      child: departments.isEmpty
          ? const EmptyStateWidget(icon: Icons.bar_chart_outlined, title: 'No departments yet')
          : Column(
              children: [
                // Header
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    children: [
                      Expanded(flex: 4, child: Text('DEPARTMENT', style: _tableHeaderStyle)),
                      Expanded(flex: 2, child: Text('STAFF', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                      Expanded(flex: 2, child: Text('TASKS', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                      Expanded(flex: 2, child: Text('DONE', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                      Expanded(flex: 3, child: Text('COMPLETION', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _kBorder),
                ...List.generate(departments.length, (i) {
                  final d = departments[i];
                  final rate = d.tasks > 0 ? ((d.completed / d.tasks) * 100).round() : 0;
                  final rateColor = rate >= 75 ? const Color(0xFF059669) : rate >= 40 ? const Color(0xFFD97706) : TaskColors.slateMuted;
                  final rateBg = rate >= 75 ? const Color(0xFFECFDF5) : rate >= 40 ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(flex: 4, child: Text(d.departmentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate))),
                            Expanded(flex: 2, child: Text('${d.staff}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted))),
                            Expanded(flex: 2, child: Text('${d.tasks}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted))),
                            Expanded(flex: 2, child: Text('${d.completed}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)))),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: rateBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text('$rate%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rateColor)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < departments.length - 1) const Divider(height: 1, color: _kBorder, indent: 12, endIndent: 12),
                    ],
                  );
                }),
              ],
            ),
    );
  }

  // ── AI Panel ──────────────────────────────────────────────────────────────
  Widget _buildAiPanel(BuildContext context, TaskReportProvider provider) {
    return Column(
      children: [
        // AI Insights card
        TaskGlassPanel(
          title: 'AI insights',
          subtitle: 'A narrative read of the numbers above',
          trailing: GestureDetector(
            onTap: provider.aiLoading ? null : provider.generateAiInsights,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kTeal, _kTealDark]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.aiLoading)
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    provider.aiLoading ? 'Thinking…' : provider.aiInsights.isNotEmpty ? 'Regenerate' : 'Generate',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          child: provider.aiLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: _kTeal)))
              : provider.aiInsights.isNotEmpty
                  ? Text(provider.aiInsights, style: const TextStyle(fontSize: 12.5, color: TaskColors.slateMuted, height: 1.5))
                  : const EmptyStateWidget(
                      icon: Icons.auto_awesome_rounded,
                      title: 'No insights yet',
                      hint: 'Generate a summary of trends and bottlenecks across the current data.',
                    ),
        ),
        const SizedBox(height: 16),
        // Ask about the data card
        TaskGlassPanel(
          title: 'Ask about the data',
          subtitle: 'Tasks, projects, departments and staff names only',
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: provider.aiHistory.isEmpty && !provider.aiAsking
                    ? const EmptyStateWidget(
                        icon: Icons.smart_toy_outlined,
                        title: 'Ask a question',
                        hint: 'For example: which department has the most overdue tasks?',
                      )
                    : ListView.builder(
                        controller: _chatScroll,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: provider.aiHistory.length + (provider.aiAsking ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == provider.aiHistory.length && provider.aiAsking) {
                            return _ChatBubble(isUser: false, content: '...', isLoading: true);
                          }
                          final m = provider.aiHistory[i];
                          return _ChatBubble(isUser: m['role'] == 'user', content: m['content'] ?? '');
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiPromptCtrl,
                      onSubmitted: (v) {
                        provider.sendAiChat(v);
                        _aiPromptCtrl.clear();
                        _scrollChatToBottom();
                      },
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Ask about tasks, projects or workload…',
                        hintStyle: const TextStyle(fontSize: 12, color: TaskColors.slateLight),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: provider.aiAsking
                        ? null
                        : () {
                            provider.sendAiChat(_aiPromptCtrl.text);
                            _aiPromptCtrl.clear();
                            _scrollChatToBottom();
                          },
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: _kTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      disabledBackgroundColor: _kTeal.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskReportProvider>();
    final workspace = context.watch<TaskWorkspaceProvider>();
    final isAdmin = workspace.me?.isAdmin ?? false;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      appBar: TaskAppBar(
        title: 'Reports',
        subtitle: 'ADMINISTRATION',
        scaffoldKey: _scaffoldKey,
        action: IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
          onPressed: provider.performance.isEmpty ? null : () => _exportCSV(provider),
          tooltip: 'Export Performance CSV',
        ),
      ),
      drawer: TaskWorkspaceDrawer(
        activeTabIndex: 14, // Reports index
        unreadCount: workspace.unreadCount,
        isAdmin: isAdmin,
        onTabSelected: _onBottomNavItemBar,
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : RefreshIndicator(
              onRefresh: provider.loadAll,
              color: _kTeal,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatTiles(provider.overview),
                  const SizedBox(height: 16),
                  
                  // Adaptive layout for charts
                  if (MediaQuery.of(context).size.width > 700)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildLineChart(provider.overview?.completionTrend ?? [])),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDeptBarChart(provider.overview?.byDepartment ?? [])),
                      ],
                    )
                  else ...[
                    _buildLineChart(provider.overview?.completionTrend ?? []),
                    const SizedBox(height: 16),
                    _buildDeptBarChart(provider.overview?.byDepartment ?? []),
                  ],
                  
                  const SizedBox(height: 16),
                  _buildDeptTable(provider.departments),
                  
                  const SizedBox(height: 16),
                  // Staff performance card
                  TaskGlassPanel(
                    title: 'Staff performance',
                    subtitle: 'Top 10 by completed work',
                    padding: EdgeInsets.zero,
                    child: provider.performance.isEmpty
                        ? const EmptyStateWidget(icon: Icons.trending_up_outlined, title: 'No assignments yet')
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 32,
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 56,
                              horizontalMargin: 12,
                              columnSpacing: 20,
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              columns: const [
                                DataColumn(label: Text('EMPLOYEE', style: _tableHeaderStyle)),
                                DataColumn(label: Text('DEPT', style: _tableHeaderStyle)),
                                DataColumn(numeric: true, label: Text('ASSIGNED', style: _tableHeaderStyle)),
                                DataColumn(numeric: true, label: Text('DONE', style: _tableHeaderStyle)),
                                DataColumn(numeric: true, label: Text('IN PROG', style: _tableHeaderStyle)),
                                DataColumn(numeric: true, label: Text('RATING', style: _tableHeaderStyle)),
                              ],
                              rows: provider.performance.take(10).map((r) {
                                return DataRow(cells: [
                                  DataCell(Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(r.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
                                      Text(r.designation ?? r.employeeCode ?? '', style: const TextStyle(fontSize: 10, color: TaskColors.slateLight)),
                                    ],
                                  )),
                                  DataCell(Text(r.departmentName ?? '—', style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted))),
                                  DataCell(Text('${r.assignedCount}', style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted))),
                                  DataCell(Text('${r.completedCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
                                  DataCell(Text('${r.inProgressCount}', style: const TextStyle(fontSize: 11, color: _kTeal))),
                                  DataCell(Text(r.avgRating > 0 ? '${r.avgRating.toStringAsFixed(1)}★' : '—', style: const TextStyle(fontSize: 11, color: Color(0xFFD97706)))),
                                ]);
                              }).toList(),
                            ),
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  _buildAiPanel(context, provider),
                  const SizedBox(height: 32),
                ],
              ),
            ),
      bottomNavigationBar: TaskFluidBottomNavBar(
        currentIndex: -1,
        unreadCount: workspace.unreadCount,
        onItemSelected: _onBottomNavItemBar,
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
const _tableHeaderStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.bold,
  color: Color(0xFF94A3B8),
  letterSpacing: 0.5,
);

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String content;
  final bool isLoading;

  const _ChatBubble({required this.isUser, required this.content, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser ? _kTeal : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: isUser ? null : Border.all(color: _kBorder),
            ),
            child: isLoading
                ? const SizedBox(width: 20, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: _kTealDark))
                : Text(content, style: TextStyle(fontSize: 12, color: isUser ? Colors.white : _kSlate, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
