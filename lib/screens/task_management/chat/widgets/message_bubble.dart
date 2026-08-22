import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../custum widgets/task_management/task_primitives.dart';
import '../../../../models/task_management/task_message_model.dart';
import 'image_lightbox.dart';

class MessageBubble extends StatelessWidget {
  final TaskMessage message;
  final bool isMine;
  final Function(TaskMessage) onReply;
  final Function(TaskMessage) onEdit;
  final Function(int) onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return DateFormat('h:mm a').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            AvatarWidget(person: message.sender, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActions(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMine ? TaskColors.medicalAccent : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 2),
                    bottomRight: Radius.circular(isMine ? 2 : 16),
                  ),
                  border: Border.all(
                    color: isMine ? TaskColors.medicalAccent : TaskColors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Sender Name for other's messages
                    if (!isMine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.sender.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: TaskColors.medicalAccentDark,
                          ),
                        ),
                      ),

                    // Reply Preview
                    if (message.replyInfo != null && !message.isDeleted)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMine ? Colors.white.withOpacity(0.15) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(
                            left: BorderSide(
                              color: isMine ? Colors.white : TaskColors.medicalAccent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.replyInfo!.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isMine ? Colors.white : TaskColors.medicalAccent,
                              ),
                            ),
                            Text(
                              message.replyInfo!.isDeleted
                                  ? 'Message deleted'
                                  : message.replyInfo!.type == 'image'
                                      ? 'Photo'
                                      : (message.replyInfo!.content ?? ''),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMine ? Colors.white70 : TaskColors.slateMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                    // Content
                    if (message.isDeleted)
                      Text(
                        'This message was deleted',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: isMine ? Colors.white70 : TaskColors.slateLight,
                        ),
                      )
                    else if (message.type == 'image' && message.imageUrl != null)
                      GestureDetector(
                        onTap: () => ImageLightbox.show(context, message.imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: CachedNetworkImage(
                              imageUrl: message.imageUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 140,
                                color: isMine ? Colors.white12 : const Color(0xFFF1F5F9),
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        message.content ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: isMine ? Colors.white : TaskColors.slateText,
                          height: 1.35,
                        ),
                      ),

                    // Time & Status indicator
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (message.editedAt != null && !message.isDeleted) ...[
                          Text(
                            'edited',
                            style: TextStyle(
                              fontSize: 9,
                              color: isMine ? Colors.white70 : TaskColors.slateLight,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 9,
                            color: isMine ? Colors.white70 : TaskColors.slateLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    if (message.isDeleted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: TaskColors.slateMuted),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply(message);
              },
            ),
            if (message.canEdit && message.type == 'text')
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: TaskColors.slateMuted),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit(message);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48)),
                title: const Text('Delete message', style: TextStyle(color: Color(0xFFE11D48))),
                onTap: () {
                  Navigator.pop(context);
                  onDelete(message.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}
