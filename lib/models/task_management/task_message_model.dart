import 'task_model.dart';

class MessageReplyInfo {
  final int id;
  final String name;
  final String? content;
  final String? type;
  final bool isDeleted;

  MessageReplyInfo({
    required this.id,
    required this.name,
    this.content,
    this.type,
    this.isDeleted = false,
  });

  factory MessageReplyInfo.fromJson(Map<String, dynamic> json) {
    return MessageReplyInfo(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      content: json['content']?.toString(),
      type: json['type']?.toString(),
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'type': type,
    'isDeleted': isDeleted,
  };
}

class TaskMessage {
  final int id;
  final int taskId;
  final String type; // 'text' | 'image' | 'system'
  final String? content;
  final String? imageUrl;
  final TaskAssignee sender;
  final MessageReplyInfo? replyInfo;
  final String createdAt;
  final String? editedAt;
  final bool isDeleted;
  final bool canEdit;

  TaskMessage({
    required this.id,
    required this.taskId,
    required this.type,
    this.content,
    this.imageUrl,
    required this.sender,
    this.replyInfo,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.canEdit = false,
  });

  factory TaskMessage.fromJson(Map<String, dynamic> json) {
    final senderObj = json['sender'] != null
        ? TaskAssignee.fromJson(json['sender'] as Map<String, dynamic>)
        : TaskAssignee(
            id: json['senderId'] is int ? json['senderId'] : int.tryParse(json['senderId']?.toString() ?? '0') ?? 0,
            name: json['senderName']?.toString() ?? 'User',
          );

    return TaskMessage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      taskId: json['taskId'] is int ? json['taskId'] : int.tryParse(json['taskId']?.toString() ?? '0') ?? 0,
      type: json['type']?.toString() ?? 'text',
      content: json['content']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      sender: senderObj,
      replyInfo: json['replyInfo'] != null
          ? MessageReplyInfo.fromJson(json['replyInfo'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      editedAt: json['editedAt']?.toString() ?? json['edited_at']?.toString(),
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == 1,
      canEdit: json['canEdit'] == true,
    );
  }

  TaskMessage copyWith({
    int? id,
    int? taskId,
    String? type,
    String? content,
    String? imageUrl,
    TaskAssignee? sender,
    MessageReplyInfo? replyInfo,
    String? createdAt,
    String? editedAt,
    bool? isDeleted,
    bool? canEdit,
  }) {
    return TaskMessage(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      type: type ?? this.type,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      sender: sender ?? this.sender,
      replyInfo: replyInfo ?? this.replyInfo,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      canEdit: canEdit ?? this.canEdit,
    );
  }
}
