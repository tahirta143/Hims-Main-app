import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../custum widgets/task_management/task_card.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/project_model.dart';
import '../../../models/task_management/task_model.dart';
import '../../../core/services/task_management/task_api_service.dart';
import '../../../providers/task_management/task_list_provider.dart';
import '../dialogs/task_detail_sheet.dart';
import '../dialogs/task_form_dialog.dart';

import 'package:hims_app/custum%20widgets/task_management/task_app_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_bottom_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_workspace_drawer.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import '../task_workspace_screen.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TaskApiService _api = TaskApiService();
  final TextEditingController _searchController = TextEditingController();

  List<TaskItem> _tasks = [];
  List<ProjectItem> _projects = [];
  List<TaskDepartment> _departments = [];

  bool _loading = false;
  String? _statusFilter;
  int? _projectFilter;
  int? _departmentFilter;

  @override
  void initState() {
    super.initState();
    _loadFiltersAndTasks();
  }

  Future<void> _loadFiltersAndTasks() async {
    setState(() => _loading = true);
    await Future.wait([
      _api.fetchProjects().then((r) { if (r.success && r.data != null) _projects = r.data!; }),
      _api.fetchDepartments().then((r) { if (r.success && r.data != null) _departments = r.data!; }),
      _loadTasks(),
    ]);
    setState(() => _loading = false);
  }

  Future<void> _loadTasks() async {
    final res = await _api.fetchTasks(
      status: _statusFilter,
      projectId: _projectFilter,
      departmentId: _departmentFilter,
    );
    if (res.success && res.data != null) {
      setState(() => _tasks = res.data!);
    }
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
    final filtered = _tasks.where((t) {
      if (query.isEmpty) return true;
      final assignees = t.assignees.map((a) => a.name).join(' ').toLowerCase();
      return t.title.toLowerCase().contains(query) ||
          (t.projectName?.toLowerCase().contains(query) ?? false) ||
          '#${t.id}'.contains(query) ||
          assignees.contains(query);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TaskAppBar(
        title: 'All Tasks',
        subtitle: 'ADMINISTRATION',
        scaffoldKey: _scaffoldKey,
        action: IconButton(
          onPressed: () {
            TaskFormDialog.show(
              context,
              onSaved: (newTask) {
                setState(() => _tasks.insert(0, newTask));
                context.read<TaskListProvider>().upsertTask(newTask);
              },
            );
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      drawer: TaskWorkspaceDrawer(
        activeTabIndex: 10,
        unreadCount: workspace.unreadCount,
        isAdmin: true,
        onTabSelected: _onBottomNavItemBar,
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TaskColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search every task…',
                      hintStyle: TextStyle(fontSize: 12, color: TaskColors.slateLight),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: TaskColors.slateLight),
                      prefixIconConstraints: BoxConstraints(minWidth: 32),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status dropdown
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: TaskColors.border),
                        ),
                        child: DropdownButton<String?>(
                          value: _statusFilter,
                          hint: const Text('All statuses', style: TextStyle(fontSize: 11, color: TaskColors.slateMuted)),
                          underline: const SizedBox.shrink(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: TaskColors.slateMuted),
                          style: const TextStyle(fontSize: 11, color: TaskColors.slateText),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All statuses')),
                            ...StatusMeta.map.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.label))),
                          ],
                          onChanged: (v) {
                            setState(() => _statusFilter = v);
                            _loadTasks();
                          },
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Project dropdown
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: TaskColors.border),
                        ),
                        child: DropdownButton<int?>(
                          value: _projectFilter,
                          hint: const Text('All projects', style: TextStyle(fontSize: 11, color: TaskColors.slateMuted)),
                          underline: const SizedBox.shrink(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: TaskColors.slateMuted),
                          style: const TextStyle(fontSize: 11, color: TaskColors.slateText),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All projects')),
                            ..._projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                          ],
                          onChanged: (v) {
                            setState(() => _projectFilter = v);
                            _loadTasks();
                          },
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Department dropdown
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: TaskColors.border),
                        ),
                        child: DropdownButton<int?>(
                          value: _departmentFilter,
                          hint: const Text('All departments', style: TextStyle(fontSize: 11, color: TaskColors.slateMuted)),
                          underline: const SizedBox.shrink(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: TaskColors.slateMuted),
                          style: const TextStyle(fontSize: 11, color: TaskColors.slateText),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All departments')),
                            ..._departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                          ],
                          onChanged: (v) {
                            setState(() => _departmentFilter = v);
                            _loadTasks();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: TaskColors.border),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent))
                : filtered.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.assignment_outlined,
                        title: 'No tasks found',
                        hint: 'Try clearing or changing your filters.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final task = filtered[idx];
                          return TaskCard(
                            task: task,
                            onTap: () {
                              TaskDetailSheet.show(
                                context,
                                task,
                                onEdit: (t) => TaskFormDialog.show(
                                  context,
                                  task: t,
                                  onSaved: (saved) {
                                    setState(() {
                                      final i = _tasks.indexWhere((x) => x.id == saved.id);
                                      if (i >= 0) _tasks[i] = saved;
                                    });
                                  },
                                ),
                                onDeleted: () {
                                  setState(() => _tasks.removeWhere((x) => x.id == task.id));
                                },
                              );
                            },
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
}
