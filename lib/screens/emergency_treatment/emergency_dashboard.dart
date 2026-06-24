import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';
import '../../providers/emergency_treatment_provider/emergency_dashboard_provider.dart';
import '../../models/emergency_model/emergency_dashboard_model.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────
const Color _red      = Color(0xFFE53935);
const Color _redDark  = Color(0xFFB71C1C);
const Color _amber    = Color(0xFFF59E0B);
const Color _green    = Color(0xFF10B981);
const Color _card     = Colors.white;

class EmergencyDashboardScreen extends StatefulWidget {
  const EmergencyDashboardScreen({super.key});

  @override
  State<EmergencyDashboardScreen> createState() =>
      _EmergencyDashboardScreenState();
}

class _EmergencyDashboardScreenState extends State<EmergencyDashboardScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmergencyDashboardProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ─── Format helpers ──────────────────────────────────────────────────────
  String _pad2(int n) => n.toString().padLeft(2, '0');
  String _padCount(int n) => n.toString().padLeft(2, '0');

  String _formatClock() {
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final ampm = _now.hour < 12 ? 'AM' : 'PM';
    return '${_pad2(h)}:${_pad2(_now.minute)}:${_pad2(_now.second)} $ampm';
  }

  String _formatDate() {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    const days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    return '${days[_now.weekday % 7]}, ${_now.day} ${months[_now.month - 1]} ${_now.year}';
  }

  String _duration(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final admitted = DateTime.parse(iso).toLocal();
      final diff = _now.difference(admitted);
      final hours = diff.inHours;
      final mins  = diff.inMinutes % 60;
      if (hours >= 24) {
        final days = hours ~/ 24;
        return '${days}d ${hours % 24}h';
      }
      return '${hours}h ${mins}m';
    } catch (_) {
      return '—';
    }
  }

  String _callTimer(String? calledAt) {
    if (calledAt == null || calledAt.isEmpty) return '00:00';
    try {
      final start = DateTime.parse(calledAt).toLocal();
      final secs  = _now.difference(start).inSeconds.clamp(0, 99999);
      final m = secs ~/ 60;
      final s = secs % 60;
      return '${_pad2(m)}:${_pad2(s)}';
    } catch (_) {
      return '00:00';
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ap = dt.hour < 12 ? 'AM' : 'PM';
      return '${_pad2(h)}:${_pad2(dt.minute)} $ap';
    } catch (_) {
      return '—';
    }
  }

  // ─── Status config ───────────────────────────────────────────────────────
  Map<String, dynamic> _statusCfg(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'critical':
        return {'color': _red,   'bg': const Color(0xFFFFF1F1), 'label': 'Critical', 'icon': Icons.error_rounded};
      case 'serious':
        return {'color': _amber, 'bg': const Color(0xFFFFFBEB), 'label': 'Serious',  'icon': Icons.warning_rounded};
      default:
        return {'color': _green, 'bg': const Color(0xFFF0FDF4), 'label': 'Stable',   'icon': Icons.check_circle_rounded};
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Emergency Dashboard',
      drawerIndex: 24,
      body: Consumer<EmergencyDashboardProvider>(
        builder: (_, prov, __) {
          return RefreshIndicator(
            onRefresh: prov.refreshAll,
            color: _red,
            child: _buildBody(prov),
          );
        },
      ),
    );
  }

  Widget _buildBody(EmergencyDashboardProvider prov) {
    if (prov.isLoading && prov.data == null) {
      return const Center(child: CustomLoader(size: 50, color: _red));
    }

    final data  = prov.data;
    final beds  = data?.beds  ?? [];
    final logs  = prov.serviceLogs;
    final queue = prov.queue;

    final apiStats = data?.stats;

    // Local calculation from beds list
    final localTotal = beds.length;
    final localOccupied = beds.where((b) => b.isOccupied).length;
    final localVacant = beds.where((b) => !b.isOccupied).length;

    final localCritical = beds.where((b) => (b.patientStatus ?? '').trim().toLowerCase() == 'critical').length;
    final localSerious = beds.where((b) => (b.patientStatus ?? '').trim().toLowerCase() == 'serious').length;
    final localStable = beds.where((b) =>
        b.isOccupied &&
        (b.patientStatus ?? '').trim().toLowerCase() != 'critical' &&
        (b.patientStatus ?? '').trim().toLowerCase() != 'serious').length;

    // Use API values if they are positive/greater than 0, otherwise fallback to local calculation
    final total = (apiStats != null && apiStats.total > 0) ? apiStats.total : localTotal;
    final occupied = (apiStats != null && apiStats.occupied > 0) ? apiStats.occupied : localOccupied;
    final vacant = (apiStats != null && apiStats.vacant > 0) ? apiStats.vacant : localVacant;

    // If API returned status counts (at least one is non-zero), use them.
    // Otherwise, or if they are all 0 but we have occupied beds, fallback to local counts.
    final bool hasApiStatusCounts = apiStats != null &&
        (apiStats.critical > 0 || apiStats.serious > 0 || apiStats.stable > 0);

    final critical = hasApiStatusCounts ? apiStats.critical : localCritical;
    final serious = hasApiStatusCounts ? apiStats.serious : localSerious;
    final stable = hasApiStatusCounts ? apiStats.stable : localStable;

    final EmergencyBedStatsModel stats = EmergencyBedStatsModel(
      total: total,
      occupied: occupied,
      vacant: vacant,
      critical: critical,
      serious: serious,
      stable: stable,
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _clockRow(),
          const SizedBox(height: 12),
          _summaryCards(stats, queue.length),
          const SizedBox(height: 14),
          _sectionHeader(
            icon: Icons.bed_rounded,
            title: 'Current Bed Matrix',
            badge: prov.filterMr.isNotEmpty ? 'Filtering: MR ${prov.filterMr}' : null,
            onClearBadge: prov.filterMr.isNotEmpty ? () => prov.clearFilter() : null,
          ),
          const SizedBox(height: 8),
          _bedMatrix(prov, beds),
          const SizedBox(height: 18),
          _sectionHeader(
            icon: Icons.receipt_long_rounded,
            title: 'Treatment Logs',
            badge: prov.filterMr.isNotEmpty ? 'MR: ${prov.filterMr}' : null,
            onClearBadge: prov.filterMr.isNotEmpty ? () => prov.clearFilter() : null,
            trailing: prov.logsLoading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _red))
                : null,
          ),
          const SizedBox(height: 8),

          // Patient MR filter input
          _mrFilterInput(prov),
          const SizedBox(height: 8),
          _treatmentLogs(prov, logs),
        ],
      ),
    );
  }

  // ─── Clock Row ───────────────────────────────────────────────────────────
  Widget _clockRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_red, _redDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11, letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(_formatClock(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  // ─── Summary Cards ───────────────────────────────────────────────────────
  Widget _summaryCards(EmergencyBedStatsModel stats, int queueCount) {
    return Column(
      children: [
        // Row 1: Occupied Beds card
        _occupiedBedCard(stats, queueCount),
        const SizedBox(height: 8),
        // Row 2: Critical, Serious, Stable — 3 equal cards
        Row(
          children: [
            Expanded(child: _statusStatCard(
              label: 'Critical',
              count: stats.critical,
              color: _red,
              borderColor: _red,
              bgColor: const Color(0xFFFFF1F1),
            )),
            const SizedBox(width: 8),
            Expanded(child: _statusStatCard(
              label: 'Serious',
              count: stats.serious,
              color: _amber,
              borderColor: _amber,
              bgColor: const Color(0xFFFFFBEB),
            )),
            const SizedBox(width: 8),
            Expanded(child: _statusStatCard(
              label: 'Stable',
              count: stats.stable,
              color: _green,
              borderColor: _green,
              bgColor: const Color(0xFFF0FDF4),
            )),
          ],
        ),
      ],
    );
  }

  Widget _occupiedBedCard(EmergencyBedStatsModel stats, int queueCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: const Icon(Icons.bed_rounded, color: _red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OCCUPIED / TOTAL BEDS',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8))),
                const SizedBox(height: 3),
                Text(
                  '${_padCount(stats.occupied)} / ${_padCount(stats.total)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontFamily: 'monospace',
                      height: 1.1),
                ),
                Text('Patients in emergency: $queueCount',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          // Vacant chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              '${stats.vacant} vacant',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF059669)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusStatCard({
    required String label,
    required int count,
    required Color color,
    required Color borderColor,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3.5,
                color: borderColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.toUpperCase(),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text(_padCount(count),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontFamily: 'monospace',
                              height: 1.1)),
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

  // ─── Section Header ──────────────────────────────────────────────────────
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String? badge,
    VoidCallback? onClearBadge,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _red, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(badge,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600)),
                if (onClearBadge != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClearBadge,
                    child: const Icon(Icons.close_rounded,
                        size: 12, color: Color(0xFF2563EB)),
                  ),
                ],
              ],
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  // ─── Bed Matrix ──────────────────────────────────────────────────────────
  Widget _bedMatrix(EmergencyDashboardProvider prov, List<EmergencyBedModel> beds) {
    if (prov.isLoading && beds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CustomLoader(size: 40, color: _red)),
      );
    }
    if (beds.isEmpty) {
      return _emptyCard('No Emergency beds configured.\nGo to Setup → Bed Setup to add beds.');
    }

    // Use ListView of rows (2 per row) so height is natural — no fixed aspect ratio
    final rows = <Widget>[];
    for (int i = 0; i < beds.length; i += 2) {
      final left  = beds[i];
      final right = i + 1 < beds.length ? beds[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _bedCard(prov, left)),
            const SizedBox(width: 10),
            Expanded(
              child: right != null
                  ? _bedCard(prov, right)
                  : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < beds.length) rows.add(const SizedBox(height: 10));
    }

    return Column(children: rows);
  }

  Widget _bedCard(EmergencyDashboardProvider prov, EmergencyBedModel bed) {
    if (bed.isOccupied) {
      return _occupiedBedCard2(prov, bed);
    } else {
      return _vacantBedCard(prov, bed);
    }
  }

  Widget _occupiedBedCard2(EmergencyDashboardProvider prov, EmergencyBedModel bed) {
    final cfg = _statusCfg(bed.patientStatus);
    final Color statusColor  = cfg['color'] as Color;
    final Color statusBg     = cfg['bg'] as Color;      // ← colored card background
    final String statusLabel = cfg['label'] as String;
    final bool isFiltered    = prov.filterMr == bed.patientMrNumber;

    // Active doctor call for this patient
    final activeCall = prov.activeCallByMr[bed.patientMrNumber ?? ''];

    return GestureDetector(
      onTap: () => prov.setFilterMr(bed.patientMrNumber ?? ''),
      onLongPress: () => _showBedDetailSheet(prov, bed),
      child: Container(
        decoration: BoxDecoration(
          // ✅ React: statusCfg.card = colored background (bg-red-50/80 etc.)
          color: statusBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFiltered
                ? const Color(0xFF60A5FA)   // blue ring when filtered
                : statusColor.withValues(alpha: 0.5),
            width: isFiltered ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: statusColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── TOP: name left | bed# + status badge right ──────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    bed.patientName ?? '—',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(5)),
                      child: Text(bed.bedNumber,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(statusLabel.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── MIDDLE: MR, age/gender, duration, MO, complaint, billing ──
            Text('MR: ${bed.patientMrNumber ?? '—'}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Color(0xFF334155))),
            const SizedBox(height: 2),
            Text('${bed.patientAge ?? '—'} · ${bed.patientGender ?? '—'}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                      text: 'Since: ',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                  TextSpan(
                      text: _duration(bed.admittedSince),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD97706))), // amber
                ],
              ),
            ),
            if ((bed.mo ?? '').isNotEmpty) ...[  
              const SizedBox(height: 2),
              Text('MO: ${bed.mo}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
            if ((bed.complaint ?? '').isNotEmpty) ...[  
              const SizedBox(height: 2),
              Text('Complaint: ${bed.complaint}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],

            // Billing badge (if services total > 0)
            if (bed.servicesTotal > 0) ...[  
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: bed.isBilled
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: bed.isBilled
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rs ${bed.servicesTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: bed.isBilled
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF991B1B)),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: bed.isBilled
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            bed.isBilled ? 'PAID' : 'PENDING',
                            style: const TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
            const SizedBox(height: 5),

            // ── BOTTOM: Release button (left) + Doctor call chip (right) ──
            Row(
              children: [
                // Release button
                GestureDetector(
                  onTap: () async {
                    if (bed.allotmentId == null) return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Release Bed'),
                        content: Text(
                            'Release bed ${bed.bedNumber} from ${bed.patientName ?? 'patient'}?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Release',
                                  style: TextStyle(color: _red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final ok = await prov.releaseBed(bed.allotmentId!);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'Bed released' : 'Failed to release'),
                          backgroundColor: ok ? _green : _red,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 11, color: statusColor),
                        const SizedBox(width: 3),
                        Text('Release',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor)),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Doctor call chip (if active)
                if (activeCall != null)
                  Flexible(
                    child: GestureDetector(
                      onTap: () async {
                        final ok = await prov.endDoctorCall(activeCall.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok
                                ? 'Doctor arrival recorded'
                                : 'Failed to end call'),
                            backgroundColor: ok ? _green : _red,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF99F6E4), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_rounded,
                                size: 10, color: Color(0xFF0F766E)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Dr. ${activeCall.doctorName ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF134E4A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _callTimer(activeCall.calledAt),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF0D9488),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded,
                                  size: 12, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vacantBedCard(EmergencyDashboardProvider prov, EmergencyBedModel bed) {
    return GestureDetector(
      onTap: () => _showAllotSheet(prov, bed),
      child: Container(
        // ✅ React: 'border-emerald-300 bg-emerald-50/40 border-dashed'
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),   // emerald-50
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF6EE7B7),  // emerald-300
              width: 1.5),
        ),
        padding: const EdgeInsets.all(9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top: "Vacant" label + bed number badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vacant',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(bed.bedNumber,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Centre: bed icon + label
            const Icon(Icons.bed_rounded,
                size: 28, color: Color(0xFF34D399)),   // emerald-400
            const SizedBox(height: 6),
            const Text('Tap to allot patient',
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Bed Detail Sheet ────────────────────────────────────────────────────
  void _showBedDetailSheet(EmergencyDashboardProvider prov, EmergencyBedModel bed) {
    final cfg = _statusCfg(bed.patientStatus);
    final Color statusColor = cfg['color'] as Color;
    final String statusLabel = cfg['label'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.bed_rounded, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bed ${bed.bedNumber}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B))),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Patient Info
            _detailRow('Patient', bed.patientName ?? '—'),
            _detailRow('MR #', bed.patientMrNumber ?? '—'),
            _detailRow('Age / Gender',
                '${bed.patientAge ?? '—'} / ${bed.patientGender ?? '—'}'),
            _detailRow('MO', bed.mo ?? '—'),
            _detailRow('Admitted', _duration(bed.admittedSince)),
            if ((bed.complaint ?? '').isNotEmpty)
              _detailRow('Complaint', bed.complaint!),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      prov.setFilterMr(bed.patientMrNumber ?? '');
                    },
                    icon: const Icon(Icons.filter_alt_rounded, size: 16),
                    label: const Text('Filter Logs'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: bed.allotmentId == null ? null : () async {
                      Navigator.pop(context);
                      final ok = await prov.releaseBed(bed.allotmentId!);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'Bed released' : 'Failed to release'),
                          backgroundColor: ok ? _green : _red,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Release Bed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  // ─── Allot Sheet ─────────────────────────────────────────────────────────
  void _showAllotSheet(EmergencyDashboardProvider prov, EmergencyBedModel bed) {
    final unallotted = prov.unallottedPatients;
    if (unallotted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No unallotted patients in queue'),
        backgroundColor: _amber,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    EmergencyQueuePatientModel? selected;
    String selectedStatus = 'stable';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Allot Patient — Bed ${bed.bedNumber}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text('${unallotted.length} patient(s) waiting',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                const SizedBox(height: 14),

                // Patient dropdown
                const Text('Select Patient',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<EmergencyQueuePatientModel>(
                      isExpanded: true,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Choose patient…'),
                      ),
                      value: selected,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      borderRadius: BorderRadius.circular(10),
                      items: unallotted.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.patientName} (${p.patientMrNumber})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (v) => setModal(() => selected = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Status selection
                const Text('Patient Status',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Row(
                  children: ['critical', 'serious', 'stable'].map((s) {
                    final cfg = _statusCfg(s);
                    final Color c = cfg['color'] as Color;
                    final bool isSelected = selectedStatus == s;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() => selectedStatus = s),
                        child: Container(
                          margin: EdgeInsets.only(
                              right: s != 'stable' ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? c : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected ? c : Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(cfg['icon'] as IconData,
                                  color: isSelected ? Colors.white : c,
                                  size: 18),
                              const SizedBox(height: 4),
                              Text(cfg['label'] as String,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : c)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selected == null || prov.allotting
                        ? null
                        : () async {
                            Navigator.pop(context);
                            final ok = await prov.allotBed(
                              bed: bed,
                              patient: selected!,
                              status: selectedStatus,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(ok
                                    ? 'Patient allotted to Bed ${bed.bedNumber}'
                                    : 'Failed to allot bed'),
                                backgroundColor: ok ? _green : _red,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: prov.allotting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Allotment',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── MR Filter Input ─────────────────────────────────────────────────────
  Widget _mrFilterInput(EmergencyDashboardProvider prov) {
    final queue = prov.queue;
    final seenMrs = <String>{};
    final uniqueQueue =
        queue.where((p) => p.patientMrNumber.isNotEmpty && seenMrs.add(p.patientMrNumber)).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: prov.filterMr.isEmpty ? null : prov.filterMr,
          hint: const Text('Filter Logs by Patient...',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          isExpanded: true,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B)),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8)),
          dropdownColor: _card,
          borderRadius: BorderRadius.circular(12),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Patients (No Filter)',
                  style: TextStyle(fontWeight: FontWeight.normal)),
            ),
            ...uniqueQueue.map((p) => DropdownMenuItem<String>(
                  value: p.patientMrNumber,
                  child: Text('${p.patientName} (${p.patientMrNumber})',
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (val) {
            if (val == null) {
              prov.clearFilter();
            } else {
              prov.setFilterMr(val);
            }
          },
        ),
      ),
    );
  }

  // ─── Treatment Logs ──────────────────────────────────────────────────────
  Widget _treatmentLogs(
      EmergencyDashboardProvider prov, List<EmergencyServiceLogModel> logs) {
    if (prov.logsLoading && logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CustomLoader(size: 36, color: _red)),
      );
    }
    if (logs.isEmpty) {
      return _emptyCard('No treatment logs found.');
    }

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _LogHeader('Time')),
                Expanded(flex: 2, child: _LogHeader('MR #')),
                Expanded(flex: 3, child: _LogHeader('Patient')),
                Expanded(flex: 3, child: _LogHeader('Service')),
              ],
            ),
          ),

          // Table rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (_, i) {
              final log = logs[i];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: i.isEven ? Colors.white : const Color(0xFFFAFAFA),
                child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text(_fmtTime(log.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)))),
                    Expanded(
                        flex: 2,
                        child: Text(log.patientMrNumber ?? '—',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis)),
                    Expanded(
                        flex: 3,
                        child: Text(log.patientName ?? '—',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF475569)),
                            overflow: TextOverflow.ellipsis)),
                    Expanded(
                        flex: 3,
                        child: Text(log.serviceHead ?? '—',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF475569)),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Empty card ──────────────────────────────────────────────────────────
  Widget _emptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.bed_outlined, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// ─── Log table header cell ────────────────────────────────────────────────────
class _LogHeader extends StatelessWidget {
  final String text;
  const _LogHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Color(0xFF94A3B8)));
  }
}
