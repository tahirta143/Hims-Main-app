import 'package:flutter/material.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/task_report_model.dart';
import '../../../core/services/task_management/task_api_service.dart';

import 'package:hims_app/custum%20widgets/task_management/task_app_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_bottom_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_workspace_drawer.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import 'package:provider/provider.dart';
import '../task_workspace_screen.dart';

class AdminScoresScreen extends StatefulWidget {
  const AdminScoresScreen({super.key});

  @override
  State<AdminScoresScreen> createState() => _AdminScoresScreenState();
}

class _AdminScoresScreenState extends State<AdminScoresScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TaskApiService _api = TaskApiService();
  final TextEditingController _searchController = TextEditingController();

  List<UserPerformanceReport> _reports = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    setState(() => _loading = true);
    final res = await _api.fetchUserPerformance();
    if (res.success && res.data != null) {
      _reports = res.data!;
    }
    setState(() => _loading = false);
  }

  void _onBottomNavItemBar(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => TaskWorkspaceScreen(initialTabIndex: index)),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _reports.where((r) {
      if (query.isEmpty) return true;
      return r.name.toLowerCase().contains(query) ||
          (r.departmentName?.toLowerCase().contains(query) ?? false) ||
          (r.designation?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TaskAppBar(
        title: 'Appraisals',
        subtitle: 'ADMINISTRATION',
        scaffoldKey: _scaffoldKey,
      ),
      drawer: TaskWorkspaceDrawer(
        activeTabIndex: 13,
        unreadCount: workspace.unreadCount,
        isAdmin: true,
        onTabSelected: _onBottomNavItemBar,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
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
                  hintText: 'Search staff by name, department…',
                  hintStyle: TextStyle(fontSize: 12, color: TaskColors.slateLight),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: TaskColors.slateLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: TaskColors.border),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent))
                : filtered.isEmpty
                    ? const EmptyStateWidget(icon: Icons.star_border_rounded, title: 'No performance records', hint: 'Completed task ratings will show up here.')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final r = filtered[idx];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: TaskColors.border),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AvatarWidget(name: r.name, id: r.employeeId, size: 34),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
                                          Text(
                                            '${r.designation ?? 'Staff'}${r.departmentName != null ? ' · ${r.departmentName}' : ''}',
                                            style: const TextStyle(fontSize: 10, color: TaskColors.slateMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFBBF24)),
                                        const SizedBox(width: 3),
                                        Text(
                                          r.avgRating > 0 ? r.avgRating.toStringAsFixed(1) : '—',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TaskColors.slateText),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildScoreStat('Assigned', '${r.assignedCount}', TaskColors.slateText),
                                      _buildScoreStat('Completed', '${r.completedCount}', const Color(0xFF059669)),
                                      _buildScoreStat('Overdue', '${r.overdueCount}', const Color(0xFFE11D48)),
                                      _buildScoreStat('Reviews', '${r.ratingCount}', TaskColors.slateMuted),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: TaskFluidBottomNavBar(
        currentIndex: -1,
        unreadCount: workspace.unreadCount,
        onItemSelected: _onBottomNavItemBar,
      ),
    );
  }

  Widget _buildScoreStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: TaskColors.slateLight)),
      ],
    );
  }
}
