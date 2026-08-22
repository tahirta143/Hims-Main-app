import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/task_report_model.dart';
import '../../../core/services/task_management/task_api_service.dart';

const Color _kTeal     = Color(0xFF00B5AD);
const Color _kTealDark = Color(0xFF0D9488);
const Color _kSlate    = Color(0xFF334155);
const Color _kMuted    = Color(0xFF64748B);
const Color _kBg       = Color(0xFFF8FAFC);
const Color _kBorder   = Color(0xFFEDF2F7);

// Colour series for bar chart (matches React SERIES array)
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
  final TaskApiService _api = TaskApiService();

  OverviewReport? _overview;
  List<UserPerformanceReport> _performance = [];
  List<DepartmentSummaryReport> _departments = [];
  bool _loading = true;

  // AI panel state
  String _aiInsights = '';
  bool _aiLoading = false;
  final List<Map<String, String>> _aiHistory = [];
  final TextEditingController _aiPromptCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _aiAsking = false;

  // Chart touch
  int? _barTouched;
  int? _lineTouched;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _aiPromptCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _api.fetchOverviewReport().then((r) {
        if (r.success && r.data != null) _overview = r.data;
      }),
      _api.fetchUserPerformance().then((r) {
        if (r.success && r.data != null) _performance = r.data!;
      }),
      _api.fetchDepartmentSummary().then((r) {
        if (r.success && r.data != null) _departments = r.data!;
      }),
    ]);
    setState(() => _loading = false);
  }

  Future<void> _generateInsights() async {
    setState(() => _aiLoading = true);
    final res = await _api.fetchAiInsights();
    if (res.success && res.data != null) {
      setState(() => _aiInsights = res.data!);
    }
    setState(() => _aiLoading = false);
  }

  Future<void> _sendPrompt() async {
    final q = _aiPromptCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _aiHistory.add({'role': 'user', 'content': q});
      _aiAsking = true;
      _aiPromptCtrl.clear();
    });
    _scrollChatToBottom();
    final res = await _api.sendAiChat(q, history: _aiHistory);
    setState(() {
      _aiHistory.add({
        'role': 'assistant',
        'content': res.success && res.data != null
            ? res.data!
            : (res.message ?? 'The assistant could not answer that.'),
      });
      _aiAsking = false;
    });
    _scrollChatToBottom();
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

  // ── Teal gradient AppBar matching the other screens ───────────────────────
  Widget _buildAppBar(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad + 10, left: 4, right: 16, bottom: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kTeal, _kTealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports',
                  style: TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ADMINISTRATION',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 10, letterSpacing: 0.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat tiles row ────────────────────────────────────────────────────────
  Widget _buildStatTiles() {
    final counts = _overview?.counts ?? const OverviewCounts();
    final activeUsers = _overview?.activeUsers ?? 0;

    final tiles = [
      _StatEntry('TOTAL',      '${counts.total}',      const Color(0xFF334155), Icons.bar_chart_rounded,     const Color(0xFFF1F5F9)),
      _StatEntry('PENDING',    '${counts.pending}',    const Color(0xFF1D4ED8), Icons.pause_circle_outline,  const Color(0xFFEFF6FF)),
      _StatEntry('IN PROGRESS','${counts.inProgress}', _kTeal,                  Icons.access_time_rounded,   const Color(0xFFF0FDFA)),
      _StatEntry('COMPLETED',  '${counts.completed}',  const Color(0xFF059669), Icons.check_circle_outline,  const Color(0xFFECFDF5)),
      _StatEntry('ON HOLD',    '${counts.onHold}',     const Color(0xFFD97706), Icons.warning_amber_rounded,  const Color(0xFFFFFBEB)),
      _StatEntry('ACTIVE STAFF','$activeUsers',         const Color(0xFFBE123C), Icons.trending_up_rounded,   const Color(0xFFFFF1F2)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.55,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) {
          final t = tiles[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.label,
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.4)),
                    Icon(t.icon, size: 11, color: t.accentColor.withOpacity(0.6)),
                  ],
                ),
                Text(
                  t.value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: t.accentColor,
                      letterSpacing: -0.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Line chart — Completed per day ────────────────────────────────────────
  Widget _buildLineChart() {
    final trend = _overview?.completionTrend ?? [];
    return _SectionCard(
      title: 'Completed per day',
      subtitle: 'Last 14 days',
      child: trend.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.trending_up_outlined,
              title: 'No activity yet',
              hint: 'Completed task trend will appear here.')
          : SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (v, _) => v == v.roundToDouble()
                            ? Text('${v.toInt()}',
                                style: const TextStyle(
                                    fontSize: 9, color: TaskColors.slateLight))
                            : const SizedBox.shrink(),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (trend.length / 4).ceilToDouble().clamp(1, 999),
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= trend.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              trend[idx].day,
                              style: const TextStyle(
                                  fontSize: 8, color: TaskColors.slateMuted),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _kSlate,
                      getTooltipItems: (spots) => spots
                          .map((s) => LineTooltipItem(
                                '${trend[s.x.toInt()].day}\n',
                                const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                                children: [
                                  TextSpan(
                                    text: '${s.y.toInt()} completed',
                                    style: const TextStyle(
                                        color: Color(0xFF99F6E4), fontSize: 10),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                    touchCallback: (e, r) {
                      setState(() {
                        _lineTouched = (r?.lineBarSpots?.isNotEmpty == true)
                            ? r!.lineBarSpots!.first.x.toInt()
                            : null;
                      });
                    },
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trend
                          .asMap()
                          .entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value.completed.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: _kTeal,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, idx) => FlDotCirclePainter(
                          radius: idx == _lineTouched ? 5 : 3,
                          color: _kTeal,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _kTeal.withOpacity(0.07),
                      ),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
    );
  }

  // ── Bar chart — Tasks by department ──────────────────────────────────────
  Widget _buildDeptBarChart() {
    final byDept = _overview?.byDepartment ?? [];
    return _SectionCard(
      title: 'Tasks by department',
      child: byDept.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.bar_chart_outlined, title: 'No departments yet')
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
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: '${d.total} tasks',
                              style: const TextStyle(
                                  color: Color(0xFF99F6E4), fontSize: 10),
                            ),
                          ],
                        );
                      },
                    ),
                    touchCallback: (e, r) {
                      setState(() {
                        _barTouched =
                            (r?.spot != null && e.isInterestedForInteractions)
                                ? r!.spot!.touchedBarGroupIndex
                                : null;
                      });
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= byDept.length) {
                            return const SizedBox.shrink();
                          }
                          final n = byDept[idx].departmentName;
                          final short =
                              n.length > 8 ? '${n.substring(0, 7)}…' : n;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(short,
                                style: const TextStyle(
                                    fontSize: 8,
                                    color: TaskColors.slateMuted)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}',
                            style: const TextStyle(
                                fontSize: 9, color: TaskColors.slateLight)),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
                  ),
                  barGroups: byDept.asMap().entries.map((e) {
                    final isTouched = e.key == _barTouched;
                    final color = _kSeries[e.key % _kSeries.length];
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.total.toDouble(),
                          color: isTouched ? color.withOpacity(0.7) : color,
                          width: 18,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
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
  Widget _buildDeptTable() {
    return _SectionCard(
      title: 'Departments',
      subtitle: 'Staffing and workload per department',
      child: _departments.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.bar_chart_outlined, title: 'No departments yet')
          : Column(
              children: [
                // Header
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: const [
                      Expanded(
                          flex: 4,
                          child: Text('DEPARTMENT',
                              style: _tableHeaderStyle)),
                      Expanded(
                          flex: 2,
                          child: Text('TASKS',
                              textAlign: TextAlign.right,
                              style: _tableHeaderStyle)),
                      Expanded(
                          flex: 2,
                          child: Text('DONE',
                              textAlign: TextAlign.right,
                              style: _tableHeaderStyle)),
                      Expanded(
                          flex: 3,
                          child: Text('COMPLETION',
                              textAlign: TextAlign.right,
                              style: _tableHeaderStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _kBorder),
                ...List.generate(_departments.length, (i) {
                  final d = _departments[i];
                  final rate = d.totalTasks > 0
                      ? ((d.completedTasks / d.totalTasks) * 100).round()
                      : 0;
                  final rateColor = rate >= 75
                      ? const Color(0xFF059669)
                      : rate >= 40
                          ? const Color(0xFFD97706)
                          : TaskColors.slateMuted;
                  final rateBg = rate >= 75
                      ? const Color(0xFFECFDF5)
                      : rate >= 40
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF8FAFC);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 4,
                                child: Text(d.departmentName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _kSlate))),
                            Expanded(
                                flex: 2,
                                child: Text('${d.totalTasks}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: TaskColors.slateMuted))),
                            Expanded(
                                flex: 2,
                                child: Text('${d.completedTasks}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF059669)))),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: rateBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('$rate%',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: rateColor)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < _departments.length - 1)
                        const Divider(
                            height: 1,
                            color: _kBorder,
                            indent: 12,
                            endIndent: 12),
                    ],
                  );
                }),
              ],
            ),
    );
  }

  // ── Staff performance table ───────────────────────────────────────────────
  Widget _buildStaffTable() {
    final top10 = _performance.take(10).toList();
    return _SectionCard(
      title: 'Staff performance',
      subtitle: 'Top 10 by completed work',
      child: top10.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.trending_up_outlined, title: 'No assignments yet')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 52,
                horizontalMargin: 12,
                columnSpacing: 16,
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(
                      label: Text('EMPLOYEE',
                          style: _tableHeaderStyle)),
                  DataColumn(
                      label: Text('DEPT',
                          style: _tableHeaderStyle)),
                  DataColumn(
                      numeric: true,
                      label: Text('ASSIGNED',
                          style: _tableHeaderStyle)),
                  DataColumn(
                      numeric: true,
                      label: Text('DONE',
                          style: _tableHeaderStyle)),
                  DataColumn(
                      numeric: true,
                      label: Text('IN PROG',
                          style: _tableHeaderStyle)),
                  DataColumn(
                      numeric: true,
                      label: Text('PENDING',
                          style: _tableHeaderStyle)),
                  DataColumn(
                      numeric: true,
                      label: Text('RATING',
                          style: _tableHeaderStyle)),
                ],
                rows: top10.map((r) {
                  return DataRow(cells: [
                    DataCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(r.name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kSlate)),
                        Text(
                          r.designation ?? r.employeeCode ?? '',
                          style: const TextStyle(
                              fontSize: 10,
                              color: TaskColors.slateLight),
                        ),
                      ],
                    )),
                    DataCell(Text(r.departmentName ?? '—',
                        style: const TextStyle(
                            fontSize: 11,
                            color: TaskColors.slateMuted))),
                    DataCell(Text('${r.assignedCount}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: TaskColors.slateMuted))),
                    DataCell(Text('${r.completedCount}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669)))),
                    DataCell(Text('${r.inProgressCount}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _kTeal))),
                    DataCell(Text('${r.pendingCount}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: TaskColors.slateMuted))),
                    DataCell(Text(
                      r.avgRating > 0
                          ? '${r.avgRating.toStringAsFixed(1)}★'
                          : '—',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFD97706)),
                    )),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  // ── AI Panel ──────────────────────────────────────────────────────────────
  Widget _buildAiPanel() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Insights card
        Expanded(
          child: _SectionCard(
            title: 'AI insights',
            subtitle: 'A narrative read of the numbers above',
            trailing: GestureDetector(
              onTap: _aiLoading ? null : _generateInsights,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_kTeal, _kTealDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _aiLoading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded,
                            size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _aiLoading
                          ? 'Thinking…'
                          : _aiInsights.isNotEmpty
                              ? 'Regenerate'
                              : 'Generate',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            child: _aiLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(
                          color: TaskColors.medicalAccent),
                    ),
                  )
                : _aiInsights.isNotEmpty
                    ? Text(
                        _aiInsights,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: TaskColors.slateMuted,
                            height: 1.5),
                      )
                    : const EmptyStateWidget(
                        icon: Icons.auto_awesome_rounded,
                        title: 'No insights yet',
                        hint:
                            'Generate a summary of trends and bottlenecks across the current data.',
                      ),
          ),
        ),
        const SizedBox(width: 12),
        // Ask about the data card
        Expanded(
          child: _SectionCard(
            title: 'Ask about the data',
            subtitle: 'Tasks, projects, departments and staff names only',
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: _aiHistory.isEmpty && !_aiAsking
                      ? const EmptyStateWidget(
                          icon: Icons.smart_toy_outlined,
                          title: 'Ask a question',
                          hint:
                              'For example: which department has the most overdue tasks?',
                        )
                      : ListView.builder(
                          controller: _chatScroll,
                          itemCount:
                              _aiHistory.length + (_aiAsking ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _aiHistory.length && _aiAsking) {
                              // Typing indicator
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                          bottomRight: Radius.circular(16),
                                        ),
                                        border: Border.all(
                                            color: _kBorder),
                                      ),
                                      child: const SizedBox(
                                        width: 24,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: TaskColors
                                                .medicalAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final m = _aiHistory[i];
                            final isUser = m['role'] == 'user';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment: isUser
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context)
                                                .size
                                                .width *
                                            0.35),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? _kTeal
                                          : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(
                                            isUser ? 16 : 4),
                                        topRight: Radius.circular(
                                            isUser ? 4 : 16),
                                        bottomLeft:
                                            const Radius.circular(16),
                                        bottomRight:
                                            const Radius.circular(16),
                                      ),
                                      border: isUser
                                          ? null
                                          : Border.all(
                                              color: _kBorder),
                                    ),
                                    child: Text(
                                      m['content'] ?? '',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isUser
                                              ? Colors.white
                                              : _kSlate,
                                          height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aiPromptCtrl,
                        onSubmitted: (_) => _sendPrompt(),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText:
                              'Ask about tasks, projects or workload…',
                          hintStyle: const TextStyle(
                              fontSize: 12,
                              color: TaskColors.slateLight),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: _kBorder),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          _aiAsking ? null : _sendPrompt,
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 16),
                      style: IconButton.styleFrom(
                        backgroundColor: _kTeal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        disabledBackgroundColor:
                            _kTeal.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: TaskColors.medicalAccent))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatTiles(),
                      const SizedBox(height: 16),
                      // Two charts side-by-side
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildLineChart()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDeptBarChart()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDeptTable(),
                      const SizedBox(height: 16),
                      _buildStaffTable(),
                      const SizedBox(height: 16),
                      _buildAiPanel(),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
const _tableHeaderStyle = TextStyle(
  fontSize: 9,
  fontWeight: FontWeight.bold,
  color: Color(0xFF94A3B8),
  letterSpacing: 0.5,
);

class _StatEntry {
  final String label;
  final String value;
  final Color accentColor;
  final IconData icon;
  final Color bgColor;
  const _StatEntry(
      this.label, this.value, this.accentColor, this.icon, this.bgColor);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 10, color: TaskColors.slateLight)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
