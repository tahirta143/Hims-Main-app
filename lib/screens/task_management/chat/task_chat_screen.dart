import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../custum widgets/task_management/task_primitives.dart';
import '../../../../models/task_management/task_model.dart';
import '../../../../providers/task_management/task_chat_provider.dart';
import '../../../../providers/task_management/task_workspace_provider.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';

class TaskChatScreen extends StatefulWidget {
  final TaskItem task;

  const TaskChatScreen({super.key, required this.task});

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _checklistExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskChatProvider>().openConversation(widget.task);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDaySeparator(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDay = DateTime(date.year, date.month, date.day);

      if (msgDay == today) return 'Today';
      if (msgDay == yesterday) return 'Yesterday';
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<TaskChatProvider>();
    final workspace = context.watch<TaskWorkspaceProvider>();
    final currentTask = chat.currentTask ?? widget.task;
    final isPendingLocked = currentTask.status == 'pending' && !(workspace.me?.isAdmin ?? false);
    final myId = workspace.me?.id ?? 0;

    final points = currentTask.points;
    final donePoints = points.where((p) => p.isDone).length;

    // Trigger scroll down on message arrival
    if (chat.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TaskColors.slateText),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentTask.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: TaskColors.slateText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (currentTask.projectName != null)
              Text(
                currentTask.projectName!,
                style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: StatusChip(status: currentTask.status),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Top Checklist Accordion Bar ────────────────────────────────────
          if (points.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: TaskColors.border)),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _checklistExpanded = !_checklistExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.checklist_rounded, size: 16, color: TaskColors.medicalAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Checklist $donePoints/${points.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: TaskColors.slateText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TaskProgressBar(
                              done: donePoints,
                              total: points.length,
                              status: currentTask.status,
                              dueDate: currentTask.dueDate,
                              showLabel: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _checklistExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: TaskColors.slateMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_checklistExpanded)
                    Container(
                      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
                      child: Column(
                        children: points.map((p) {
                          return InkWell(
                            onTap: () => chat.toggleChecklistPoint(p),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    p.isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                    size: 16,
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
                    ),
                ],
              ),
            ),

          // ── Messages List ──────────────────────────────────────────────────
          Expanded(
            child: chat.loading
                ? const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent))
                : chat.messages.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No messages yet',
                        hint: 'Say something to get this task moving.',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: chat.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chat.messages[index];
                          final isMine = msg.sender.id == myId;

                          // Check if we should render a day separator
                          bool showDaySeparator = false;
                          String dayLabel = '';
                          if (index == 0) {
                            showDaySeparator = true;
                            dayLabel = _formatDaySeparator(msg.createdAt);
                          } else {
                            final prevMsg = chat.messages[index - 1];
                            final prevDay = _formatDaySeparator(prevMsg.createdAt);
                            final currentDay = _formatDaySeparator(msg.createdAt);
                            if (prevDay != currentDay) {
                              showDaySeparator = true;
                              dayLabel = currentDay;
                            }
                          }

                          return Column(
                            children: [
                              if (showDaySeparator && dayLabel.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: TaskColors.border),
                                    ),
                                    child: Text(
                                      dayLabel,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: TaskColors.slateMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              MessageBubble(
                                message: msg,
                                isMine: isMine,
                                onReply: (m) => chat.setReplyingTo(m),
                                onEdit: (m) => chat.setEditingMessage(m),
                                onDelete: (id) => chat.deleteMessage(id),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ── Typing Indicator ───────────────────────────────────────────────
          if (chat.typingNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${chat.typingNames.join(', ')} ${chat.typingNames.length == 1 ? 'is' : 'are'} typing…',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: TaskColors.slateMuted,
                  ),
                ),
              ),
            ),

          // ── Bottom Input Bar / Pending Lock ────────────────────────────────
          if (isPendingLocked)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: const Text(
                'This task is still pending — chat opens once it is in progress.',
                style: TextStyle(fontSize: 12, color: TaskColors.slateMuted),
                textAlign: TextAlign.center,
              ),
            )
          else
            ChatInputBar(
              replyingTo: chat.replyingTo,
              editingMessage: chat.editingMessage,
              pendingImage: chat.pendingImage,
              isSending: chat.isSending,
              onTextChanged: (txt) => chat.onTextChanged(txt),
              onSendText: (txt) => chat.sendTextMessage(txt),
              onSendImage: () => chat.sendImageMessage(),
              onImageSelected: (file) => chat.setPendingImage(file),
              onClearAction: () => chat.clearActionState(),
            ),
        ],
      ),
    );
  }
}
