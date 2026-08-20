import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../models/appointment_model/appointments_model.dart';
import '../../models/consultation_model/doctor_model.dart';
import '../../models/consultation_model/appointment_model.dart' as appt_model;
import 'widgets/appointment_dialog.dart';
import '../../providers/appointments_provider/appointments_provider.dart';
import '../../custum widgets/custom_loader.dart';

const Color _teal = Color(0xFF00B5AD);

class AppointmentReportScreen extends StatelessWidget {
  const AppointmentReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppointmentsProvider(),
      child: BaseScaffold(
        title: 'Appointment Report',
        drawerIndex: 11, // update to match your drawer index
        showNotificationIcon: false,
        actions: [const SizedBox(width: 8), _LiveClockBadge()],
        body: const _AppointmentBody(),
      ),
    );
  }
}

// ─── Live Clock Badge ─────────────────────────────────────────────────────────
class _LiveClockBadge extends StatefulWidget {
  @override
  State<_LiveClockBadge> createState() => _LiveClockBadgeState();
}

class _LiveClockBadgeState extends State<_LiveClockBadge> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmtDate(DateTime d) {
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu',
      'Fri', 'Sat', 'Sun'
    ];
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[d.weekday - 1]}, ${months[d.month]} ${d.day}, ${d.year}';
  }

  String _fmtTime(DateTime d) {
    int h = d.hour % 12;
    if (h == 0) h = 12;
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m:$s $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF00B5AD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_fmtDate(_now),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          Text(_fmtTime(_now),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9), fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _AppointmentBody extends StatelessWidget {
  const _AppointmentBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();

    return Container(
      color: const Color(0xFFF0F4F8),
      child: provider.isLoading
          ? const Center(
              child: CustomLoader(
                size: 50,
                color: _teal,
              ),
            )
          : provider.errorMessage != null
          ? _ErrorView(message: provider.errorMessage!)
          : RefreshIndicator(
        color: const Color(0xFF00B5AD),
        onRefresh: () async => provider.refresh(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 136),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filters Card
                    const _FiltersCard(),
                    const SizedBox(height: 16),
                    // Stats Row
                    const _StatsRow(),
                    const SizedBox(height: 16),
                    // Appointments Table
                    const _AppointmentDetailsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: Color(0xFFE53E3E), size: 48),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: Color(0xFF718096))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => context.read<AppointmentsProvider>().refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B5AD),
              foregroundColor: Colors.white),
        ),
      ]),
    );
  }
}

// ─── Screen Header ────────────────────────────────────────────────────────────
// class _ScreenHeader extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return const Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Appointment Report',
//             style: TextStyle(
//                 fontSize: 26,
//                 fontWeight: FontWeight.bold,
//                 color: Color(0xFF1A202C))),
//         SizedBox(height: 2),
//         Text('View and analyze consultant appointments',
//             style: TextStyle(fontSize: 13, color: Color(0xFF718096))),
//       ],
//     );
//   }
// }

// ─── Filters Card ─────────────────────────────────────────────────────────────
class _FiltersCard extends StatelessWidget {
  const _FiltersCard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();
    final sw = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: const Border(
            left: BorderSide(color: Color(0xFF00B5AD), width: 3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF00B5AD).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.filter_alt_outlined,
                  color: Color(0xFF00B5AD), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Filters',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A202C))),
          ]),
          const SizedBox(height: 14),

          // ── Quick filter buttons ───────────────────────────────────
          Row(children: [
            _QuickFilterBtn(label: 'Today'),
            const SizedBox(width: 8),
            _QuickFilterBtn(label: 'This Week'),
            const SizedBox(width: 8),
            _QuickFilterBtn(label: 'Date Range'),
          ]),
          const SizedBox(height: 14),

          // ── Date / Time / Doctor / Status row ──────────────────
          if (sw >= 1100)
            _WideFilterRow()
          else if (sw >= 700)
            const _MediumFilterLayout()
          else
            _NarrowFilterColumn(),
          const SizedBox(height: 12),

          // ── Search + Action Buttons ────────────────────────────────
          if (sw >= 850)
            Row(children: [
              Expanded(child: _SearchField()),
              const SizedBox(width: 16),
              _ActionButtons(),
            ])
          else
            Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchField(),
                  const SizedBox(height: 16),
                  _ActionButtons(),
                ]),
        ],
      ),
    );
  }
}

class _MediumFilterLayout extends StatelessWidget {
  const _MediumFilterLayout();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _DateField(label: 'Date From', isFrom: true)),
        const SizedBox(width: 10),
        Expanded(child: _DateField(label: 'Date To', isFrom: false)),
        const SizedBox(width: 10),
        Expanded(child: _DoctorDropdown()),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _TimeField(label: 'Time From', isFrom: true)),
        const SizedBox(width: 10),
        Expanded(child: _TimeField(label: 'Time To', isFrom: false)),
        const SizedBox(width: 10),
        Expanded(child: _StatusDropdown()),
      ]),
    ]);
  }
}

class _QuickFilterBtn extends StatelessWidget {
  final String label;
  const _QuickFilterBtn({required this.label});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();
    final isActive = provider.quickFilter == label;
    return GestureDetector(
      onTap: () => provider.setQuickFilter(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00B5AD) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive
                  ? const Color(0xFF00B5AD)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF4A5568))),
      ),
    );
  }
}

class _WideFilterRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _DateField(label: 'Date From', isFrom: true)),
        const SizedBox(width: 10),
        Expanded(child: _DateField(label: 'Date To', isFrom: false)),
        const SizedBox(width: 10),
        Expanded(child: _TimeField(label: 'Time From', isFrom: true)),
        const SizedBox(width: 10),
        Expanded(child: _TimeField(label: 'Time To', isFrom: false)),
        const SizedBox(width: 10),
        Expanded(child: _DoctorDropdown()),
        const SizedBox(width: 10),
        Expanded(child: _StatusDropdown()),
      ],
    );
  }
}

class _NarrowFilterColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _DateField(label: 'Date From', isFrom: true)),
        const SizedBox(width: 10),
        Expanded(child: _DateField(label: 'Date To', isFrom: false)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _TimeField(label: 'Time From', isFrom: true)),
        const SizedBox(width: 10),
        Expanded(child: _TimeField(label: 'Time To', isFrom: false)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _DoctorDropdown()),
        const SizedBox(width: 10),
        Expanded(child: _StatusDropdown()),
      ]),
    ]);
  }
}

// ─── Date Field ───────────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  final String label;
  final bool isFrom;
  const _DateField({required this.label, required this.isFrom});

  String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();
    final date = isFrom ? provider.dateFrom : provider.dateTo;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _labelStyle),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(
                    primary: Color(0xFF00B5AD)),
              ),
              child: child!,
            ),
          );
          if (picked != null) {
            if (isFrom) {
              context.read<AppointmentsProvider>().setDateFrom(picked);
            } else {
              context.read<AppointmentsProvider>().setDateTo(picked);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              child: Text(_fmt(date),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1A202C))),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 15, color: Color(0xFFB0BEC5)),
          ]),
        ),
      ),
    ]);
  }
}

// ─── Time Field ───────────────────────────────────────────────────────────────
class _TimeField extends StatelessWidget {
  final String label;
  final bool isFrom;
  const _TimeField({required this.label, required this.isFrom});

  String _fmt(TimeOfDay? t) {
    if (t == null) return '--:-- --';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();
    final time = isFrom ? provider.timeFrom : provider.timeTo;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _labelStyle),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time ?? TimeOfDay.now(),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(
                    primary: Color(0xFF00B5AD)),
              ),
              child: child!,
            ),
          );
          if (picked != null) {
            if (isFrom) {
              context.read<AppointmentsProvider>().setTimeFrom(picked);
            } else {
              context.read<AppointmentsProvider>().setTimeTo(picked);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              child: Text(_fmt(time),
                  style: TextStyle(
                      fontSize: 13,
                      color: time == null
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF1A202C))),
            ),
            const Icon(Icons.access_time,
                size: 15, color: Color(0xFFB0BEC5)),
          ]),
        ),
      ),
    ]);
  }
}

// ─── Doctor Dropdown ──────────────────────────────────────────────────────────
class _DoctorDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();
    final doctors = provider.doctors;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Doctors', style: _labelStyle),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: provider.selectedDoctorId,
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A202C)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            borderRadius: BorderRadius.circular(8),
            items: [
              const DropdownMenuItem(value: 'All', child: Text('All Doctors')),
              ...doctors.map((d) => DropdownMenuItem(
                  value: d.srlNo.toString(),
                  child: Text('Dr. ${d.doctorName}')))
            ],
            onChanged: (v) =>
                context.read<AppointmentsProvider>().setDoctor(v!),
          ),
        ),
      ),
    ]);
  }
}

// ─── Status Dropdown ──────────────────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Status', style: _labelStyle),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: provider.selectedStatus,
            isExpanded: true,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A202C)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            borderRadius: BorderRadius.circular(8),
            items: AppointmentsProvider.statusOptions
                .map((s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s == 'All Status'
                      ? 'All Status'
                      : '${s[0].toUpperCase()}${s.substring(1)}',
                )))
                .toList(),
            onChanged: (v) =>
                context.read<AppointmentsProvider>().setStatus(v!),
          ),
        ),
      ),
    ]);
  }
}

// ─── Search Field ─────────────────────────────────────────────────────────────
class _SearchField extends StatefulWidget {
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: (v) {
        setState(() {});
        context.read<AppointmentsProvider>().setSearch(v);
      },
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText:
        'Search by MR No, Patient Name, Doctor, Contact, Appointment ID...',
        hintStyle:
        const TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
        prefixIcon:
        const Icon(Icons.search, color: Color(0xFFBDBDBD), size: 18),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
            icon: const Icon(Icons.clear,
                color: Color(0xFFBDBDBD), size: 16),
            onPressed: () {
              _ctrl.clear();
              setState(() {});
              context.read<AppointmentsProvider>().clearSearch();
            })
            : null,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
            const BorderSide(color: Color(0xFF00B5AD), width: 1.5)),
        filled: true,
        fillColor: const Color(0xFFF7FAFC),
      ),
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Refresh
        ElevatedButton.icon(
          onPressed: () => context.read<AppointmentsProvider>().refresh(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B5AD),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        // Summarize
        ElevatedButton.icon(
          onPressed: () => context.read<AppointmentsProvider>().toggleSummarized(),
          icon: Icon(
            provider.isSummarized ? Icons.summarize : Icons.summarize_outlined,
            size: 16,
          ),
          label: Text(provider.isSummarized ? 'Summarized' : 'Summarize'),
          style: ElevatedButton.styleFrom(
            backgroundColor: provider.isSummarized ? _teal : _teal.withOpacity(0.1),
            foregroundColor: provider.isSummarized ? Colors.white : _teal,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        // Export CSV (placeholder)
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('CSV export coming soon'),
              behavior: SnackBarBehavior.floating,
            ));
          },
          icon: const Icon(Icons.upload_file_outlined, size: 16),
          label: const Text('Export CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D3748),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        // Print (placeholder)
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Print coming soon'),
              behavior: SnackBarBehavior.floating,
            ));
          },
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text('Print'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A5568),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppointmentsProvider>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _StatCard(label: 'TOTAL', value: p.total.toString()),
        const SizedBox(width: 10),
        _StatCard(
            label: 'BOOKED',
            value: p.booked.toString(),
            valueColor: const Color(0xFF2B6CB0)),
        const SizedBox(width: 10),
        _StatCard(
            label: 'COMPLETED',
            value: p.completed.toString(),
            valueColor: const Color(0xFF276749)),
        const SizedBox(width: 10),
        _StatCard(
            label: 'CANCELLED',
            value: p.cancelled.toString(),
            valueColor: const Color(0xFFE53E3E)),
        const SizedBox(width: 10),
        _StatCard(
            label: 'FIRST VISITS',
            value: p.firstVisits.toString(),
            valueColor: const Color(0xFF2B6CB0)),
        const SizedBox(width: 10),
        _StatCard(
            label: 'FOLLOW-UPS',
            value: p.followUps.toString(),
            valueColor: const Color(0xFFE53E3E)),
        const SizedBox(width: 10),
        _StatCard(
            label: 'REVENUE',
            value: p.formattedRevenue,
            valueColor: const Color(0xFFD69E2E),
            wide: true),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool wide;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF1A202C),
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 160 : 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
            top: BorderSide(color: Color(0xFF00B5AD), width: 2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF718096),
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: wide ? 16 : 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
        ],
      ),
    );
  }
}

// ─── Appointment Details Card ─────────────────────────────────────────────────
class _AppointmentDetailsCard extends StatelessWidget {
  const _AppointmentDetailsCard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();
    final list = provider.filtered;
    final summaries = provider.summarizedData;
    final isSummarized = provider.isSummarized;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B5AD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                    isSummarized ? Icons.summarize : Icons.bike_scooter,
                    color: const Color(0xFF00B5AD),
                    size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isSummarized ? 'Summarized Report' : 'Appointment Details',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C))),
                Text(
                  isSummarized
                      ? 'Grouped by doctor (${summaries.length} doctors)'
                      : 'Showing ${list.length} of ${provider.total} records',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF718096)),
                ),
              ]),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // ── Table ─────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table header
                _TableHeader(),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),

                // Rows
                if (isSummarized)
                  if (summaries.isEmpty)
                    _noDataFound()
                  else
                    ...summaries.asMap().entries.map((e) => _SummaryRow(
                        summary: e.value,
                        index: e.key + 1,
                        isEven: e.key % 2 == 0))
                else if (list.isEmpty)
                  _noDataFound()
                else
                  ...list.asMap().entries.map((e) => _AppointmentRow(
                      appt: e.value,
                      index: e.key + 1,
                      isEven: e.key % 2 == 0)),
              ],
            ),
          ),

          // ── Footer total ───────────────────────────────────────────
          if (isSummarized ? summaries.isNotEmpty : list.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF7FAFC),
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    isSummarized
                        ? 'TOTAL DOCTORS: ${summaries.length}'
                        : 'TOTAL (${list.length} APPOINTMENTS)',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A5568)),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    provider.formattedRevenue,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _noDataFound() => Container(
        width: 1000,
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: Text('No records found',
              style: TextStyle(color: Color(0xFF718096))),
        ),
      );
}

// ─── Table Header ─────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();
    final isSummarized = provider.isSummarized;

    return Container(
      color: const Color(0xFFF7FAFC),
      child: Row(children: isSummarized
          ? [
        _th('SR#', w: 40),
        _th('DOCTOR', w: 200),
        _th('TOTAL', w: 80),
        _th('FIRST', w: 80),
        _th('FOLLOWUP', w: 90),
        _th('BOOKED', w: 80),
        _th('COMPLETED', w: 90),
        _th('CANCELLED', w: 90),
      ]
          : [
        _th('SR#', w: 40),
        _th('DATE', w: 100),
        _th('TOKEN', w: 70),
        _th('SLOT', w: 90),
        _th('MR NO', w: 80),
        _th('PATIENT', w: 130),
        _th('CONTACT', w: 110),
        _th('DOCTOR', w: 110),
        _th('SPECIALIZATION', w: 110),
        _th('TYPE', w: 90),
        _th('FEE', w: 120),
        _th('STATUS', w: 90),
        _th('ACTIONS', w: 120),
      ]),
    );
  }

  Widget _th(String t, {required double w}) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(t,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF718096),
              letterSpacing: 0.5)),
    ),
  );
}

// ─── Appointment Row ──────────────────────────────────────────────────────────
class _AppointmentRow extends StatelessWidget {
  final AppointmentModel appt;
  final int index;
  final bool isEven;

  const _AppointmentRow(
      {required this.appt, required this.index, required this.isEven});

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'booked':
        return const Color(0xFF2B6CB0);
      case 'completed':
        return const Color(0xFF276749);
      case 'cancelled':
        return const Color(0xFFE53E3E);
      default:
        return const Color(0xFF718096);
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'booked':
        return const Color(0xFFEBF8FF);
      case 'completed':
        return const Color(0xFFF0FFF4);
      case 'cancelled':
        return const Color(0xFFFFF5F5);
      default:
        return const Color(0xFFF7FAFC);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? Colors.white : const Color(0xFFFAFAFA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // SR#
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF00B5AD).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(index.toString(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00B5AD))),
                ),
              ),
            ),
          ),
          // DATE
          _cell(appt.formattedDate, w: 100),
          SizedBox(
            width: 70,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF00B5AD).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFF00B5AD).withOpacity(0.2)),
                ),
                child: Center(
                  child: Text(
                    appt.tokenNumber != null ? '#${appt.tokenNumber}' : '-',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00B5AD),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // SLOT
          SizedBox(
            width: 90,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B5AD).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(appt.formattedSlotTime,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00B5AD))),
              ),
            ),
          ),
          // MR NO
          _cell(appt.mrNumber, w: 80, bold: true),
          // PATIENT
          _cell(appt.patientName, w: 130, bold: true),
          // CONTACT
          _cell(appt.patientContact, w: 110),
          // ADDRESS
          // _cell(appt.patientAddress ?? '—', w: 160,
          //     color: appt.patientAddress == null
          //         ? const Color(0xFFBDBDBD)
          //         : null),
          // CONSULTANT
          _cell(appt.doctorName, w: 110, bold: true),
          // SPECIALIZATION
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9F7AEA).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(appt.doctorSpecialization,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B46C1))),
              ),
            ),
          ),
          // TYPE
          SizedBox(
            width: 90,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: (appt.isFirstVisit ? Colors.green : Colors.blue)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(appt.visitType,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: appt.isFirstVisit
                            ? Colors.green[700]
                            : Colors.blue[700])),
              ),
            ),
          ),
          // FEE
          _cell(appt.formattedFee, w: 120, bold: true),
          // STATUS
          SizedBox(
            width: 90,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg(appt.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(appt.statusDisplay,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(appt.status))),
              ),
            ),
          ),
          // ACTIONS
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => _onEdit(context),
                  tooltip: 'Edit',
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => _onCancel(context),
                  tooltip: 'Cancel',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onEdit(BuildContext context) {
    // Map AppointmentModel to DoctorInfo and ConsultationAppointment for the dialog
    final doctor = DoctorInfo(
      id: appt.doctorSrlNo.toString(),
      name: appt.doctorName.startsWith('Dr. ') ? appt.doctorName : 'Dr. ${appt.doctorName}',
      specialty: appt.doctorSpecialization,
      consultationFee: appt.fee.toString(),
      followUpCharges: appt.followUpCharges.toString(),
      availableDays: [], // Not strictly needed for edit
      timings: '${appt.consultationTimeFrom} - ${appt.consultationTimeTo}',
      hospital: 'WMCTH', // Default
      imageAsset: '',
      avatarColor: Colors.blue,
      department: '',
      totalAppointments: 0,
    );

    final consultationAppt = appt.toConsultationAppointment('WMCTH');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppointmentDialog(
        doctor: doctor,
        availableSlots: 10, // Dummy
        editAppointment: consultationAppt,
      ),
    );
  }

  void _onCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text('Are you sure you want to cancel appointment for ${appt.patientName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<AppointmentsProvider>();
              final success = await provider.cancelAppointment(appt.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Appointment cancelled successfully'),
                  backgroundColor: Colors.green,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(provider.errorMessage ?? 'Failed to cancel'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text,
      {required double w,
        bool bold = false,
        Color? color}) =>
      SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                  color: color ?? const Color(0xFF1A202C))),
        ),
      );
}

// ─── Summary Row ──────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final AppointmentSummary summary;
  final int index;
  final bool isEven;

  const _SummaryRow(
      {required this.summary, required this.index, required this.isEven});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? Colors.white : const Color(0xFFFAFAFA),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cell(index.toString(), w: 40),
          _cell(summary.doctorName, w: 200, bold: true),
          _cell(summary.totalCount.toString(), w: 80),
          _cell(summary.firstVisits.toString(), w: 80),
          _cell(summary.followUps.toString(), w: 90),
          _cell(summary.booked.toString(), w: 80),
          _cell(summary.completed.toString(), w: 90),
          _cell(summary.cancelled.toString(), w: 90),
        ],
      ),
    );
  }

  Widget _cell(String text, {required double w, bool bold = false}) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Text(text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: const Color(0xFF1A202C))),
    ),
  );
}

// ─── Shared label style ────────────────────────────────────────────────────────
const TextStyle _labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF718096));