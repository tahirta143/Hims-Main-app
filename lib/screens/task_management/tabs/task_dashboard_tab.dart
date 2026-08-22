import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../custum widgets/task_management/task_card.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../providers/task_management/task_list_provider.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import '../chat/task_chat_screen.dart';
import '../dialogs/task_detail_sheet.dart';
import '../dialogs/task_form_dialog.dart';

class TaskDashboardTab extends StatefulWidget {
  final VoidCallback onOpenBoard;

  const TaskDashboardTab({super.key, required this.onOpenBoard});

  @override
  State<TaskDashboardTab> createState() => _TaskDashboardTabState();
}

class _TaskDashboardTabState extends State<TaskDashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskListProvider>().loadTasks(customScope: 'mine');
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    final taskList  = context.watch<TaskListProvider>();
    final items     = taskList.items;
    final isAdmin   = workspace.me?.isAdmin ?? false;

    // ── Stats ─────────────────────────────────────────────────────────────────
    int total = items.length;
    int inProgress = 0, pending = 0, completed = 0, overdue = 0;
    final now = DateTime.now();
    for (final t in items) {
      if (t.status == 'in_progress') inProgress++;
      if (t.status == 'pending') pending++;
      if (t.status == 'completed') completed++;
      if (t.status != 'completed' && t.dueDate != null) {
        try {
          if (DateTime.parse(t.dueDate!).isBefore(now)) overdue++;
        } catch (_) {}
      }
    }

    // ── Up Next ───────────────────────────────────────────────────────────────
    final upNext = items.where((t) => t.status != 'completed' && t.status != 'hold').toList()
      ..sort((a, b) {
        final da = a.dueDate != null ? DateTime.tryParse(a.dueDate!) ?? DateTime(2099) : DateTime(2099);
        final db = b.dueDate != null ? DateTime.tryParse(b.dueDate!) ?? DateTime(2099) : DateTime(2099);
        return da.compareTo(db);
      });

    // ── Recent Chats ──────────────────────────────────────────────────────────
    final recentChats = items.where((t) => t.lastMessage != null).toList()
      ..sort((a, b) {
        final da = a.lastMessage?.createdAt != null ? DateTime.tryParse(a.lastMessage!.createdAt) ?? DateTime(1970) : DateTime(1970);
        final db = b.lastMessage?.createdAt != null ? DateTime.tryParse(b.lastMessage!.createdAt) ?? DateTime(1970) : DateTime(1970);
        return db.compareTo(da);
      });

    return RefreshIndicator(
      color: TaskColors.medicalAccent,
      onRefresh: () => taskList.loadTasks(customScope: 'mine'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Welcome header ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OVERVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TaskColors.slateLight,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Welcome back, ${workspace.me?.name.split(' ').last ?? 'User'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: TaskColors.slateText,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              if (isAdmin)
                ElevatedButton.icon(
                  onPressed: () {
                    TaskFormDialog.show(
                      context,
                      onSaved: (newTask) => taskList.upsertTask(newTask),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Task', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TaskColors.medicalAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Stat tiles grid — matching dashboard _StatCard design ──────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              StatTileWidget(
                label: 'Assigned',
                value: '$total',
                icon: Icons.assignment_outlined,
                accentColor: const Color(0xFF334155),
                bgColor: const Color(0xFFF8FAFC),
              ),
              StatTileWidget(
                label: 'In Progress',
                value: '$inProgress',
                icon: Icons.timelapse_rounded,
                accentColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFF0FDFA),
              ),
              StatTileWidget(
                label: 'Pending',
                value: '$pending',
                icon: Icons.pause_circle_outline_rounded,
                accentColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
              ),
              StatTileWidget(
                label: 'Completed',
                value: '$completed',
                icon: Icons.check_circle_outline_rounded,
                accentColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
              StatTileWidget(
                label: 'Overdue',
                value: '$overdue',
                icon: Icons.warning_amber_rounded,
                accentColor: const Color(0xFFE11D48),
                bgColor: const Color(0xFFFFF1F2),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Section: Up Next ───────────────────────────────────────────────
          _sectionHeader(
            title: 'UP NEXT',
            subtitle: 'Soonest deadline first',
            trailing: TextButton(
              onPressed: widget.onOpenBoard,
              child: const Text('Board →', style: TextStyle(fontSize: 11, color: TaskColors.medicalAccent, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),

          if (taskList.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: TaskColors.medicalAccent, strokeWidth: 2),
              ),
            )
          else if (upNext.isEmpty)
            TaskGlassPanel(
              child: const EmptyStateWidget(
                icon: Icons.check_circle_outline_rounded,
                title: 'Nothing outstanding',
                hint: 'Every task assigned to you is done or on hold.',
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upNext.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final task = upNext[idx];
                return TaskCard(
                  task: task,
                  onTap: () {
                    TaskDetailSheet.show(
                      context,
                      task,
                      onEdit: (t) => TaskFormDialog.show(context, task: t, onSaved: (saved) => taskList.upsertTask(saved)),
                    );
                  },
                  onStatusChange: (newStatus) => taskList.moveTask(task.id, newStatus),
                );
              },
            ),

          const SizedBox(height: 24),

          // ── Section: Recent Conversations ──────────────────────────────────
          _sectionHeader(
            title: 'RECENT CONVERSATIONS',
            subtitle: 'Latest task activity',
          ),
          const SizedBox(height: 8),

          if (recentChats.isEmpty)
            TaskGlassPanel(
              child: const EmptyStateWidget(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No recent messages',
                hint: 'Task chatter shows up here.',
              ),
            )
          else
            TaskGlassPanel(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentChats.take(5).length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: TaskColors.borderLight),
                itemBuilder: (context, idx) {
                  final task = recentChats[idx];
                  final lastMsg = task.lastMessage;
                  final isFirst = idx == 0;
                  final isLast  = idx == (recentChats.take(5).length - 1);
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TaskChatScreen(task: task)),
                      );
                    },
                    borderRadius: BorderRadius.vertical(
                      top: isFirst ? const Radius.circular(20) : Radius.zero,
                      bottom: isLast ? const Radius.circular(20) : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          // Dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: StatusMeta.of(task.status).dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: TaskColors.slateText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (task.unreadCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE11D48),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          task.unreadCount > 99 ? '99+' : '${task.unreadCount}',
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lastMsg != null
                                      ? '${lastMsg.senderName}: ${lastMsg.isDeleted ? 'Message deleted' : lastMsg.type == 'image' ? 'Photo' : lastMsg.content}'
                                      : 'No messages yet',
                                  style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade300),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Section header matching the dashboard's category panel headers.
  Widget _sectionHeader({required String title, String? subtitle, Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            if (subtitle != null)
              Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
