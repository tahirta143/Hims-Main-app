import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/custom_loader.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/permissions/permission_keys.dart';
import '../../core/services/camp_sync_service.dart';



// ─── Constants ────────────────────────────────────────────────────────────────
const _teal = Color(0xFF00B5AD);
const _tealLight = Color(0xFFE6F7F6);
const _bg = Color(0xFFF4F7FA);
const _border = Color(0xFFE2E8F0);
const _textDark = Color(0xFF1A202C);
const _textLight = Color(0xFF718096);

const _daysOfWeek = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _dayAbbr = {
  'Monday': 'Mon', 'Tuesday': 'Tue', 'Wednesday': 'Wed',
  'Thursday': 'Thu', 'Friday': 'Fri', 'Saturday': 'Sat', 'Sunday': 'Sun',
};
const _dayColors = {
  'Monday':    [Color(0xFFDBEAFE), Color(0xFF1D4ED8)],
  'Tuesday':   [Color(0xFFD1FAE5), Color(0xFF065F46)],
  'Wednesday': [Color(0xFFEDE9FE), Color(0xFF5B21B6)],
  'Thursday':  [Color(0xFFFEF3C7), Color(0xFF92400E)],
  'Friday':    [Color(0xFFFFE4E6), Color(0xFF9F1239)],
  'Saturday':  [Color(0xFFCFFAFE), Color(0xFF155E75)],
  'Sunday':    [Color(0xFFFFEDD5), Color(0xFF9A3412)],
};

// ─── Screen wrapper ───────────────────────────────────────────────────────────
class CampDashboardScreen extends StatelessWidget {
  const CampDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Camp Sessions',
      drawerIndex: 102,
      body: Consumer<PermissionProvider>(
        builder: (context, perm, _) {
          if (!perm.can(Perm.campDashboardRead)) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 64, color: Color(0xFFCBD5E0)),
                SizedBox(height: 16),
                Text('Access Denied', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('You do not have permission to view Camp Sessions.', style: TextStyle(color: Color(0xFF718096))),
              ]),
            );
          }
          return const _CampDashboardBody();
        },
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────
class _CampDashboardBody extends StatefulWidget {
  const _CampDashboardBody();
  @override
  State<_CampDashboardBody> createState() => _CampDashboardBodyState();
}

class _CampDashboardBodyState extends State<_CampDashboardBody> {
  final _sync = CampSyncService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _overview = {'totalCamps': 0, 'totalPatients': 0, 'totalPrescriptions': 0};
  List<Map<String, dynamic>> _camps = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() { _loading = true; _error = null; });
    final result = await _sync.getCampStats();
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _overview = (data['overview'] as Map<String, dynamic>?) ?? _overview;
        _camps = List<Map<String, dynamic>>.from(
          (data['camps'] as List?)?.map((c) => Map<String, dynamic>.from(c as Map)) ?? [],
        );
        _loading = false;
      });
    } else {
      setState(() { _error = result['message']?.toString() ?? 'Failed to load'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _camps;
    final q = _search.toLowerCase();
    return _camps.where((c) =>
      (c['name'] ?? '').toString().toLowerCase().contains(q) ||
      (c['location'] ?? '').toString().toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _delete(Map<String, dynamic> camp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Camp'),
        content: Text('Delete "${camp['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _sync.deleteCamp(camp['id'].toString());
    if (!mounted) return;
    if (result['success'] == true) {
      _fetchStats();
    } else {
      setState(() => _error = result['message']?.toString() ?? 'Delete failed');
    }
  }

  void _openForm({Map<String, dynamic>? camp}) {
    showDialog(
      context: context,
      builder: (_) => _CampFormDialog(
        existing: camp,
        onSaved: _fetchStats,
      ),
    );
  }

  void _openTeamsConfig() {
    showDialog(
      context: context,
      builder: (_) => _TeamsConfigDialog(
        camps: _camps,
        onSaved: _fetchStats,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionProvider>();
    final canCreate = perm.can(Perm.campSessionCreate);
    final canUpdate = perm.can(Perm.campSessionUpdate);
    final canDelete = perm.can(Perm.campDashboardDelete);
    final isWide = MediaQuery.of(context).size.width > 820;
    final isMedium = MediaQuery.of(context).size.width > 600;
    final hPad = isWide ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _teal,
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──────────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Camp Sessions',
                              style: TextStyle(fontSize: isWide ? 26 : 22, fontWeight: FontWeight.bold, color: _textDark)),
                          const Text('Medical Camp Statistics & Patient Overview',
                              style: TextStyle(fontSize: 12, color: _textLight)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : _fetchStats,
                      icon: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _teal))
                          : const Icon(Icons.refresh_rounded, color: _teal),
                    ),
                  ],
                ),
                if (canCreate) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _openTeamsConfig,
                        icon: const Icon(Icons.groups_2_outlined, size: 16, color: _teal),
                        label: const Text('Configure Teams', style: TextStyle(fontSize: 12, color: _teal)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _teal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Camp', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Error ────────────────────────────────────────────────────────
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFEB2B2))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Color(0xFFE53E3E), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 12))),
                ]),
              ),

            // ── Stat Cards ───────────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _StatCard(title: 'Total Camps', value: '${_overview['totalCamps'] ?? 0}', icon: Icons.festival_outlined, color: _teal)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Patients', value: '${_overview['totalPatients'] ?? 0}', icon: Icons.people_outline, color: const Color(0xFF38A169))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Prescriptions', value: '${_overview['totalPrescriptions'] ?? 0}', icon: Icons.description_outlined, color: const Color(0xFF805AD5))),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Search ───────────────────────────────────────────────────────
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search camps...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFBDBDBD)),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Camp List ────────────────────────────────────────────────────
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CustomLoader(size: 40, color: _teal)))
            else if (_filtered.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  const Icon(Icons.festival_outlined, size: 48, color: _border),
                  const SizedBox(height: 12),
                  Text(_search.isEmpty ? 'No camps found.' : 'No camps match "$_search".',
                      style: const TextStyle(color: _textLight, fontSize: 13)),
                ]),
              ))
            else if (isMedium)
              // ── Wide/Medium: 2-column grid ──────────────────────────────
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 3 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.15 : 0.95,
                ),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _CampCard(
                  camp: _filtered[i],
                  canUpdate: canUpdate,
                  canDelete: canDelete,
                  onEdit: () => _openForm(camp: _filtered[i]),
                  onDelete: () => _delete(_filtered[i]),
                ),
              )
            else
              // ── Mobile: single column list ──────────────────────────────
              ...(_filtered.map((camp) => _CampCard(
                camp: camp,
                canUpdate: canUpdate,
                canDelete: canDelete,
                onEdit: () => _openForm(camp: camp),
                onDelete: () => _delete(camp),
              ))),
          ]),
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: const Color(0xFFE6F7F6), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 18, color: const Color(0xFF00B5AD)),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF718096), fontWeight: FontWeight.w400)),
      ]),
    );
  }
}

// ─── Camp Card ────────────────────────────────────────────────────────────────
class _CampCard extends StatelessWidget {
  final Map<String, dynamic> camp;
  final bool canUpdate, canDelete;
  final VoidCallback onEdit, onDelete;
  const _CampCard({required this.camp, required this.canUpdate, required this.canDelete, required this.onEdit, required this.onDelete});

  List<String> get _days {
    final raw = camp['days']?.toString() ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final status = (camp['status'] ?? 'active').toString();
    final isActive = status == 'active';
    final days = _days;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        // Top-right: status badge + actions
        Positioned(
          top: 0, right: 0,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE6F7F6) : const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? const Color(0xFF00B5AD) : const Color(0xFFE2E8F0)),
              ),
              child: Text(status.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF00B5AD) : const Color(0xFF718096))),
            ),
            if (canUpdate) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFE6F7F6), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF00B5AD)),
                ),
              ),
            ],
            if (canDelete) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFE53E3E)),
                ),
              ),
            ],
          ]),
        ),

        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon + name
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: const Color(0xFFE6F7F6), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.festival_outlined, size: 18, color: Color(0xFF00B5AD)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                camp['name']?.toString() ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2D3748), height: 1.2),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if ((camp['location'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF718096)),
                  const SizedBox(width: 2),
                  Expanded(child: Text(camp['location'].toString(),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ])),
            // space for the action buttons above
            const SizedBox(width: 80),
          ]),

          const SizedBox(height: 12),

          // Days chips
          if (days.isEmpty)
            const Text('Every day', style: TextStyle(fontSize: 11, color: Color(0xFF718096), fontStyle: FontStyle.italic))
          else
            Wrap(spacing: 4, runSpacing: 4, children: days.map((day) {
              final colors = _dayColors[day] ?? [const Color(0xFFF7FAFC), const Color(0xFF718096)];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colors[0], borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors[1].withValues(alpha: 0.4)),
                ),
                child: Text(_dayAbbr[day] ?? day,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors[1])),
              );
            }).toList()),

          const SizedBox(height: 10),

          // Stats row
          Row(children: [
            _statBadge('${camp['total_patients'] ?? 0}', 'Patients', const Color(0xFF38A169), const Color(0xFFF0FFF4)),
            const SizedBox(width: 8),
            _statBadge('${camp['total_prescriptions'] ?? 0}', 'Rx', const Color(0xFF805AD5), const Color(0xFFFAF5FF)),
            const Spacer(),
            const Icon(Icons.north_east_rounded, size: 12, color: Color(0xFFE2E8F0)),
          ]),
        ]),
      ]),
    );
  }

  Widget _statBadge(String value, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Text('$value $label', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─── Day Selector ─────────────────────────────────────────────────────────────
class _DaySelector extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChange;
  const _DaySelector({required this.selected, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: _daysOfWeek.map((day) {
      final isSelected = selected.contains(day);
      return GestureDetector(
        onTap: () {
          final updated = List<String>.from(selected);
          if (isSelected) { updated.remove(day); } else { updated.add(day); }
          onChange(updated);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? _teal : const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? _teal : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 11, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(_dayAbbr[day] ?? day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : _textLight)),
          ]),
        ),
      );
    }).toList());
  }
}

// ─── Create / Edit Dialog ─────────────────────────────────────────────────────
class _CampFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _CampFormDialog({this.existing, required this.onSaved});

  @override
  State<_CampFormDialog> createState() => _CampFormDialogState();
}

class _CampFormDialogState extends State<_CampFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  List<String> _selectedDays = [];
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!['name']?.toString() ?? '';
      _locCtrl.text = widget.existing!['location']?.toString() ?? '';
      final raw = widget.existing!['days']?.toString() ?? '';
      _selectedDays = raw.isEmpty ? [] : raw.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });

    final sync = CampSyncService();
    final daysStr = _selectedDays.isEmpty ? null : _selectedDays.join(',');
    Map<String, dynamic> result;

    if (_isEdit) {
      result = await sync.updateCamp(
        widget.existing!['id'].toString(),
        {'name': _nameCtrl.text.trim(), 'location': _locCtrl.text.trim(), 'days': daysStr},
      );
    } else {
      result = await sync.createCamp(
        {'name': _nameCtrl.text.trim(), 'location': _locCtrl.text.trim(), 'days': daysStr},
      );
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      Navigator.pop(context);
      widget.onSaved();
    } else {
      setState(() => _error = result['message']?.toString() ?? 'Failed to save');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF7FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _tealLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.festival_outlined, color: _teal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_isEdit ? 'Edit Camp' : 'Create New Camp',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: _textLight, size: 20)),
              ]),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFEB2B2))),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 12)),
                    ),

                  // Camp Name
                  const Text('Camp Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Health Camp - City Center',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                      filled: true, fillColor: const Color(0xFFF8FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE53E3E))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Location
                  const Text('Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _locCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Community Hall',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                      filled: true, fillColor: const Color(0xFFF8FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _teal, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Days
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: _teal),
                    const SizedBox(width: 6),
                    const Text('Camp Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                  ]),
                  const SizedBox(height: 8),
                  _DaySelector(
                    selected: _selectedDays,
                    onChange: (days) => setState(() => _selectedDays = days),
                  ),
                  const SizedBox(height: 4),
                  const Text('Leave empty to make this camp available every day', style: TextStyle(fontSize: 10, color: _textLight)),
                  const SizedBox(height: 20),

                  // Actions
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: _textLight)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_isEdit ? Icons.save_outlined : Icons.add, size: 16),
                      label: Text(_isEdit ? 'Update Camp' : 'Create Camp', style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Teams Config Dialog ──────────────────────────────────────────────────────
/// Mirrors React CampDashboard's isTeamModalOpen section:
/// Configure Team 1 (blue) & Team 2 (emerald) — staff names + camp assignment.
class _TeamsConfigDialog extends StatefulWidget {
  final List<Map<String, dynamic>> camps;
  final VoidCallback onSaved;
  const _TeamsConfigDialog({required this.camps, required this.onSaved});

  @override
  State<_TeamsConfigDialog> createState() => _TeamsConfigDialogState();
}

class _TeamsConfigDialogState extends State<_TeamsConfigDialog> {
  final _sync = CampSyncService();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // team1 / team2 state mirrors React teamData
  Map<String, dynamic> _t1 = {'id': '', 'medical_officer': '', 'nutritionist': '', 'medical_assistant': '', 'camp_id': '', 'assignedCamps': []};
  Map<String, dynamic> _t2 = {'id': '', 'medical_officer': '', 'nutritionist': '', 'medical_assistant': '', 'camp_id': '', 'assignedCamps': []};

  final _t1MoCtrl  = TextEditingController();
  final _t1NutCtrl = TextEditingController();
  final _t1MaCtrl  = TextEditingController();
  final _t2MoCtrl  = TextEditingController();
  final _t2NutCtrl = TextEditingController();
  final _t2MaCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _t1MoCtrl.dispose(); _t1NutCtrl.dispose(); _t1MaCtrl.dispose();
    _t2MoCtrl.dispose(); _t2NutCtrl.dispose(); _t2MaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _sync.getAllTeams();
      List<dynamic> teams = (res['data'] as List?) ?? [];

      // Ensure Team 1 and Team 2 exist (create if missing)
      if (!teams.any((t) => t['team_name'] == 'Team 1')) {
        await _sync.createTeam({'team_name': 'Team 1'});
      }
      if (!teams.any((t) => t['team_name'] == 'Team 2')) {
        await _sync.createTeam({'team_name': 'Team 2'});
      }
      final finalRes = await _sync.getAllTeams();
      teams = (finalRes['data'] as List?) ?? [];

      final t1g = teams.firstWhere((t) => t['team_name'] == 'Team 1', orElse: () => {});
      final t2g = teams.firstWhere((t) => t['team_name'] == 'Team 2', orElse: () => {});

      // Collect already-assigned camp IDs for each team from stats.camps.teams
      final t1AssignedCamps = widget.camps
          .where((c) => (c['teams'] as List?)?.any((t) => t['team_name'] == 'Team 1') == true)
          .map((c) => c['id'].toString()).toList();
      final t2AssignedCamps = widget.camps
          .where((c) => (c['teams'] as List?)?.any((t) => t['team_name'] == 'Team 2') == true)
          .map((c) => c['id'].toString()).toList();

      setState(() {
        _t1 = {
          'id': t1g['id'] ?? '',
          'medical_officer': t1g['medical_officer'] ?? '',
          'nutritionist': t1g['nutritionist'] ?? '',
          'medical_assistant': t1g['medical_assistant'] ?? '',
          'camp_id': '',
          'assignedCamps': t1AssignedCamps,
        };
        _t2 = {
          'id': t2g['id'] ?? '',
          'medical_officer': t2g['medical_officer'] ?? '',
          'nutritionist': t2g['nutritionist'] ?? '',
          'medical_assistant': t2g['medical_assistant'] ?? '',
          'camp_id': '',
          'assignedCamps': t2AssignedCamps,
        };
        _t1MoCtrl.text  = _t1['medical_officer'];
        _t1NutCtrl.text = _t1['nutritionist'];
        _t1MaCtrl.text  = _t1['medical_assistant'];
        _t2MoCtrl.text  = _t2['medical_officer'];
        _t2NutCtrl.text = _t2['nutritionist'];
        _t2MaCtrl.text  = _t2['medical_assistant'];
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load teams: $e'; _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final saves = <Future>[];

      // Update staff info for each team
      if ((_t1['id'] as String).isNotEmpty) {
        saves.add(_sync.updateTeam(_t1['id'], {
          'medical_officer': _t1MoCtrl.text.trim(),
          'nutritionist': _t1NutCtrl.text.trim(),
          'medical_assistant': _t1MaCtrl.text.trim(),
        }));
      }
      if ((_t2['id'] as String).isNotEmpty) {
        saves.add(_sync.updateTeam(_t2['id'], {
          'medical_officer': _t2MoCtrl.text.trim(),
          'nutritionist': _t2NutCtrl.text.trim(),
          'medical_assistant': _t2MaCtrl.text.trim(),
        }));
      }

      // Assign to new camp if selected (and not already assigned)
      final t1Assigned = List<String>.from(_t1['assignedCamps'] ?? []);
      final t2Assigned = List<String>.from(_t2['assignedCamps'] ?? []);

      if ((_t1['camp_id'] as String).isNotEmpty && !t1Assigned.contains(_t1['camp_id'])) {
        saves.add(_sync.assignTeamToCamp(_t1['camp_id'], {
          'team_name': 'Team 1',
          'medical_officer': _t1MoCtrl.text.trim(),
          'nutritionist': _t1NutCtrl.text.trim(),
          'medical_assistant': _t1MaCtrl.text.trim(),
        }));
      }
      if ((_t2['camp_id'] as String).isNotEmpty && !t2Assigned.contains(_t2['camp_id'])) {
        saves.add(_sync.assignTeamToCamp(_t2['camp_id'], {
          'team_name': 'Team 2',
          'medical_officer': _t2MoCtrl.text.trim(),
          'nutritionist': _t2NutCtrl.text.trim(),
          'medical_assistant': _t2MaCtrl.text.trim(),
        }));
      }

      await Future.wait(saves);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      setState(() { _error = 'Failed to save teams: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF7FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(children: [
              const Icon(Icons.groups_2_outlined, color: _teal, size: 22),
              const SizedBox(width: 10),
              const Expanded(child: Text('Configure Teams', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textDark))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: _textLight, size: 20)),
            ]),
          ),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _teal)))
                  : Column(children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFEB2B2))),
                          child: Text(_error!, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 12)),
                        ),
                      _buildTeamSection('team1'),
                      const SizedBox(height: 16),
                      _buildTeamSection('team2'),
                    ]),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: _textLight)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving || _loading ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 16),
                label: const Text('Save Teams', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildTeamSection(String key) {
    final isTeam1 = key == 'team1';
    final team    = isTeam1 ? _t1 : _t2;
    final label   = isTeam1 ? 'Team 1' : 'Team 2';
    
    // Harmonized app color theme (Teal)
    const borderColor = Color(0xFFB2EBE8);
    const headerBg = _tealLight;
    const accent = _teal;

    final moCtrl  = isTeam1 ? _t1MoCtrl  : _t2MoCtrl;
    final nutCtrl = isTeam1 ? _t1NutCtrl : _t2NutCtrl;
    final maCtrl  = isTeam1 ? _t1MaCtrl  : _t2MaCtrl;
    final assigned = List<String>.from(team['assignedCamps'] ?? []);
    final unassigned = widget.camps.where((c) => !assigned.contains(c['id']?.toString())).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Team header with assigned camp badges
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: headerBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(children: [
            const Icon(Icons.groups_2_outlined, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: assigned.isEmpty
                    ? const Text('No camps assigned', style: TextStyle(fontSize: 10, color: _textLight, fontStyle: FontStyle.italic))
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: assigned.map((cid) {
                          final name = widget.camps.firstWhere((c) => c['id']?.toString() == cid, orElse: () => {'name': 'Camp'})['name'] ?? 'Camp';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accent.withValues(alpha: 0.4)),
                            ),
                            child: Text(name.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent)),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ]),
        ),

        // Staff fields
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(child: _staffField('Medical Officer', moCtrl, accent)),
              const SizedBox(width: 10),
              Expanded(child: _staffField('Nutritionist', nutCtrl, accent)),
              const SizedBox(width: 10),
              Expanded(child: _staffField('Medical Asst.', maCtrl, accent)),
            ]),
            const SizedBox(height: 12),

            // Assign to new camp
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                unassigned.isEmpty ? 'Assigned to all camps' : 'Assign to Camp',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textLight),
              ),
            ]),
            const SizedBox(height: 6),
            if (unassigned.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: (team['camp_id'] as String).isEmpty ? null : team['camp_id'],
                decoration: InputDecoration(
                  filled: true, fillColor: const Color(0xFFF8FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent, width: 1.5)),
                ),
                hint: const Text('— Select a camp —', style: TextStyle(fontSize: 12)),
                items: unassigned.map((camp) {
                  return DropdownMenuItem<String>(
                    value: camp['id']?.toString() ?? '',
                    child: Text(camp['name']?.toString() ?? 'Camp', style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  if (isTeam1) {
                    _t1['camp_id'] = v ?? '';
                  } else {
                    _t2['camp_id'] = v ?? '';
                  }
                }),
              )
            else
              Text('This team is already assigned to all available camps.', style: TextStyle(fontSize: 11, color: accent, fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }

  Widget _staffField(String label, TextEditingController ctrl, Color accent) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _textLight)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD)),
          filled: true, fillColor: const Color(0xFFF8FAFB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: accent, width: 1.5)),
        ),
      ),
    ]);
  }
}
