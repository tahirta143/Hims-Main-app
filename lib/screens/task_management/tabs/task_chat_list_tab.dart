import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../providers/task_management/task_list_provider.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import '../chat/task_chat_screen.dart';

class TaskChatListTab extends StatefulWidget {
  const TaskChatListTab({super.key});

  @override
  State<TaskChatListTab> createState() => _TaskChatListTabState();
}

class _TaskChatListTabState extends State<TaskChatListTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskListProvider>().loadTasks(orderBy: 'last_message');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return DateFormat('d MMM').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    final taskList = context.watch<TaskListProvider>();
    final isAdmin = workspace.me?.isAdmin ?? false;

    final query = _searchController.text.trim().toLowerCase();
    final conversations = taskList.items.where((t) {
      if (t.status == 'hold' && !isAdmin) return false;
      if (query.isEmpty) return true;
      final assignees = t.assignees.map((a) => a.name).join(' ').toLowerCase();
      return t.title.toLowerCase().contains(query) ||
          (t.projectName?.toLowerCase().contains(query) ?? false) ||
          assignees.contains(query);
    }).toList();

    return Column(
      children: [
        // Search Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                hintText: 'Search conversations…',
                hintStyle: TextStyle(fontSize: 12, color: TaskColors.slateLight),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: TaskColors.slateLight),
                prefixIconConstraints: BoxConstraints(minWidth: 32),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),

        const Divider(height: 1, color: TaskColors.border),

        // Conversation List
        Expanded(
          child: taskList.loading
              ? const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent))
              : conversations.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No conversations found',
                      hint: 'Tasks you are assigned to will show their chat threads here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: TaskColors.border),
                      itemBuilder: (context, idx) {
                        final task = conversations[idx];
                        final lastMsg = task.lastMessage;
                        final unread = task.unreadCount;

                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TaskChatScreen(task: task)),
                            ).then((_) {
                              taskList.clearUnread(task.id);
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: TaskColors.slateText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatRelativeTime(lastMsg?.createdAt),
                                style: const TextStyle(fontSize: 10, color: TaskColors.slateLight),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 3),
                              Text(
                                lastMsg != null
                                    ? '${lastMsg.senderName}: ${lastMsg.isDeleted ? 'Message deleted' : lastMsg.type == 'image' ? 'Photo' : lastMsg.content}'
                                    : 'No messages yet',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: unread > 0 ? TaskColors.slateText : TaskColors.slateMuted,
                                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  StatusChip(status: task.status),
                                  const SizedBox(width: 8),
                                  AvatarStackWidget(people: task.assignees, size: 18, max: 3),
                                  const Spacer(),
                                  if (unread > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE11D48),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        unread > 99 ? '99+' : '$unread',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
