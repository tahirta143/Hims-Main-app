import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/task_model.dart';
import '../../../core/services/task_management/task_api_service.dart';
import '../../../providers/task_management/task_list_provider.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import '../chat/task_chat_screen.dart';

class TaskDetailSheet extends StatefulWidget {
  final TaskItem task;
  final Function(TaskItem)? onEdit;
  final VoidCallback? onDeleted;

  const TaskDetailSheet({
    super.key,
    required this.task,
    this.onEdit,
    this.onDeleted,
  });

  static void show(BuildContext context, TaskItem task, {Function(TaskItem)? onEdit, VoidCallback? onDeleted}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailSheet(
        task: task,
        onEdit: onEdit,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TaskApiService _api = TaskApiService();

  List<TaskEvaluation> _evaluations = [];
  final Map<int, int> _evalRatings = {};
  final Map<int, TextEditingController> _evalRemarksControllers = {};
  int? _savingEmployeeId;
  bool _loadingEvaluations = false;

  late TaskItem _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    final isCompleted = _task.status == 'completed';
    _tabController = TabController(
      length: isCompleted ? 3 : 2,
      vsync: this,
      initialIndex: isCompleted ? 2 : 0,
    );

    if (isCompleted) {
      _loadEvaluations();
    }
  }

  Future<void> _loadEvaluations() async {
    setState(() => _loadingEvaluations = true);
    final res = await _api.fetchEvaluations(_task.id);
    if (res.success && res.data != null) {
      _evaluations = res.data!;
      for (final ev in _evaluations) {
        _evalRatings[ev.employeeId] = ev.rating;
        _evalRemarksControllers[ev.employeeId] = TextEditingController(text: ev.remarks ?? '');
      }
    }
    setState(() => _loadingEvaluations = false);
  }

  Future<void> _saveEvaluation(int employeeId) async {
    setState(() => _savingEmployeeId = employeeId);
    final rating = _evalRatings[employeeId] ?? 0;
    final remarks = _evalRemarksControllers[employeeId]?.text.trim();

    final res = await _api.saveEvaluation(_task.id, employeeId, rating, remarks);
    if (res.success && res.data != null) {
      _evaluations = res.data!;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation saved successfully')),
        );
      }
    }
    setState(() => _savingEmployeeId = null);
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE11D48)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _api.deleteTask(_task.id);
      if (res.success) {
        if (mounted) {
          context.read<TaskListProvider>().removeTask(_task.id);
          Navigator.pop(context);
          widget.onDeleted?.call();
        }
      }
    }
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
  void dispose() {
    _tabController.dispose();
    for (final ctrl in _evalRemarksControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    final isAdmin = workspace.me?.isAdmin ?? false;
    final isCompleted = _task.status == 'completed';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TaskColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${_task.id}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: TaskColors.slateLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusChip(status: _task.status),
                          const SizedBox(width: 4),
                          PriorityChip(priority: _task.priority),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _task.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: TaskColors.slateText,
                        ),
                      ),
                      if (_task.projectName != null)
                        Text(
                          _task.projectName!,
                          style: const TextStyle(fontSize: 12, color: TaskColors.slateMuted),
                        ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onEdit?.call(_task);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 20, color: TaskColors.slateMuted),
                  ),
                  IconButton(
                    onPressed: _deleteTask,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFE11D48)),
                  ),
                ],
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: TaskColors.slateMuted),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: TaskColors.medicalAccent,
            unselectedLabelColor: TaskColors.slateMuted,
            indicatorColor: TaskColors.medicalAccent,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: [
              const Tab(text: 'Detail'),
              const Tab(text: 'Chat'),
              if (isCompleted) const Tab(text: 'Evaluation'),
            ],
          ),

          const Divider(height: 1, color: TaskColors.border),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailTab(),
                _buildChatTab(context),
                if (isCompleted) _buildEvaluationTab(isAdmin),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Description
        if (_task.description != null && _task.description!.isNotEmpty) ...[
          const Text(
            'DESCRIPTION',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            _task.description!,
            style: const TextStyle(fontSize: 13, color: TaskColors.slateText, height: 1.4),
          ),
          const SizedBox(height: 16),
        ],

        // Date Info Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TaskColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: TaskColors.slateMuted),
                        SizedBox(width: 4),
                        Text('START DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: TaskColors.slateMuted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_formatDate(_task.startDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TaskColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_available_rounded, size: 12, color: TaskColors.slateMuted),
                        SizedBox(width: 4),
                        Text('DUE DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: TaskColors.slateMuted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_formatDate(_task.dueDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Assignees
        const Text(
          'ASSIGNED TO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        if (_task.assignees.isEmpty)
          const Text('Nobody assigned yet.', style: TextStyle(fontSize: 12, color: TaskColors.slateLight))
        else
          Column(
            children: _task.assignees.map((a) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TaskColors.border),
                ),
                child: Row(
                  children: [
                    AvatarWidget(person: a, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
                          if (a.designation != null)
                            Text(a.designation!, style: const TextStyle(fontSize: 10, color: TaskColors.slateMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 16),

        // Checklist
        if (_task.points.isNotEmpty) ...[
          const Text(
            'CHECKLIST',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Column(
            children: _task.points.map((p) {
              return InkWell(
                onTap: p.id != null
                    ? () async {
                        final ok = await context.read<TaskListProvider>().togglePoint(_task.id, p.id!, !p.isDone);
                        if (ok) {
                          setState(() {
                            final updated = _task.points.map((pt) {
                              if (pt.id == p.id) return pt.copyWith(isDone: !p.isDone);
                              return pt;
                            }).toList();
                            _task = _task.copyWith(points: updated);
                          });
                        }
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        p.isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: p.isDone ? TaskColors.medicalAccent : TaskColors.slateLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: p.isDone ? TaskColors.slateLight : TaskColors.slateText,
                            decoration: p.isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Footer Meta
        const Divider(color: TaskColors.border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Created on ${_formatDate(_task.createdAt)}'
            '${_task.departmentName != null ? ' · ${_task.departmentName}' : ''}',
            style: const TextStyle(fontSize: 11, color: TaskColors.slateLight),
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: TaskColors.medicalAccent),
            const SizedBox(height: 12),
            Text(
              'Chat for #${_task.id} - ${_task.title}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TaskColors.slateText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Communicate with assignees in real-time, send attachments, and check off tasks.',
              style: TextStyle(fontSize: 12, color: TaskColors.slateMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskChatScreen(task: _task)),
                );
              },
              icon: const Icon(Icons.forum_rounded, size: 16),
              label: const Text('Open Conversation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TaskColors.medicalAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationTab(bool isAdmin) {
    if (_loadingEvaluations) {
      return const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent));
    }

    if (_task.assignees.isEmpty) {
      return const Center(
        child: Text('No assignees to evaluate.', style: TextStyle(fontSize: 12, color: TaskColors.slateLight)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _task.assignees.map((person) {
        final existing = _evaluations.where((r) => r.employeeId == person.id).firstOrNull;
        final rating = _evalRatings[person.id] ?? existing?.rating ?? 0;
        final remarksCtrl = _evalRemarksControllers.putIfAbsent(
          person.id,
          () => TextEditingController(text: existing?.remarks ?? ''),
        );
        final isSaving = _savingEmployeeId == person.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TaskColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarWidget(person: person, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
                        if (person.designation != null)
                          Text(person.designation!, style: const TextStyle(fontSize: 10, color: TaskColors.slateMuted)),
                      ],
                    ),
                  ),
                  StarPickerWidget(
                    value: rating,
                    disabled: !isAdmin,
                    onChange: (newRating) {
                      setState(() {
                        _evalRatings[person.id] = newRating;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: remarksCtrl,
                enabled: isAdmin,
                maxLines: 2,
                style: const TextStyle(fontSize: 12, color: TaskColors.slateText),
                decoration: InputDecoration(
                  hintText: 'Remarks (optional)',
                  hintStyle: const TextStyle(fontSize: 12, color: TaskColors.slateLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: TaskColors.border),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    existing != null ? 'Rated by ${existing.evaluatorName ?? 'Admin'}' : 'Not yet rated',
                    style: const TextStyle(fontSize: 10, color: TaskColors.slateLight),
                  ),
                  if (isAdmin)
                    ElevatedButton(
                      onPressed: isSaving ? null : () => _saveEvaluation(person.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TaskColors.medicalAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
