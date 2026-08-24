import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/project_model.dart';
import '../../../models/task_management/task_model.dart';
import '../../../core/services/task_management/task_api_service.dart';
import 'package:hims_app/custum%20widgets/task_management/task_app_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_bottom_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_workspace_drawer.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import '../task_workspace_screen.dart';

const Color _kBg       = Color(0xFFF8FAFC);
const Color _kBorder   = Color(0xFFEDF2F7);

class AdminProjectsScreen extends StatefulWidget {
  const AdminProjectsScreen({super.key});

  @override
  State<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends State<AdminProjectsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TaskApiService _api = TaskApiService();
  final TextEditingController _searchController = TextEditingController();

  List<ProjectItem> _projects = [];
  List<TaskDepartment> _departments = [];
  List<TaskAssignee> _allPeople = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    await Future.wait([
      _api.fetchProjects(includeClosed: true).then((r) {
        if (r.success && r.data != null) _projects = r.data!;
      }),
      _api.fetchDepartments().then((r) {
        if (r.success && r.data != null) _departments = r.data!;
      }),
      _api.fetchPeople().then((r) {
        if (r.success && r.data != null) {
          _allPeople = r.data!;
        }
      }),
    ]);
    if (_allPeople.isEmpty) {
      final retry = await _api.fetchPeople();
      if (retry.success && retry.data != null) {
        _allPeople = retry.data!;
      }
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


  // ── Project create/edit dialog ────────────────────────────────────────────
  void _showProjectForm({ProjectItem? project}) {
    final nameCtrl = TextEditingController(text: project?.name ?? '');
    int? selectedDeptId = project?.departmentId;
    DateTime? deadlineDate = project?.deadlineDate != null
        ? DateTime.tryParse(project!.deadlineDate!)
        : null;
    String status = project?.status ?? 'active';
    bool saving = false;
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) => AlertDialog(
          title: Text(project == null ? 'New Project' : 'Edit Project',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                const Text('NAME *',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: TaskColors.slateLight)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Project Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),

                // Department
                const Text('DEPARTMENT',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: TaskColors.slateLight)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int?>(
                  value: selectedDeptId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('None',
                            style: TextStyle(fontSize: 12))),
                    ..._departments.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.name,
                            style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (v) => setDs(() => selectedDeptId = v),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),

                // Deadline
                const Text('DEADLINE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: TaskColors.slateLight)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: deadlineDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035));
                    if (p != null) setDs(() => deadlineDate = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        border: Border.all(color: TaskColors.border),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: TaskColors.slateLight),
                        const SizedBox(width: 8),
                        Text(
                          deadlineDate != null
                              ? DateFormat('yyyy-MM-dd').format(deadlineDate!)
                              : 'Pick deadline date',
                          style: TextStyle(
                              fontSize: 12,
                              color: deadlineDate != null
                                  ? TaskColors.slateText
                                  : TaskColors.slateLight),
                        ),
                      ],
                    ),
                  ),
                ),

                if (err != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(err!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFBE123C))),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setDs(() => err = 'Project name is required.');
                        return;
                      }
                      setDs(() => saving = true);

                      final payload = {
                        'name': name,
                        'departmentId': selectedDeptId,
                        'deadlineDate': deadlineDate != null
                            ? DateFormat('yyyy-MM-dd').format(deadlineDate!)
                            : null,
                        'status': status,
                      };

                      if (project == null) {
                        final res = await _api.createProject(payload);
                        if (res.success && res.data != null) {
                          setState(() => _projects.insert(0, res.data!));
                          if (ctx.mounted) Navigator.pop(ctx);
                        } else {
                          setDs(() {
                            err = res.message ?? 'Failed to create project.';
                            saving = false;
                          });
                        }
                      } else {
                        final res =
                            await _api.updateProject(project.id, payload);
                        if (res.success && res.data != null) {
                          setState(() {
                            final i = _projects
                                .indexWhere((p) => p.id == project.id);
                            if (i >= 0) _projects[i] = res.data!;
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                        } else {
                          setDs(() {
                            err = res.message ?? 'Failed to update project.';
                            saving = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: TaskColors.medicalAccent,
                  foregroundColor: Colors.white),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Member assignment dialog ──────────────────────────────────────────────
  Future<void> _showMemberAssignment(ProjectItem project) async {
    // If people list is empty, fetch it now before showing dialog
    if (_allPeople.isEmpty) {
      final res = await _api.fetchPeople();
      if (res.success && res.data != null) {
        setState(() => _allPeople = res.data!);
      }
    }

    if (!mounted) return;

    final memberIds = project.members.map((m) => m.id).toSet();
    final searchCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = _allPeople.where((p) {
            if (query.isEmpty) return true;
            return p.name.toLowerCase().contains(query) ||
                (p.designation?.toLowerCase().contains(query) ?? false) ||
                (p.employeeCode?.toLowerCase().contains(query) ?? false);
          }).toList();

          return AlertDialog(
            title: Text('Assign Members: ${project.name}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setDs(() {}),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search by name, designation, code…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Count badge
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${memberIds.length} selected · ${filtered.length} shown',
                      style: const TextStyle(
                          fontSize: 10, color: TaskColors.slateMuted),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              _allPeople.isEmpty
                                  ? 'No people found. Make sure employees are linked to user accounts.'
                                  : 'No results for "$query"',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: TaskColors.slateMuted),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, idx) {
                              final person = filtered[idx];
                              final isSelected =
                                  memberIds.contains(person.id);
                              return CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                activeColor: TaskColors.medicalAccent,
                                title: Text(person.name,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    [
                                      if (person.designation != null)
                                        person.designation!,
                                      if (person.employeeCode != null)
                                        person.employeeCode!,
                                      if (person.departmentName != null)
                                        person.departmentName!,
                                    ].join(' · '),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: TaskColors.slateMuted)),
                                secondary: AvatarWidget(
                                    person: person, size: 28),
                                onChanged: (val) {
                                  setDs(() {
                                    if (val == true) {
                                      memberIds.add(person.id);
                                    } else {
                                      memberIds.remove(person.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final res = await _api.setProjectMembers(
                      project.id, memberIds.toList());
                  if (res.success && res.data != null) {
                    setState(() {
                      final i = _projects
                          .indexWhere((p) => p.id == project.id);
                      if (i >= 0) {
                        _projects[i] = ProjectItem(
                          id: project.id,
                          name: project.name,
                          description: project.description,
                          departmentId: project.departmentId,
                          departmentName: project.departmentName,
                          startDate: project.startDate,
                          deadlineDate: project.deadlineDate,
                          status: project.status,
                          memberCount: res.data!.length,
                          taskCount: project.taskCount,
                          completedTaskCount: project.completedTaskCount,
                          progressPercent: project.progressPercent,
                          members: res.data!,
                        );
                      }
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: TaskColors.medicalAccent,
                    foregroundColor: Colors.white),
                child: const Text('Save Members'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _projects.where((p) {
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          (p.departmentName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      appBar: TaskAppBar(
        title: 'Projects',
        subtitle: 'ADMINISTRATION',
        scaffoldKey: _scaffoldKey,
        action: IconButton(
          onPressed: () => _showProjectForm(),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        ),
      ),
      drawer: TaskWorkspaceDrawer(
        activeTabIndex: 11,
        unreadCount: workspace.unreadCount,
        isAdmin: true,
        onTabSelected: _onBottomNavItemBar,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Search projects by name, department…',
                  hintStyle:
                      TextStyle(fontSize: 12, color: TaskColors.slateLight),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 16, color: TaskColors.slateLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: TaskColors.border),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: TaskColors.medicalAccent))
                : filtered.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.business_rounded,
                        title: 'No projects found',
                        hint:
                            'Create a project to start organizing tasks.')
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: TaskColors.medicalAccent,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final project = filtered[idx];
                            return _ProjectCard(
                              project: project,
                              onEdit: () =>
                                  _showProjectForm(project: project),
                              onMembers: () =>
                                  _showMemberAssignment(project),
                            );
                          },
                        ),
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

// ── Project card ─────────────────────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final ProjectItem project;
  final VoidCallback onEdit;
  final VoidCallback onMembers;

  const _ProjectCard({
    required this.project,
    required this.onEdit,
    required this.onMembers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TaskColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2)),
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
                    Text(project.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TaskColors.slateText)),
                    if (project.departmentName != null)
                      Text(project.departmentName!,
                          style: const TextStyle(
                              fontSize: 11, color: TaskColors.slateMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: project.status == 'completed'
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: project.status == 'completed'
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFF99F6E4)),
                ),
                child: Text(
                  project.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: project.status == 'completed'
                        ? const Color(0xFF047857)
                        : const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  '${project.completedTaskCount}/${project.taskCount} tasks done',
                  style: const TextStyle(
                      fontSize: 11, color: TaskColors.slateMuted)),
              Text('${project.progressPercent.round()}%',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: TaskColors.slateText)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (project.progressPercent / 100).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF1F5F9),
              color: TaskColors.medicalAccent,
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              TextButton.icon(
                onPressed: onMembers,
                icon: const Icon(Icons.people_outline_rounded, size: 14),
                label: Text('${project.memberCount} members',
                    style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: TaskColors.medicalAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const Spacer(),
              if (project.deadlineDate != null)
                Text(
                  'Ends ${project.deadlineDate!.split('T')[0]}',
                  style: const TextStyle(
                      fontSize: 10, color: TaskColors.slateLight),
                ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: TaskColors.slateMuted),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
