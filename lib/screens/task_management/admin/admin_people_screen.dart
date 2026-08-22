import 'package:flutter/material.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/project_model.dart';
import '../../../models/task_management/task_model.dart';
import '../../../core/services/task_management/task_api_service.dart';

class AdminPeopleScreen extends StatefulWidget {
  const AdminPeopleScreen({super.key});

  @override
  State<AdminPeopleScreen> createState() => _AdminPeopleScreenState();
}

class _AdminPeopleScreenState extends State<AdminPeopleScreen> {
  final TaskApiService _api = TaskApiService();
  final TextEditingController _searchController = TextEditingController();

  List<TaskAssignee> _people = [];
  List<TaskDepartment> _departments = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([
      _api.fetchPeople().then((r) { if (r.success && r.data != null) _people = r.data!; }),
      _api.fetchDepartments().then((r) { if (r.success && r.data != null) _departments = r.data!; }),
    ]);
    setState(() => _loading = false);
  }

  void _showDepartmentDialog(TaskAssignee person) {
    int? selectedDeptId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Department: ${person.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Assign this person to a department:', style: TextStyle(fontSize: 12, color: TaskColors.slateMuted)),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                value: selectedDeptId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('No Department', style: TextStyle(fontSize: 12))),
                  ..._departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontSize: 12)))),
                ],
                onChanged: (v) => setDialogState(() => selectedDeptId = v),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final res = await _api.setPersonDepartment(person.id, selectedDeptId);
                if (res.success) {
                  _loadData();
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: TaskColors.medicalAccent, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _people.where((p) {
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          (p.employeeCode?.toLowerCase().contains(query) ?? false) ||
          (p.designation?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('People & Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TaskColors.slateText),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
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
                  hintText: 'Search people by name, designation, code…',
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
                    ? const EmptyStateWidget(icon: Icons.people_outline_rounded, title: 'No staff found', hint: 'No one matches your search.')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final person = filtered[idx];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: TaskColors.border),
                            ),
                            child: Row(
                              children: [
                                AvatarWidget(person: person, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(person.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
                                      Text(
                                        '${person.designation ?? person.employeeCode ?? 'Staff'}'
                                        '${person.hasAccess == false ? ' · No login link' : ''}',
                                        style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showDepartmentDialog(person),
                                  icon: const Icon(Icons.apartment_rounded, size: 18, color: TaskColors.slateMuted),
                                  tooltip: 'Assign Department',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
