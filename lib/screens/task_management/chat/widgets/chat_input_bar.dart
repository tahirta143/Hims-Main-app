import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../custum widgets/task_management/task_primitives.dart';
import '../../../../models/task_management/task_message_model.dart';

class ChatInputBar extends StatefulWidget {
  final TaskMessage? replyingTo;
  final TaskMessage? editingMessage;
  final File? pendingImage;
  final bool isSending;
  final ValueChanged<String> onTextChanged;
  final Function(String) onSendText;
  final VoidCallback onSendImage;
  final Function(File) onImageSelected;
  final VoidCallback onClearAction;

  const ChatInputBar({
    super.key,
    this.replyingTo,
    this.editingMessage,
    this.pendingImage,
    required this.isSending,
    required this.onTextChanged,
    required this.onSendText,
    required this.onSendImage,
    required this.onImageSelected,
    required this.onClearAction,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != null && oldWidget.editingMessage?.id != widget.editingMessage?.id) {
      _textController.text = widget.editingMessage?.content ?? '';
    } else if (widget.editingMessage == null && oldWidget.editingMessage != null) {
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        widget.onImageSelected(File(picked.path));
      }
    } catch (_) {}
  }

  void _handleSend() {
    if (widget.pendingImage != null) {
      widget.onSendImage();
    } else {
      final text = _textController.text.trim();
      if (text.isNotEmpty) {
        widget.onSendText(text);
        _textController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: TaskColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply / Edit Banner
          if (widget.replyingTo != null || widget.editingMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: TaskColors.medicalAccent, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.editingMessage != null
                              ? 'Editing your message'
                              : 'Replying to ${widget.replyingTo?.sender.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: TaskColors.medicalAccentDark,
                          ),
                        ),
                        Text(
                          (widget.editingMessage ?? widget.replyingTo)?.content ?? 'Photo',
                          style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClearAction,
                    icon: const Icon(Icons.close_rounded, size: 16, color: TaskColors.slateLight),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Pending Image Preview Banner
          if (widget.pendingImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TaskColors.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      widget.pendingImage!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Attached photo ready to send',
                      style: TextStyle(fontSize: 12, color: TaskColors.slateText),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClearAction,
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48)),
                  ),
                ],
              ),
            ),

          // Input Row
          Row(
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_camera_outlined, color: TaskColors.slateMuted),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: TaskColors.border),
                  ),
                  child: TextField(
                    controller: _textController,
                    onChanged: widget.onTextChanged,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 13, color: TaskColors.slateText),
                    decoration: const InputDecoration(
                      hintText: 'Write a message…',
                      hintStyle: TextStyle(fontSize: 13, color: TaskColors.slateLight),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.isSending ? null : _handleSend,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: TaskColors.medicalAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: TaskColors.medicalAccent.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: widget.isSending
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
