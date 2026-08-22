import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/project_model.dart';
import '../../../models/task_management/task_model.dart';
import '../../../core/services/task_management/task_api_service.dart';

class TaskFormDialog extends StatefulWidget {
  final TaskItem? task;
  final Function(TaskItem) onSaved;

  const TaskFormDialog({super.key, this.task, required this.onSaved});

  static void show(BuildContext context, {TaskItem? task, required Function(TaskItem) onSaved}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskFormDialog(task: task, onSaved: onSaved),
    );
  }

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final TaskApiService _api = TaskApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _pointInputController = TextEditingController();
  final TextEditingController _assigneeSearchController = TextEditingController();

  List<ProjectItem> _projects = [];
  List<TaskAssignee> _projectMembers = [];
  bool _loadingProjects = false;
  bool _loadingMembers = false;
  bool _saving = false;
  String? _errorMessage;

  String? _selectedProjectName;
  String _status = 'pending';
  String _priority = 'medium';
  DateTime? _startDate;
  DateTime? _dueDate;
  TimeOfDay _dueTime = const TimeOfDay(hour: 17, minute: 0);

  final List<int> _selectedAssigneeIds = [];
  final List<ChecklistPoint> _points = [];

  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loadingProjects = true);
    final res = await _api.fetchProjects(includeClosed: false);
    if (res.success && res.data != null) {
      _projects = res.data!;
    }
    setState(() => _loadingProjects = false);

    if (widget.task != null) {
      final t = widget.task!;
      _titleController.text = t.title;
      _descController.text = t.description ?? '';
      _selectedProjectName = t.projectName;
      _status = t.status;
      _priority = t.priority;

      if (t.startDate != null) {
        try {
          _startDate = DateTime.parse(t.startDate!);
        } catch (_) {}
      }
      if (t.dueDate != null) {
        try {
          _dueDate = DateTime.parse(t.dueDate!);
          _dueTime = TimeOfDay(hour: _dueDate!.hour, minute: _dueDate!.minute);
        } catch (_) {}
      }

      _selectedAssigneeIds.addAll(t.assignees.map((a) => a.id));
      _points.addAll(t.points);

      if (t.projectId != null) {
        _loadMembersForProject(t.projectId!);
      } else if (t.projectName != null) {
        final proj = _projects.where((p) => p.name == t.projectName).firstOrNull;
        if (proj != null) {
          _loadMembersForProject(proj.id);
        }
      }
    }
  }

  Future<void> _loadMembersForProject(int projectId) async {
    setState(() => _loadingMembers = true);
    final res = await _api.fetchProjectMembers(projectId);
    if (res.success && res.data != null) {
      _projectMembers = res.data!;
    } else {
      _projectMembers = [];
    }
    setState(() => _loadingMembers = false);
  }

  void _onProjectChanged(String? name) {
    setState(() {
      _selectedProjectName = name;
      _selectedAssigneeIds.clear();
      _projectMembers.clear();
    });

    final proj = _projects.where((p) => p.name == name).firstOrNull;
    if (proj != null) {
      _loadMembersForProject(proj.id);
    }
  }

  void _addPoint() {
    final label = _pointInputController.text.trim();
    if (label.isEmpty) return;
    setState(() {
      _points.add(ChecklistPoint(label: label, isDone: false));
      _pointInputController.clear();
    });
  }

  String _formatSqlDate(DateTime? d, [TimeOfDay? t]) {
    if (d == null) return '';
    final time = t ?? const TimeOfDay(hour: 0, minute: 0);
    final dt = DateTime(d.year, d.month, d.day, time.hour, time.minute);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectName == null || _selectedProjectName!.isEmpty) {
      setState(() => _errorMessage = 'Please choose a project.');
      return;
    }

    final project = _projects.where((p) => p.name == _selectedProjectName).firstOrNull;
    if (_dueDate != null && project?.deadlineDate != null) {
      try {
        final projectDeadline = DateTime.parse(project!.deadlineDate!);
        if (_dueDate!.isAfter(projectDeadline)) {
          setState(() => _errorMessage =
              'This project ends on ${DateFormat('yyyy-MM-dd').format(projectDeadline)} — the task cannot be due later.');
          return;
        }
      } catch (_) {}
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final payload = {
      'title': _titleController.text.trim(),
      'projectName': _selectedProjectName,
      'description': _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      'status': _status,
      'priority': _priority,
      'startDate': _startDate != null ? _formatSqlDate(_startDate) : null,
      'dueDate': _dueDate != null ? _formatSqlDate(_dueDate, _dueTime) : null,
      'assigneeIds': _selectedAssigneeIds,
      'points': _points.map((p) => p.toJson()).toList(),
    };

    try {
      TaskApiResponse<TaskItem> res;
      if (isEditing) {
        res = await _api.patchTask(widget.task!.id, payload);
        if (res.success && res.data != null) {
          await _api.replaceTaskAssignees(widget.task!.id, _selectedAssigneeIds);
        }
      } else {
        res = await _api.createTask(payload);
      }

      if (res.success && res.data != null) {
        widget.onSaved(res.data!);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() => _errorMessage = res.message ?? 'Failed to save task.');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _pointInputController.dispose();
    _assigneeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = _assigneeSearchController.text.trim().toLowerCase();
    final filteredMembers = _projectMembers.where((m) {
      if (search.isEmpty) return true;
      return m.name.toLowerCase().contains(search) || (m.designation?.toLowerCase().contains(search) ?? false);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Task #${widget.task!.id}' : 'New Task',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TaskColors.slateText),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: TaskColors.slateMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: TaskColors.border),

          // Form Body
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title
                  const Text('TITLE *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _titleController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                    decoration: InputDecoration(
                      hintText: 'What needs doing?',
                      hintStyle: const TextStyle(fontSize: 13, color: TaskColors.slateLight),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: TaskColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Project Dropdown
                  const Text('PROJECT *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight)),
                  const SizedBox(height: 4),
                  _loadingProjects
                      ? const LinearProgressIndicator(color: TaskColors.medicalAccent)
                      : DropdownButtonFormField<String>(
                          value: _selectedProjectName,
                          items: _projects.map((p) {
                            return DropdownMenuItem(
                              value: p.name,
                              child: Text(
                                '${p.name}${p.deadlineDate != null ? ' (ends ${p.deadlineDate!.split('T')[0]})' : ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: _onProjectChanged,
                          validator: (v) => (v == null || v.isEmpty) ? 'Please select a project' : null,
                          decoration: InputDecoration(
                            hintText: 'Select a project…',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: TaskColors.border)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),

                  const SizedBox(height: 14),

                  // Status & Priority
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _status,
                              items: StatusMeta.map.entries.map((e) {
                                return DropdownMenuItem(value: e.key, child: Text(e.value.label, style: const TextStyle(fontSize: 12)));
                              }).toList(),
                              onChanged: (v) => setState(() => _status = v ?? 'pending'),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: TaskColors.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PRIORITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _priority,
                              items: PriorityMeta.map.entries.map((e) {
                                return DropdownMenuItem(value: e.key, child: Text(e.value.label, style: const TextStyle(fontSize: 12)));
                              }).toList(),
                              onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: TaskColors.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Start Date & Due Date
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('START DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setState(() => _startDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: TaskColors.border),
                                ),
                                child: Text(
                                  _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : 'Pick date',
                                  style: TextStyle(fontSize: 12, color: _startDate != null ? TaskColors.slateText : TaskColors.slateLight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DUE DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 2)),
                                  firstDate: _startDate ?? DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setState(() => _dueDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: TaskColors.border),
                                ),
                                child: Text(
                                  _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : 'Pick due date',
                                  style: TextStyle(fontSize: 12, color: _dueDate != null ? TaskColors.slateText : TaskColors.slateLight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Due Time
                  const Text('DUE TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _dueTime,
                      );
                      if (picked != null) setState(() => _dueTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: TaskColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: TaskColors.slateLight),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(_dueTime),
                            style: const TextStyle(fontSize: 12, color: TaskColors.slateText),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Description
                  const Text('DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Optional detail or context',
                      hintStyle: const TextStyle(fontSize: 13, color: TaskColors.slateLight),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: TaskColors.border)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Assignees Picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ASSIGN TO (${_selectedAssigneeIds.length})',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight),
                      ),
                      if (_projectMembers.length > 5)
                        SizedBox(
                          width: 140,
                          height: 28,
                          child: TextField(
                            controller: _assigneeSearchController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 11),
                            decoration: InputDecoration(
                              hintText: 'Filter people…',
                              prefixIcon: const Icon(Icons.search_rounded, size: 14, color: TaskColors.slateLight),
                              prefixIconConstraints: const BoxConstraints(minWidth: 24),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: TaskColors.border)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TaskColors.border),
                    ),
                    child: _selectedProjectName == null
                        ? const Center(
                            child: Text(
                              'Choose a project first — assignees come from its members.',
                              style: TextStyle(fontSize: 11, color: TaskColors.slateLight),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _loadingMembers
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: TaskColors.medicalAccent))
                            : filteredMembers.isEmpty
                                ? const Center(
                                    child: Text('No project members found.', style: TextStyle(fontSize: 11, color: TaskColors.slateLight)),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: filteredMembers.length,
                                    itemBuilder: (_, idx) {
                                      final person = filteredMembers[idx];
                                      final isSelected = _selectedAssigneeIds.contains(person.id);
                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedAssigneeIds.remove(person.id);
                                            } else {
                                              _selectedAssigneeIds.add(person.id);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          margin: const EdgeInsets.only(bottom: 4),
                                          decoration: BoxDecoration(
                                            color: isSelected ? TaskColors.medicalAccent.withOpacity(0.1) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              AvatarWidget(person: person, size: 22),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  person.name,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TaskColors.slateText),
                                                ),
                                              ),
                                              if (isSelected)
                                                const Icon(Icons.check_circle_rounded, size: 16, color: TaskColors.medicalAccent),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                  ),

                  const SizedBox(height: 14),

                  // Checklist Points Builder
                  Text(
                    'CHECKLIST (${_points.length})',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: TaskColors.slateLight),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pointInputController,
                          onSubmitted: (_) => _addPoint(),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Add a checklist point and press add…',
                            hintStyle: const TextStyle(fontSize: 12, color: TaskColors.slateLight),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: TaskColors.border)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addPoint,
                        icon: const Icon(Icons.add_rounded, color: TaskColors.medicalAccent),
                        style: IconButton.styleFrom(
                          backgroundColor: TaskColors.medicalAccent.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  if (_points.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Column(
                      children: List.generate(_points.length, (idx) {
                        final pt = _points[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: TaskColors.border),
                          ),
                          child: Row(
                            children: [
                              Text('${idx + 1}.', style: const TextStyle(fontSize: 11, color: TaskColors.slateLight)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(pt.label, style: const TextStyle(fontSize: 12, color: TaskColors.slateText)),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _points.removeAt(idx)),
                                icon: const Icon(Icons.close_rounded, size: 14, color: TaskColors.slateLight),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C))),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TaskColors.medicalAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEditing ? 'Save Changes' : 'Create Task', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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