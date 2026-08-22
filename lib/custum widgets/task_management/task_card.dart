import 'package:flutter/material.dart';
import '../../models/task_management/task_model.dart';
import 'task_primitives.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTap;
  final Function(String targetStatus)? onStatusChange;
  final bool showProject;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.onStatusChange,
    this.showProject = true,
  });

  @override
  Widget build(BuildContext context) {
    final totalPoints = task.points.length;
    final donePoints = task.points.where((p) => p.isDone).length;
    final status = StatusMeta.of(task.status);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),           // matches dashboard cards
          border: Border.all(color: TaskColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top row: ID dot + project label + unread badge + menu ────────
            Row(
              children: [
                // Accent dot matching _StatCard header dot
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: status.dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  '#${task.id}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: TaskColors.slateLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                PriorityChip(priority: task.priority),
                const SizedBox(width: 4),
                DueChip(dueDate: task.dueDate, status: task.status),
                const Spacer(),
                if (task.unreadCount > 0)
                  Container(
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
                if (onStatusChange != null)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 16, color: Colors.grey.shade400),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: onStatusChange,
                    itemBuilder: (_) => [
                      if (task.status != 'pending')
                        const PopupMenuItem(value: 'pending', child: Text('Move to Pending', style: TextStyle(fontSize: 12))),
                      if (task.status != 'in_progress')
                        const PopupMenuItem(value: 'in_progress', child: Text('Move to In Progress', style: TextStyle(fontSize: 12))),
                      if (task.status != 'completed')
                        const PopupMenuItem(value: 'completed', child: Text('Mark as Completed', style: TextStyle(fontSize: 12))),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 7),

            // ── Task title ────────────────────────────────────────────────────
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: TaskColors.slateText,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if (showProject && (task.projectName != null && task.projectName!.isNotEmpty)) ...[
              const SizedBox(height: 2),
              Text(
                task.projectName!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Checklist progress ────────────────────────────────────────────
            if (totalPoints > 0) ...[
              const SizedBox(height: 8),
              TaskProgressBar(
                done: donePoints,
                total: totalPoints,
                status: task.status,
                dueDate: task.dueDate,
              ),
            ],

            const SizedBox(height: 8),

            // ── Footer: avatars + status chip ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AvatarStackWidget(people: task.assignees, size: 20),
                StatusChip(status: task.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
