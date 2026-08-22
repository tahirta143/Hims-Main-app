import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/task_report_model.dart';
import '../../../core/services/task_management/task_api_service.dart';

class TaskProgressTab extends StatefulWidget {
  const TaskProgressTab({super.key});

  @override
  State<TaskProgressTab> createState() => _TaskProgressTabState();
}

class _TaskProgressTabState extends State<TaskProgressTab> {
  final TaskApiService _api = TaskApiService();
  final TextEditingController _searchController = TextEditingController();

  List<ProgressTaskRow> _rows = [];
  bool _loading = false;
  String _filter = 'all'; // 'all' | 'active' | 'overdue' | 'completed'

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    final res = await _api.fetchProgress();
    if (res.success && res.data != null) {
      _rows = res.data!;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _rows.where((r) {
      if (_filter == 'overdue' && !r.isOverdue) return false;
      if (_filter == 'active' && r.status == 'completed') return false;
      if (_filter == 'completed' && r.status != 'completed') return false;

      if (query.isEmpty) return true;
      final assignees = r.assignees.map((a) => a.name).join(' ').toLowerCase();
      return r.title.toLowerCase().contains(query) ||
          (r.projectName?.toLowerCase().contains(query) ?? false) ||
          (r.departmentName?.toLowerCase().contains(query) ?? false) ||
          assignees.contains(query);
    }).toList();

    // Stats
    final overdueCount = _rows.where((r) => r.isOverdue).length;
    final avgPct = _rows.isNotEmpty
        ? (_rows.fold<double>(0.0, (sum, r) => sum + r.progressPercent) / _rows.length).round()
        : 0;
    final dueSoonCount = _rows.where((r) {
      if (r.dueDate == null || r.status == 'completed') return false;
      try {
        final d = DateTime.parse(r.dueDate!);
        final diff = d.difference(DateTime.now()).inDays;
        return diff >= 0 && diff <= 3;
      } catch (_) {
        return false;
      }
    }).length;

    return RefreshIndicator(
      color: TaskColors.medicalAccent,
      onRefresh: _loadProgress,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stat Tiles Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              StatTileWidget(
                label: 'Tracked',
                value: '${_rows.length}',
                icon: Icons.trending_up_rounded,
                accentColor: const Color(0xFF334155),
                bgColor: const Color(0xFFF8FAFC),
              ),
              StatTileWidget(
                label: 'Avg. Progress',
                value: '$avgPct%',
                icon: Icons.analytics_outlined,
                accentColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFF0FDFA),
              ),
              StatTileWidget(
                label: 'Due in 3 days',
                value: '$dueSoonCount',
                icon: Icons.access_time_rounded,
                accentColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
              StatTileWidget(
                label: 'Overdue',
                value: '$overdueCount',
                icon: Icons.warning_amber_rounded,
                accentColor: const Color(0xFFE11D48),
                bgColor: const Color(0xFFFFF1F2),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search + Filter Buttons
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TaskColors.border),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Search tasks, projects, people…',
                hintStyle: TextStyle(fontSize: 12, color: TaskColors.slateLight),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: TaskColors.slateLight),
                prefixIconConstraints: BoxConstraints(minWidth: 32),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 6),
                _buildFilterChip('active', 'Active'),
                const SizedBox(width: 6),
                _buildFilterChip('overdue', 'Overdue'),
                const SizedBox(width: 6),
                _buildFilterChip('completed', 'Completed'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Task Progress Cards
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: TaskColors.medicalAccent)))
          else if (filtered.isEmpty)
            const EmptyStateWidget(
              icon: Icons.trending_up_rounded,
              title: 'Nothing to show',
              hint: 'No tasks match the current search or filters.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final item = filtered[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.isOverdue ? const Color(0xFFFECDD3) : TaskColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TaskColors.slateText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.projectName != null)
                                  Text(
                                    '${item.projectName}${item.departmentName != null ? ' · ${item.departmentName}' : ''}',
                                    style: const TextStyle(fontSize: 10, color: TaskColors.slateMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          StatusChip(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AvatarStackWidget(people: item.assignees, size: 20),
                          Row(
                            children: [
                              PriorityChip(priority: item.priority),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(item.dueDate),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: item.isOverdue ? const Color(0xFFE11D48) : TaskColors.slateMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (item.totalPoints > 0)
                        TaskProgressBar(
                          done: item.completedPoints,
                          total: item.totalPoints,
                          status: item.status,
                          dueDate: item.dueDate,
                        )
                      else
                        const Text('No checklist points', style: TextStyle(fontSize: 10, color: TaskColors.slateLight, fontStyle: FontStyle.italic)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: TaskColors.medicalAccent,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: isSelected ? Colors.white : TaskColors.slateMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: isSelected ? TaskColors.medicalAccent : TaskColors.border),
      onSelected: (_) => setState(() => _filter = key),
    );
  }
}
