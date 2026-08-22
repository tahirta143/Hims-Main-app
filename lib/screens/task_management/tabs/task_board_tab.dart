import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../custum widgets/task_management/task_card.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/task_model.dart';
import '../../../providers/task_management/task_list_provider.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import '../dialogs/task_detail_sheet.dart';
import '../dialogs/task_form_dialog.dart';

class TaskBoardTab extends StatefulWidget {
  const TaskBoardTab({super.key});

  @override
  State<TaskBoardTab> createState() => _TaskBoardTabState();
}

class _TaskBoardTabState extends State<TaskBoardTab> with SingleTickerProviderStateMixin {
  late TabController _columnTabController;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _columns = [
    {'key': 'pending', 'title': 'Pending'},
    {'key': 'in_progress', 'title': 'In Progress'},
    {'key': 'completed', 'title': 'Completed'},
  ];

  @override
  void initState() {
    super.initState();
    _columnTabController = TabController(length: _columns.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskListProvider>().loadTasks();
    });
  }

  @override
  void dispose() {
    _columnTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleStatusMove(TaskItem task, String targetStatus) async {
    final workspace = context.read<TaskWorkspaceProvider>();
    final isAdmin = workspace.me?.isAdmin ?? false;

    if (targetStatus == 'completed' && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only an administrator can mark a task complete.')),
      );
      return;
    }
    if (task.status == 'in_progress' && targetStatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work already in progress cannot go back to pending.')),
      );
      return;
    }

    final ok = await context.read<TaskListProvider>().moveTask(task.id, targetStatus);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not move that task.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    final taskList = context.watch<TaskListProvider>();
    final canViewAll = workspace.me?.canViewAllTasks ?? workspace.me?.isAdmin ?? false;
    final isAdmin = workspace.me?.isAdmin ?? false;

    final query = _searchController.text.trim().toLowerCase();
    final allItems = taskList.items.where((t) {
      if (query.isEmpty) return true;
      final assignees = t.assignees.map((a) => '${a.name} ${a.employeeCode ?? ''}').join(' ').toLowerCase();
      return t.title.toLowerCase().contains(query) ||
          (t.projectName?.toLowerCase().contains(query) ?? false) ||
          '#${t.id}'.contains(query) ||
          assignees.contains(query);
    }).toList();

    return Column(
      children: [
        // Top Toolbar: Search + Scope switch + New Task
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEDF2F7)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Search board by title, project, assignee…',
                          hintStyle: TextStyle(fontSize: 12, color: TaskColors.slateLight),
                          prefixIcon: Icon(Icons.search_rounded, size: 16, color: TaskColors.slateLight),
                          prefixIconConstraints: BoxConstraints(minWidth: 36),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        TaskFormDialog.show(
                          context,
                          onSaved: (saved) => taskList.upsertTask(saved),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: TaskColors.medicalAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ],
              ),

              if (canViewAll) ...[
                const SizedBox(height: 8),
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => taskList.setScope('mine'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: taskList.scope == 'mine' ? TaskColors.medicalAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'My tasks',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: taskList.scope == 'mine' ? Colors.white : TaskColors.slateMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => taskList.setScope('all'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: taskList.scope == 'all' ? TaskColors.medicalAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'All tasks',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: taskList.scope == 'all' ? Colors.white : TaskColors.slateMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Column Tab Bar
        Container(
          color: Colors.white,
          child:
        TabBar(
          controller: _columnTabController,
          labelColor: TaskColors.medicalAccent,
          unselectedLabelColor: TaskColors.slateMuted,
          indicatorColor: TaskColors.medicalAccent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 2.5,
          tabs: _columns.map((col) {
            final count = allItems.where((t) => t.status == col['key']).length;
            return Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(col['title']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: TaskColors.slateMuted)),
                  ),
                ],
              ),
            );
          }).toList(),
        )),

        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // Column Tab Views
        Expanded(
          child: taskList.loading
              ? const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent))
              : TabBarView(
                  controller: _columnTabController,
                  children: _columns.map((col) {
                    final statusKey = col['key']!;
                    final colTasks = allItems.where((t) => t.status == statusKey).toList();

                    if (colTasks.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.dashboard_outlined,
                        title: 'No ${col['title']} tasks',
                        hint: statusKey == 'completed' && !isAdmin
                            ? 'Only administrators can mark tasks complete.'
                            : 'Tasks will appear here when moved to ${col['title']}.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: colTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final task = colTasks[idx];
                        return TaskCard(
                          task: task,
                          onTap: () {
                            TaskDetailSheet.show(
                              context,
                              task,
                              onEdit: (t) => TaskFormDialog.show(context, task: t, onSaved: (saved) => taskList.upsertTask(saved)),
                            );
                          },
                          onStatusChange: (target) => _handleStatusMove(task, target),
                        );
                      },
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
