import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:hims_app/custum widgets/drawer/base_scaffold.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../core/services/auth_storage_service.dart';
import '../../custum widgets/custom_loader.dart';
import '../../providers/opd/consultation_provider/cunsultation_provider.dart';
import '../../providers/mr_provider/mr_provider.dart';
import '../../models/consultation_model/doctor_model.dart';
import '../../models/dashboard_model.dart';
import '../../providers/dashboard/dashboard_provider.dart';
import '../../custum widgets/animations/animations.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../global/global_api.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';

import '../cunsultations/cunsultations.dart';
import '../cunsultations/widgets/appointment_dialog.dart';

const Color _teal = Color(0xFF00B5AD);

// ─── Palette & card config (mirrors React CARDS) ─────────────────────────────
class _CardConfig {
  final String key;
  final String label;
  final Color accent;
  final String note;

  const _CardConfig({
    required this.key,
    required this.label,
    required this.accent,
    required this.note,
  });
}

const _kCards = [
  _CardConfig(key: 'opd', label: 'OPD', accent: Color(0xFF0D9488), note: 'Excludes consultation, lab & emergency'),
  _CardConfig(key: 'consultation', label: 'Consultation', accent: Color(0xFF4F46E5), note: 'Doctor & hospital split'),
  _CardConfig(key: 'emergency', label: 'Emergency', accent: Color(0xFFE11D48), note: 'Emergency receipts & bills'),
  _CardConfig(key: 'lab', label: 'Laboratory', accent: Color(0xFF7C3AED), note: 'OPD receipts billed to lab'),
  _CardConfig(key: 'expenses', label: 'Expenses', accent: Color(0xFFC2410C), note: 'Direct expenses recorded'),
  _CardConfig(key: 'revenue', label: 'Net Revenue', accent: Color(0xFF047857), note: 'Collected less shares & expenses'),
];

// ─────────────────────────────────────────────
//  NUMBER HELPERS
// ─────────────────────────────────────────────
String _money(double v) => NumberFormat('#,###').format(v.round());
String _fmt(num v) => NumberFormat('#,###').format(v);
String _compact(double v) {
  final abs = v.abs();
  if (abs >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
  if (abs >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
  if (abs >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.round().toString();
}

String _format12h(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return '';
  try {
    final parts = timeStr.split(':');
    final h = int.parse(parts[0]);
    final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $suffix';
  } catch (_) {
    return timeStr;
  }
}

// ─────────────────────────────────────────────
//  ANIMATED COUNTER WIDGET
// ─────────────────────────────────────────────
class _AnimatedCounter extends StatefulWidget {
  final double targetValue;
  final bool isCurrency;
  final TextStyle style;

  const _AnimatedCounter({
    required this.targetValue,
    required this.isCurrency,
    required this.style,
  });

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.targetValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.targetValue != widget.targetValue) {
      _previousValue = old.targetValue;
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.targetValue,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) {
        final val = _animation.value;
        final text = widget.isCurrency
            ? 'PKR ${_money(val)}'
            : _fmt(val.round());
        return Text(text, style: widget.style);
      },
    );
  }
}

// ─────────────────────────────────────────────
//  MINI STAT (inside stat card)
// ─────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MiniStat({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF334155),
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 8, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: valueColor,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STAT CARD WIDGET (matches React StatCard)
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final _CardConfig card;
  final ManagementSummary? summary;
  final bool selected;
  final VoidCallback onTap;

  const _StatCard({
    required this.card,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  DashboardCategory get _cat {
    if (summary == null) return DashboardCategory.empty();
    switch (card.key) {
      case 'opd': return summary!.opd;
      case 'consultation': return summary!.consultation;
      case 'emergency': return summary!.emergency;
      case 'lab': return summary!.lab;
      case 'expenses': return summary!.expenses;
      default: return DashboardCategory.empty();
    }
  }

  DashboardRevenue get _rev => summary?.revenue ?? DashboardRevenue.empty();

  bool get _isRevenue => card.key == 'revenue';
  bool get _isConsult => card.key == 'consultation';
  double get _amount => _isRevenue ? _rev.net : _cat.amount;
  int get _count => _isRevenue
      ? (summary != null
          ? summary!.opd.qty + summary!.consultation.qty + summary!.emergency.qty + summary!.lab.qty
          : 0)
      : _cat.qty;
  bool get _profit => !_isRevenue || _rev.net >= 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _isRevenue && !_profit
              ? const Color(0xFFFFF1F2)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? card.accent : const Color(0xFFEDF2F7),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: card.accent.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: card.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      card.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (_isRevenue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _profit
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _profit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 8,
                          color: _profit ? const Color(0xFF059669) : const Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _profit ? 'Profit' : 'Loss',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: _profit ? const Color(0xFF059669) : const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _fmt(_count),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),

            // Animated amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'PKR',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: _isRevenue
                        ? (_profit ? const Color(0xFF059669).withValues(alpha: 0.6) : const Color(0xFFE11D48).withValues(alpha: 0.6))
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: _AnimatedCounter(
                    targetValue: _amount,
                    isCurrency: false,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _isRevenue
                          ? (_profit ? const Color(0xFF059669) : const Color(0xFFE11D48))
                          : const Color(0xFF0F172A),
                      fontFamily: 'monospace',
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),

            // Mini stats
            if (_isRevenue) ...[
              Row(
                children: [
                  _MiniStat(label: 'Coll', value: _compact(_rev.collected)),
                  const SizedBox(width: 2),
                  _MiniStat(label: 'Dr.', value: _compact(-_rev.drShare), valueColor: const Color(0xFFE11D48)),
                  const SizedBox(width: 2),
                  _MiniStat(label: 'Exp', value: _compact(-_rev.expenses), valueColor: const Color(0xFFF97316)),
                ],
              ),
            ] else if (_isConsult) ...[
              Row(
                children: [
                  _MiniStat(label: 'Dr. Share', value: _compact(_cat.drShare), valueColor: const Color(0xFFE11D48)),
                  const SizedBox(width: 2),
                  _MiniStat(label: 'Hospital', value: _compact(_cat.hospitalShare), valueColor: const Color(0xFF059669)),
                ],
              ),
            ] else ...[
              Text(
                card.note,
                style: TextStyle(fontSize: 8.5, color: Colors.grey.shade400),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CATEGORY BAR CHART (matches React BarChart)
// ─────────────────────────────────────────────
class _CategoryBarChart extends StatelessWidget {
  final ManagementSummary? summary;
  final String? selectedCategory;
  final ValueChanged<String?> onSelect;

  const _CategoryBarChart({
    required this.summary,
    required this.selectedCategory,
    required this.onSelect,
  });

  List<Map<String, dynamic>> get _chartData {
    if (summary == null) return [];
    return [
      {'key': 'opd', 'name': 'OPD', 'accent': const Color(0xFF0D9488), 'value': summary!.opd.amount},
      {'key': 'consultation', 'name': 'Consult', 'accent': const Color(0xFF4F46E5), 'value': summary!.consultation.amount},
      {'key': 'emergency', 'name': 'Emerg', 'accent': const Color(0xFFE11D48), 'value': summary!.emergency.amount},
      {'key': 'lab', 'name': 'Lab', 'accent': const Color(0xFF7C3AED), 'value': summary!.lab.amount},
      {'key': 'expenses', 'name': 'Expense', 'accent': const Color(0xFFC2410C), 'value': summary!.expenses.amount},
      {
        'key': 'revenue',
        'name': 'Net Rev',
        'accent': summary!.revenue.net >= 0 ? const Color(0xFF047857) : const Color(0xFFE11D48),
        'value': summary!.revenue.net,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final data = _chartData;

    if (data.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('No data', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ),
      );
    }

    final maxVal = data.map((d) => (d['value'] as double).abs()).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance by category',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap a bar to drill in',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxVal > 0 ? maxVal * 1.2 : 100,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal > 0 ? maxVal / 4 : 25,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.shade100,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (val, _) => Text(
                      _compact(val),
                      style: const TextStyle(fontSize: 8, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (val, _) {
                      final i = val.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          data[i]['name'] as String,
                          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  if (event is FlTapUpEvent && response?.spot != null) {
                    final key = data[response!.spot!.touchedBarGroupIndex]['key'] as String;
                    onSelect(key);
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1E293B),
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIdx, rod, rodIdx) {
                    final d = data[groupIdx];
                    return BarTooltipItem(
                      '${d['name']}\nPKR ${_money(d['value'] as double)}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              barGroups: List.generate(data.length, (i) {
                final d = data[i];
                final key = d['key'] as String;
                final accent = d['accent'] as Color;
                final isSelected = selectedCategory == null || selectedCategory == key;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: (d['value'] as double).abs(),
                      width: 24,
                      color: accent.withValues(alpha: isSelected ? 1.0 : 0.28),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                  ],
                );
              }),
            ),
            swapAnimationDuration: Duration.zero,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  BREAKDOWN PANEL (matches React DrillDownTable)
// ─────────────────────────────────────────────
class _BreakdownPanel extends StatelessWidget {
  final String? selectedCategory;
  final ManagementSummary? summary;
  final VoidCallback onClear;
  final ValueChanged<DashboardHead> onRowTap;

  const _BreakdownPanel({
    required this.selectedCategory,
    required this.summary,
    required this.onClear,
    required this.onRowTap,
  });

  _CardConfig? get _card {
    if (selectedCategory == null) return null;
    try {
      return _kCards.firstWhere((c) => c.key == selectedCategory);
    } catch (_) {
      return null;
    }
  }

  List<DashboardHead> get _heads {
    if (selectedCategory == null || summary == null) return [];
    if (selectedCategory == 'revenue') {
      return [
        DashboardHead(name: 'OPD', qty: summary!.opd.qty, amount: summary!.opd.amount, drShare: summary!.opd.drShare),
        DashboardHead(name: 'Consultation', qty: summary!.consultation.qty, amount: summary!.consultation.amount, drShare: summary!.consultation.drShare),
        DashboardHead(name: 'Emergency', qty: summary!.emergency.qty, amount: summary!.emergency.amount, drShare: summary!.emergency.drShare),
        DashboardHead(name: 'Laboratory', qty: summary!.lab.qty, amount: summary!.lab.amount, drShare: summary!.lab.drShare),
        DashboardHead(name: 'Doctor Share (deducted)', qty: 0, amount: -summary!.revenue.drShare),
        DashboardHead(name: 'Expenses (deducted)', qty: summary!.expenses.qty, amount: -summary!.revenue.expenses),
      ];
    }
    return summary!.heads[selectedCategory!] ?? [];
  }

  bool get _isConsult => selectedCategory == 'consultation';

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final heads = _heads;
    final totalQty = heads.fold<int>(0, (s, h) => s + h.qty);
    final totalAmount = heads.fold<double>(0, (s, h) => s + h.amount);
    final totalDrShare = heads.fold<double>(0, (s, h) => s + h.drShare);

    final sortedHeads = [...heads];
    if (_isConsult) {
      sortedHeads.sort((a, b) {
        final aName = a.name.replaceFirst(RegExp(r'^(Dr|Doctor)\.?\s+', caseSensitive: false), '').toLowerCase();
        final bName = b.name.replaceFirst(RegExp(r'^(Dr|Doctor)\.?\s+', caseSensitive: false), '').toLowerCase();
        return aName.compareTo(bName);
      });
    } else {
      sortedHeads.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (card != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: card.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card != null ? '${card.label} Breakdown' : 'Breakdown',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card != null
                            ? '${_fmt(sortedHeads.length)} ${_isConsult ? 'doctors' : 'heads'} · tap a row for records'
                            : 'Select a card or bar above to view detail',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                if (card != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Content
          if (card == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.ads_click_rounded, color: Colors.grey.shade300, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text('No category selected',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                    const SizedBox(height: 3),
                    Text(
                      'Tap any card or bar above to see the full breakdown.',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (sortedHeads.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  'No ${card.label.toLowerCase()} records in this period.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _isConsult ? 'DOCTOR' : 'HEAD',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('QTY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8), textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8), textAlign: TextAlign.right),
                  ),
                  if (_isConsult)
                    SizedBox(
                      width: 72,
                      child: Text('DR. SHARE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8), textAlign: TextAlign.right),
                    ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sortedHeads.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                itemBuilder: (context, i) {
                  final h = sortedHeads[i];
                  return InkWell(
                    onTap: () => onRowTap(h),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    h.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              _fmt(h.qty),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace'),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              _money(h.amount),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          if (_isConsult)
                            SizedBox(
                              width: 72,
                              child: Text(
                                _money(h.drShare),
                                style: const TextStyle(fontSize: 10, color: Color(0xFFE11D48), fontFamily: 'monospace'),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey.shade300),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.6)),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(_fmt(totalQty), style: const TextStyle(fontSize: 10, color: Color(0xFF334155), fontFamily: 'monospace'), textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _money(totalAmount),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  if (_isConsult)
                    SizedBox(
                      width: 72,
                      child: Text(
                        _money(totalDrShare),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE11D48), fontFamily: 'monospace'),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HEAD DETAIL MODAL (matches React HeadDetailModal)
// ─────────────────────────────────────────────
class _HeadDetailDialog extends StatefulWidget {
  final String category;
  final String label;
  final Color accent;
  final String head;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String shift;

  const _HeadDetailDialog({
    required this.category,
    required this.label,
    required this.accent,
    required this.head,
    required this.dateFrom,
    required this.dateTo,
    required this.shift,
  });

  @override
  State<_HeadDetailDialog> createState() => _HeadDetailDialogState();
}

class _HeadDetailDialogState extends State<_HeadDetailDialog> {
  int _page = 1;
  static const int _pageSize = 50;
  bool _loading = false;
  String? _error;
  int _total = 0;
  List<dynamic> _rows = [];

  bool get _isConsult => widget.category == 'consultation';
  bool get _isExpense => widget.category == 'expenses';

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await AuthStorageService().getToken();
      final fromStr = DateFormat('yyyy-MM-dd').format(widget.dateFrom);
      final toStr = DateFormat('yyyy-MM-dd').format(widget.dateTo);
      final shiftParam = widget.shift == 'All' ? '' : '&shift=${widget.shift}';
      final encodedHead = Uri.encodeComponent(widget.head);
      final url = '${GlobalApi.baseUrl}/reports/management-dashboard/detail?startDate=$fromStr&endDate=$toStr$shiftParam&category=${widget.category}&head=$encodedHead&page=$_page&pageSize=$_pageSize';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final data = json['data'];
          if (mounted) {
            setState(() {
              _total = data['total'] ?? 0;
              _rows = data['rows'] ?? [];
              _loading = false;
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _error = 'Could not load records.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error: $e';
          _loading = false;
        });
      }
    }
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_total / _pageSize).ceil().clamp(1, 9999);
    final firstOnPage = _total == 0 ? 0 : (_page - 1) * _pageSize + 1;
    final lastOnPage = (_page * _pageSize).clamp(0, _total);

    final pageTotalAmount = _rows.fold<double>(0, (s, r) => s + _parseDouble(r['amount']));
    final pageTotalDrShare = _rows.fold<double>(0, (s, r) => s + _parseDouble(r['dr_share']));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dialog Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.head,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.label} · ${_fmt(_total)} record${_total == 1 ? '' : 's'} · ${DateFormat('d MMM yyyy').format(widget.dateFrom)} – ${DateFormat('d MMM yyyy').format(widget.dateTo)}${widget.shift != 'All' ? ' · ${widget.shift} shift' : ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade600),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Dialog Body ──
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
                minHeight: 180,
              ),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CustomLoader(size: 45, color: _teal),
                      ),
                    )
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12)))
                      : _rows.isEmpty
                          ? Center(
                              child: Text(
                                'No records found.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowHeight: 34,
                                    dataRowMinHeight: 36,
                                    dataRowMaxHeight: 44,
                                    horizontalMargin: 16,
                                    columnSpacing: 18,
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                    columns: [
                                      const DataColumn(label: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      const DataColumn(label: Text('DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      const DataColumn(label: Text('TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      DataColumn(label: Text(_isExpense ? 'VOUCHER' : 'MR NO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      DataColumn(label: Text(_isExpense ? 'RECORDED BY' : 'PATIENT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      DataColumn(label: Text(_isExpense ? 'EXPENSE' : 'SERVICE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      const DataColumn(label: Text('DETAIL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      const DataColumn(label: Text('SHIFT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      const DataColumn(numeric: true, label: Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                      if (_isConsult)
                                        const DataColumn(numeric: true, label: Text('DR. SHARE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)))),
                                    ],
                                    rows: List.generate(_rows.length, (i) {
                                      final r = _rows[i];
                                      final rowIdx = firstOnPage + i;
                                      final date = r['date']?.toString() ?? '—';
                                      final time = r['time']?.toString();
                                      final refOrMr = (_isExpense ? r['ref'] : r['mr_number'])?.toString() ?? '—';
                                      final party = r['party']?.toString() ?? '—';
                                      final service = r['service']?.toString() ?? '—';
                                      final detail = r['detail']?.toString() ?? '—';
                                      final shift = r['shift']?.toString() ?? '—';
                                      final amount = _parseDouble(r['amount']);
                                      final drShare = _parseDouble(r['dr_share']);

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(rowIdx.toString(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace'))),
                                          DataCell(Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                                          DataCell(Text(time != null && time.isNotEmpty ? _format12h(time) : '—', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                                          DataCell(Text(refOrMr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontFamily: 'monospace'))),
                                          DataCell(Text(party, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                                          DataCell(Text(service, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 160),
                                              child: Text(detail, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                              child: Text(shift, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                            ),
                                          ),
                                          DataCell(Text(_money(amount), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'monospace'))),
                                          if (_isConsult)
                                            DataCell(Text(_money(drShare), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48), fontFamily: 'monospace'))),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
            ),

            // ── Dialog Footer (Pagination & Page Totals) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _total == 0
                          ? 'No records'
                          : 'Showing ${_fmt(firstOnPage)}–${_fmt(lastOnPage)} of ${_fmt(_total)} · Total: PKR ${_money(pageTotalAmount)}${_isConsult ? ' · Dr: PKR ${_money(pageTotalDrShare)}' : ''}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _page > 1 && !_loading
                            ? () {
                                setState(() => _page--);
                                _fetchDetail();
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _page > 1 ? Colors.white : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.chevron_left_rounded, size: 14, color: _page > 1 ? Colors.black87 : Colors.grey.shade400),
                              Text('Prev', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _page > 1 ? Colors.black87 : Colors.grey.shade400)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_page / $totalPages',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155), fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _page < totalPages && !_loading
                            ? () {
                                setState(() => _page++);
                                _fetchDetail();
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _page < totalPages ? Colors.white : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Text('Next', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _page < totalPages ? Colors.black87 : Colors.grey.shade400)),
                              Icon(Icons.chevron_right_rounded, size: 14, color: _page < totalPages ? Colors.black87 : Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ATTENDANCE PANEL (matches React AttendancePanel)
// ─────────────────────────────────────────────
class _AttendancePanel extends StatefulWidget {
  const _AttendancePanel();

  @override
  State<_AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends State<_AttendancePanel> {
  bool _showAll = false;

  ({Color bg, Color text, String label}) _statusTone(AttendanceRecord r) {
    if (r.status == 'Absent') return (bg: const Color(0xFFFFF1F2), text: const Color(0xFFBE123C), label: 'Absent');
    if (r.status == 'Leave') return (bg: const Color(0xFFFFFBEB), text: const Color(0xFFB45309), label: 'Leave');
    if (r.status == 'Half Day') return (bg: const Color(0xFFFFF7ED), text: const Color(0xFFC2410C), label: 'Half Day');
    if (r.lateMinutes > 0) return (bg: const Color(0xFFFEFCE8), text: const Color(0xFF92400E), label: 'Late');
    if (r.status == 'Holiday' || r.status == 'Weekly Off') {
      return (bg: const Color(0xFFF8FAFC), text: const Color(0xFF64748B), label: r.status);
    }
    return (bg: const Color(0xFFECFDF5), text: const Color(0xFF065F46), label: 'Present');
  }

  String _lateLabel(int minutes) {
    if (minutes <= 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, prov, _) {
        final records = prov.attendanceRecords;
        final exceptions = records.where((r) => r.isException).length;
        final visible = _showAll ? records : records.take(8).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attendance',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          if (records.isNotEmpty)
                            RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                                children: [
                                  TextSpan(text: DateFormat('d MMM yyyy').format(prov.dateFrom)),
                                  const TextSpan(text: ' · '),
                                  TextSpan(
                                    text: '${_fmt(exceptions)} needing attention',
                                    style: TextStyle(
                                      color: exceptions > 0 ? const Color(0xFFE11D48) : const Color(0xFF059669),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' of ${_fmt(records.length)}'),
                                ],
                              ),
                            )
                          else
                            Text(DateFormat('d MMM yyyy').format(prov.dateFrom),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                    if (prov.isAttendanceLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey.shade300),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 38, child: Text('ID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8))),
                    Expanded(child: Text('NAME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8))),
                    SizedBox(width: 46, child: Text('IN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8), textAlign: TextAlign.center)),
                    SizedBox(width: 46, child: Text('OUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8), textAlign: TextAlign.center)),
                    SizedBox(width: 34, child: Text('LATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Rows
              if (prov.attendanceError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(prov.attendanceError!, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ),
                )
              else if (!prov.isAttendanceLoading && records.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No attendance recorded for this day.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                    itemBuilder: (context, i) {
                      final r = visible[i];
                      final tone = _statusTone(r);
                      return Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 38,
                              child: Text(
                                r.empId.isEmpty ? '—' : r.empId,
                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: tone.bg,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: tone.text.withValues(alpha: 0.15)),
                                    ),
                                    child: Text(tone.label, style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, color: tone.text)),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    r.employeeName.isEmpty ? '—' : r.employeeName,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 46,
                              child: Text(
                                r.timeIn != null ? _format12h(r.timeIn!.substring(0, r.timeIn!.length > 5 ? 5 : r.timeIn!.length)) : '—',
                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontFamily: 'monospace'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 46,
                              child: Text(
                                r.timeOut != null ? _format12h(r.timeOut!.substring(0, r.timeOut!.length > 5 ? 5 : r.timeOut!.length)) : '—',
                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontFamily: 'monospace'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 34,
                              child: Text(
                                _lateLabel(r.lateMinutes),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: r.lateMinutes > 0 ? FontWeight.w700 : FontWeight.w400,
                                  color: r.lateMinutes > 0 ? const Color(0xFFB45309) : Colors.grey.shade300,
                                  fontFamily: 'monospace',
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              // Show all toggle
              if (records.length > 8) ...[
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                GestureDetector(
                  onTap: () => setState(() => _showAll = !_showAll),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      _showAll ? 'Show exceptions only' : 'Show all ${_fmt(records.length)}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  TASKS PANEL (placeholder, matches React TasksPanel)
// ─────────────────────────────────────────────
class _TasksPanel extends StatelessWidget {
  const _TasksPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tasks',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text('Task management', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.checklist_rounded, color: Colors.grey.shade300, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text('Nothing here yet',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Assigned tasks will appear here once task management is part of the system.',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DOCTOR CARD WIDGET
// ─────────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final DoctorInfo doctor;
  final int availableSlots;
  final Color primaryColor;
  final VoidCallback onTap;

  const _DoctorCard({
    required this.doctor,
    required this.availableSlots,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double cardWidth = screenSize.width * 0.9;
    final double horizontalPadding = screenSize.width * 0.04;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topRight,
        children: [
          Container(
            width: cardWidth,
            margin: EdgeInsets.only(
              top: screenSize.height * 0.02,
              bottom: screenSize.height * 0.015,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenSize.width * 0.04),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctor.name,
                                style: TextStyle(
                                    fontSize: screenSize.width * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            SizedBox(height: screenSize.height * 0.003),
                            Text(doctor.specialty,
                                style: TextStyle(
                                    fontSize: screenSize.width * 0.035,
                                    color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            SizedBox(height: screenSize.height * 0.008),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: screenSize.width * 0.02,
                                  vertical: screenSize.height * 0.004),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius:
                                BorderRadius.circular(screenSize.width * 0.02),
                              ),
                              child: Text('Rs. ${doctor.consultationFee}',
                                  style: TextStyle(
                                      fontSize: screenSize.width * 0.04,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: screenSize.width * 0.28),
                    ],
                  ),
                  SizedBox(height: screenSize.height * 0.015),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: screenSize.width * 0.035, color: Colors.green),
                      SizedBox(width: screenSize.width * 0.01),
                      Text('$availableSlots Slots Available',
                          style: TextStyle(
                              fontSize: screenSize.width * 0.03,
                              color: Colors.green,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  SizedBox(height: screenSize.height * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDayChip('Mon', screenSize, doctor.availableDays.contains('Mon')),
                      _buildDayChip('Tue', screenSize, doctor.availableDays.contains('Tue')),
                      _buildDayChip('Wed', screenSize, doctor.availableDays.contains('Wed')),
                      _buildDayChip('Thu', screenSize, doctor.availableDays.contains('Thu')),
                      _buildDayChip('Fri', screenSize, doctor.availableDays.contains('Fri')),
                      _buildDayChip('Sat', screenSize, doctor.availableDays.contains('Sat')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -screenSize.height * 0.015,
            right: horizontalPadding,
            child: SizedBox(
              width: screenSize.width * 0.32,
              height: screenSize.width * 0.4,
              child: Builder(
                builder: (context) {
                  final url = GlobalApi.getImageUrl(doctor.imageAsset);
                  if (url != null) {
                    return CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      placeholder: (context, _) =>
                          _buildAvatarFallback(screenSize, isChild: true),
                      errorWidget: (context, _, _) =>
                          _buildAvatarFallback(screenSize, isChild: true),
                    );
                  }
                  return _buildAvatarFallback(screenSize, isChild: true);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(Size screenSize, {bool isChild = false}) {
    final avatar = Container(
      width: screenSize.width * 0.28,
      height: screenSize.width * 0.28,
      decoration: BoxDecoration(
        color: doctor.avatarColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(screenSize.width * 0.05),
      ),
      child: Center(
        child: Text(
          doctor.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join('').toUpperCase(),
          style: TextStyle(
              color: doctor.avatarColor,
              fontWeight: FontWeight.bold,
              fontSize: screenSize.width * 0.08),
        ),
      ),
    );
    if (isChild) return Align(alignment: Alignment.bottomCenter, child: avatar);
    return avatar;
  }

  Widget _buildDayChip(String day, Size screenSize, bool isAvailable) {
    return Container(
      width: screenSize.width * 0.12,
      padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.008),
      decoration: BoxDecoration(
        color: isAvailable ? primaryColor : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(screenSize.width * 0.025),
      ),
      child: Center(
        child: Text(day,
            style: TextStyle(
                fontSize: screenSize.width * 0.03,
                fontWeight: FontWeight.bold,
                color: isAvailable ? Colors.white : Colors.grey.shade500)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DASHBOARD BODY (with LayoutBuilder + MediaQuery)
// ─────────────────────────────────────────────
class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  static const Color primaryColor = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<DashboardProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      prov.resetToToday();
      prov.resetLoading();
      prov.refresh();
    });
  }

  String _formatRangeLabel(DateTime from, DateTime to) {
    final fmtDay = DateFormat('yyyy-MM-dd');
    if (fmtDay.format(from) == fmtDay.format(to)) {
      return DateFormat('EEEE, d MMMM yyyy').format(from);
    }
    return '${DateFormat('d MMM yyyy').format(from)} – ${DateFormat('d MMM yyyy').format(to)}';
  }

  void _handleBreakdownRowTap(DashboardHead head, DashboardProvider prov) {
    if (prov.selectedCategory == 'revenue') {
      final target = _kCards.cast<_CardConfig?>().firstWhere(
        (c) => c?.key != 'revenue' && (c?.label.toLowerCase() == head.name.toLowerCase()),
        orElse: () => null,
      );
      if (target != null) {
        prov.setSelectedCategory(target.key);
      }
      return;
    }

    final card = _kCards.cast<_CardConfig?>().firstWhere(
      (c) => c?.key == prov.selectedCategory,
      orElse: () => null,
    );
    if (card == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => _HeadDetailDialog(
        category: prov.selectedCategory!,
        label: card.label,
        accent: card.accent,
        head: head.name,
        dateFrom: prov.dateFrom,
        dateTo: prov.dateTo,
        shift: prov.selectedShiftType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProv = Provider.of<DashboardProvider>(context);
    final consultationProv = Provider.of<ConsultationProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isWide = constraints.maxWidth >= 960;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 960;

        return RefreshIndicator(
          onRefresh: () => dashboardProv.refresh(),
          color: _teal,
          child: CustomPageTransition(
            child: dashboardProv.isLoading
                ? Center(
                    key: const ValueKey('loader'),
                    child: CustomLoader(size: 50, color: _teal))
                : Container(
                    key: const ValueKey('content'),
                    color: const Color(0xFFF8F9FA),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: EdgeInsets.symmetric(
                          horizontal: screenWidth > 800 ? 24 : 16,
                          vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // ── Header & Range Label ────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Dashboard',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.5),
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        _formatRangeLabel(dashboardProv.dateFrom, dashboardProv.dateTo),
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                      ),
                                      if (dashboardProv.selectedShiftType != 'All')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${dashboardProv.selectedShiftType} shift only',
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        )
                                      else if (dashboardProv.runningShift != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 5,
                                                height: 5,
                                                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${dashboardProv.runningShift} shift running',
                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // IconButton(
                            //   icon: const Icon(Icons.offline_pin_rounded, color: _teal),
                            //   tooltip: 'Offline Dashboard',
                            //   onPressed: () => Navigator.pushReplacement(
                            //     context,
                            //     PageRouteBuilder(
                            //       pageBuilder: (context, _, _) => const OfflineDashboardScreen(),
                            //       transitionDuration: Duration.zero,
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── All Filter Controls (Preset / DateFrom / DateTo / Shift / Refresh) ──
                        FadeInDown(
                          duration: const Duration(milliseconds: 350),
                          child: _buildFilterBar(dashboardProv),
                        ),
                        const SizedBox(height: 10),

                        // ── Six Clickable Stat Cards Grid ───────────────────
                        FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          delay: const Duration(milliseconds: 50),
                          child: _buildStatCardsGrid(dashboardProv, isWide, isTablet),
                        ),
                        const SizedBox(height: 12),

                        // ── Performance Category Card with Breakdown Card Directly Below It ──
                        if (isWide) ...[
                          // Wide Screen (Desktop): 2-column layout
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column: Performance Card + Breakdown directly under it
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildGlassPanel(
                                      child: _CategoryBarChart(
                                        summary: dashboardProv.summary,
                                        selectedCategory: dashboardProv.selectedCategory,
                                        onSelect: (key) => dashboardProv.setSelectedCategory(key),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // ⬇️ Breakdown Card directly under performance card
                                    _BreakdownPanel(
                                      selectedCategory: dashboardProv.selectedCategory,
                                      summary: dashboardProv.summary,
                                      onClear: () => dashboardProv.setSelectedCategory(null),
                                      onRowTap: (h) => _handleBreakdownRowTap(h, dashboardProv),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Right column: Monthly Appointments Calendar
                              Expanded(
                                flex: 3,
                                child: _buildCalendarPanel(dashboardProv),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Mobile / Tablet: Stacked layout
                          _buildGlassPanel(
                            child: _CategoryBarChart(
                              summary: dashboardProv.summary,
                              selectedCategory: dashboardProv.selectedCategory,
                              onSelect: (key) => dashboardProv.setSelectedCategory(key),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // ⬇️ Breakdown Card directly under Performance card on Mobile
                          _BreakdownPanel(
                            selectedCategory: dashboardProv.selectedCategory,
                            summary: dashboardProv.summary,
                            onClear: () => dashboardProv.setSelectedCategory(null),
                            onRowTap: (h) => _handleBreakdownRowTap(h, dashboardProv),
                          ),
                          const SizedBox(height: 16),
                          _buildCalendarPanel(dashboardProv),
                        ],
                        const SizedBox(height: 20),

                        // ── Attendance & Tasks Panels (Adaptive Row or Column) ──
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 300),
                          child: isWide || isTablet
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Expanded(flex: 3, child: _AttendancePanel()),
                                    SizedBox(width: 16),
                                    Expanded(flex: 2, child: _TasksPanel()),
                                  ],
                                )
                              : Column(
                                  children: const [
                                    _AttendancePanel(),
                                    SizedBox(height: 16),
                                    _TasksPanel(),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),

                        // ── Revenue Trend ───────────────────────────────────
                        FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          delay: const Duration(milliseconds: 400),
                          child: _buildGlassPanel(
                            title: 'Revenue Trend',
                            subtitle: 'Intraday estimate',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AnimatedCounter(
                                  targetValue: dashboardProv.totalOpdRevenue,
                                  isCurrency: true,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace'),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 120,
                                  child: SfCartesianChart(
                                    key: ValueKey('trend_${dashboardProv.dateFrom}'),
                                    margin: EdgeInsets.zero,
                                    plotAreaBorderWidth: 0,
                                    trackballBehavior: TrackballBehavior(
                                      enable: true,
                                      activationMode: ActivationMode.singleTap,
                                      tooltipDisplayMode: TrackballDisplayMode.nearestPoint,
                                      tooltipSettings: const InteractiveTooltip(
                                        enable: true,
                                        color: Colors.white,
                                        textStyle: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                                        format: 'point.x : PKR point.y',
                                        borderColor: Colors.black12,
                                        borderWidth: 1,
                                      ),
                                      lineType: TrackballLineType.vertical,
                                      lineColor: Colors.grey.shade300,
                                      lineWidth: 1,
                                      markerSettings: const TrackballMarkerSettings(
                                        markerVisibility: TrackballVisibilityMode.visible,
                                        height: 10,
                                        width: 10,
                                        borderWidth: 2,
                                        borderColor: Colors.white,
                                      ),
                                    ),
                                    primaryXAxis: const CategoryAxis(
                                      majorGridLines: MajorGridLines(width: 0),
                                      axisLine: AxisLine(width: 0),
                                      majorTickLines: MajorTickLines(size: 0),
                                      labelStyle: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                    ),
                                    primaryYAxis: const NumericAxis(
                                      isVisible: false,
                                      minimum: 0,
                                    ),
                                    series: <CartesianSeries>[
                                      AreaSeries<ChartDataPoint, String>(
                                        animationDuration: 800,
                                        dataSource: dashboardProv.trendData,
                                        xValueMapper: (ChartDataPoint data, _) => data.x,
                                        yValueMapper: (ChartDataPoint data, _) => data.y,
                                        color: const Color(0xFFCBD5E0).withValues(alpha: 0.35),
                                        borderColor: const Color(0xFF94A3B8),
                                        borderWidth: 1.5,
                                      ),
                                      AreaSeries<ChartDataPoint, String>(
                                        animationDuration: 800,
                                        dataSource: dashboardProv.trendData,
                                        xValueMapper: (ChartDataPoint data, _) => data.x,
                                        yValueMapper: (ChartDataPoint data, _) => data.y * 0.62,
                                        color: const Color(0xFF1E293B).withValues(alpha: 0.88),
                                        borderColor: const Color(0xFF0F172A),
                                        borderWidth: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Available Doctors ───────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Available Doctor',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ConsultationScreen()),
                              ),
                              child: Text('View all',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: primaryColor,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (consultationProv.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (consultationProv.doctors.isEmpty)
                          const Center(child: Text('No doctors available'))
                        else
                          FadeInUp(
                            duration: const Duration(milliseconds: 500),
                            delay: const Duration(milliseconds: 600),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: consultationProv.doctors.length,
                              itemBuilder: (context, index) {
                                final doctor = consultationProv.doctors[index];
                                return _DoctorCard(
                                  doctor: doctor,
                                  availableSlots:
                                  consultationProv.availableSlotsForDoctor(
                                      doctor.name, DateTime.now()),
                                  primaryColor: primaryColor,
                                  onTap: () => _showDialog(
                                      context, consultationProv, doctor),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
          ),
        );
      },
    );
  }

  // ── Filter Bar Widget (Period preset, DateFrom, DateTo, Shift, Refresh) ──
  Widget _buildFilterBar(DashboardProvider prov) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Period preset dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Period: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: prov.selectedPreset,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    items: kRangePresets
                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.label)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) prov.applyPreset(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: prov.selectedShiftType,
                isDense: true,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                items: ['All', 'Morning', 'Evening', 'Night', 'Unassigned']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Shifts' : s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) prov.setSelectedShiftType(val);
                },
              ),
            ),
          ),
          // 2. Date From Picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: prov.dateFrom,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) prov.setDateFrom(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd/MM/yyyy').format(prov.dateFrom),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
          ),

          // 3. Date To Picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: prov.dateTo,
                firstDate: prov.dateFrom,
                lastDate: DateTime(2030),
              );
              if (picked != null) prov.setDateTo(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd/MM/yyyy').format(prov.dateTo),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
          ),


          // // 5. Refresh Button
          // GestureDetector(
          //   onTap: () => prov.refresh(),
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //     decoration: BoxDecoration(
          //       color: const Color(0xFF0F172A),
          //       borderRadius: BorderRadius.circular(12),
          //       boxShadow: [
          //         BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1)),
          //       ],
          //     ),
          //     child: Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         Icon(Icons.refresh_rounded, size: 13, color: Colors.white),
          //         const SizedBox(width: 5),
          //         const Text('Refresh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  // ── Stat Cards Grid LayoutBuilder helper ─────────────────────────────────
  Widget _buildStatCardsGrid(DashboardProvider prov, bool isWide, bool isTablet) {
    final int crossAxisCount = isWide ? 6 : (isTablet ? 3 : 2);
    final double childAspectRatio = isWide ? 1.4 : (isTablet ? 1.6 : 1.55);

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _kCards.length,
      itemBuilder: (context, i) {
        final card = _kCards[i];
        final isSelected = prov.selectedCategory == card.key;
        return _StatCard(
          card: card,
          summary: prov.summary,
          selected: isSelected,
          onTap: () => prov.setSelectedCategory(card.key),
        );
      },
    );
  }

  // ── Glass panel wrapper ───────────────────────────────────────────────────
  Widget _buildGlassPanel({
    String? title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569))),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  // ── Calendar panel ────────────────────────────────────────────────────────
  Widget _buildCalendarPanel(DashboardProvider prov) {
    final calDate = prov.calendarDate;
    return _buildGlassPanel(
      title: 'Monthly Appointments',
      subtitle: 'Tap a date to view details',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _calNavBtn(
            Icons.chevron_left_rounded,
            () => prov.fetchCalendarData(DateTime(calDate.year, calDate.month - 1)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('MMM yyyy').format(calDate),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
          _calNavBtn(
            Icons.chevron_right_rounded,
            () => prov.fetchCalendarData(DateTime(calDate.year, calDate.month + 1)),
          ),
        ],
      ),
      child: prov.isCalendarLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CustomLoader(size: 40, color: _teal),
              ),
            )
          : _buildCalendarGrid(prov),
    );
  }

  Widget _calNavBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildCalendarGrid(DashboardProvider prov) {
    final now = DateTime.now();
    final calDate = prov.calendarDate;  // use calendarDate, not dateFrom
    final firstDay = DateTime(calDate.year, calDate.month, 1);
    final daysInMonth = DateTime(calDate.year, calDate.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7;

    return Column(
      children: [
        // Day-of-week header
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            childAspectRatio: 0.82,
          ),
          itemCount: daysInMonth + startOffset,
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox();
            final day = index - startOffset + 1;
            final dateStr = DateFormat('yyyy-MM-dd').format(
              DateTime(calDate.year, calDate.month, day),
            );
            final data = prov.calendarData[dateStr] ?? {};
            final hasAppts = data.isNotEmpty;
            final isToday = day == now.day &&
                calDate.month == now.month &&
                calDate.year == now.year;

            return GestureDetector(
              onTap: hasAppts ? () => _showAppointmentDetails(dateStr, data) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: hasAppts
                      ? const Color(0xFF0D9488).withValues(alpha: 0.06)
                      : Colors.grey.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isToday
                        ? const Color(0xFF0D9488).withValues(alpha: 0.6)
                        : hasAppts
                            ? Colors.grey.shade200
                            : Colors.transparent,
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 3, top: 2),
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? const Color(0xFF0D9488)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    if (hasAppts) ...[
                      const SizedBox(height: 1),
                      ...data.entries.take(2).map((e) => Padding(
                            padding: const EdgeInsets.only(left: 1.5, right: 1.5, bottom: 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${e.key.replaceFirst('Dr. ', '').split(' ').first} (${e.value.length})',
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Appointment detail modal (matches React Dialog) ───────────────────────
  void _showAppointmentDetails(
      String date, Map<String, List<dynamic>> data) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          decoration: BoxDecoration(
            color: const Color(0xFAFAFCFF),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 15, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(date)),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              // Content
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: data.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No appointments found.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                          ),
                        )
                      : Column(
                          children: data.entries.map((entry) {
                            final doctorName = entry.key;
                            final appointments = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.local_hospital_rounded, size: 14, color: Colors.grey.shade400),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            doctorName,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B)),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${appointments.length} appt${appointments.length != 1 ? 's' : ''}',
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...appointments.asMap().entries.map((e) {
                                    final appt = e.value;
                                    final isLast = e.key == appointments.length - 1;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        border: !isLast ? const Border(bottom: BorderSide(color: Color(0xFFF8FAFC))) : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade400),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  appt['patient_name'] ?? 'Unknown Patient',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF1E293B)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    if (appt['mr_number'] != null) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade50,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: Colors.grey.shade200),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.tag_rounded, size: 9, color: Colors.grey.shade500),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              appt['mr_number'].toString(),
                                                              style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                    ],
                                                    if (appt['slot_time'] != null)
                                                      Row(
                                                        children: [
                                                          Icon(Icons.access_time_rounded, size: 9, color: Colors.grey.shade400),
                                                          const SizedBox(width: 2),
                                                          Text(
                                                            _format12h(appt['slot_time'].toString()),
                                                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (appt['token_number'] != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey.shade200),
                                              ),
                                              child: Text(
                                                '#${appt['token_number']}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF334155),
                                                    fontFamily: 'monospace'),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              // Close button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: Color(0xFF475569))),
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

  void _showDialog(
      BuildContext context, ConsultationProvider prov, DoctorInfo doctor) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: prov),
            ChangeNotifierProvider.value(value: context.read<MrProvider>()),
          ],
          child: AppointmentDialog(
            doctor: doctor,
            availableSlots:
            prov.availableSlotsForDoctor(doctor.name, DateTime.now()),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  HOME SCREEN
// ─────────────────────────────────────────────
class DashboardScreen extends StatelessWidget {
  final bool useScaffold;
  const DashboardScreen({super.key, this.useScaffold = true});

  @override
  Widget build(BuildContext context) {
    if (!useScaffold) return const _DashboardBody();
    return BaseScaffold(
      title: 'Dashboard',
      drawerIndex: 0,
      body: Consumer<PermissionProvider>(
        builder: (context, perm, _) {
          if (!perm.can(Perm.appDashboardRead)) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Color(0xFFCBD5E0)),
                  SizedBox(height: 16),
                  Text('Access Denied',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A5568))),
                  SizedBox(height: 8),
                  Text(
                      'You do not have permission to view the Dashboard.',
                      style: TextStyle(color: Color(0xFF718096))),
                ],
              ),
            );
          }
          return const _DashboardBody();
        },
      ),
    );
  }
}