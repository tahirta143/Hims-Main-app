class TaskAssignee {
  final int id;
  final String name;
  final String? employeeCode;
  final String? designation;
  final String? departmentName;
  final String? profileImageUrl;
  final bool? hasAccess;

  TaskAssignee({
    required this.id,
    required this.name,
    this.employeeCode,
    this.designation,
    this.departmentName,
    this.profileImageUrl,
    this.hasAccess,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString(),
      designation: json['designation']?.toString(),
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString(),
      profileImageUrl: json['profileImageUrl']?.toString(),
      hasAccess: json['hasAccess'] is bool ? json['hasAccess'] : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'employeeCode': employeeCode,
    'designation': designation,
    'departmentName': departmentName,
    'profileImageUrl': profileImageUrl,
    'hasAccess': hasAccess,
  };
}

class ChecklistPoint {
  final int? id;
  final String label;
  final bool isDone;

  ChecklistPoint({
    this.id,
    required this.label,
    this.isDone = false,
  });

  factory ChecklistPoint.fromJson(Map<String, dynamic> json) {
    return ChecklistPoint(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      label: json['label']?.toString() ?? '',
      isDone: json['isDone'] == true || json['isDone'] == 1 || json['is_done'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'label': label,
    'isDone': isDone,
  };

  ChecklistPoint copyWith({int? id, String? label, bool? isDone}) {
    return ChecklistPoint(
      id: id ?? this.id,
      label: label ?? this.label,
      isDone: isDone ?? this.isDone,
    );
  }
}

class LastMessagePreview {
  final int id;
  final String? content;
  final String? type;
  final String? imageUrl;
  final String senderName;
  final String createdAt;
  final bool isDeleted;

  LastMessagePreview({
    required this.id,
    this.content,
    this.type,
    this.imageUrl,
    required this.senderName,
    required this.createdAt,
    this.isDeleted = false,
  });

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) {
    return LastMessagePreview(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      content: json['content']?.toString(),
      type: json['type']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      senderName: json['senderName']?.toString() ?? json['sender_name']?.toString() ?? 'Unknown',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == 1,
    );
  }
}

class TaskItem {
  final int id;
  final String title;
  final String? description;
  final String? projectName;
  final int? projectId;
  final String? departmentName;
  final int? departmentId;
  final String status; // 'pending' | 'in_progress' | 'completed' | 'hold'
  final String priority; // 'low' | 'medium' | 'high' | 'urgent'
  final String? startDate;
  final String? dueDate;
  final String? createdAt;
  final TaskAssignee? createdByUser;
  final List<TaskAssignee> assignees;
  final List<ChecklistPoint> points;
  final LastMessagePreview? lastMessage;
  final int unreadCount;

  TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.projectName,
    this.projectId,
    this.departmentName,
    this.departmentId,
    required this.status,
    required this.priority,
    this.startDate,
    this.dueDate,
    this.createdAt,
    this.createdByUser,
    this.assignees = const [],
    this.points = const [],
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final assigneesList = (json['assignees'] as List<dynamic>?)
            ?.map((e) => TaskAssignee.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final pointsList = (json['points'] as List<dynamic>?)
            ?.map((e) => ChecklistPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return TaskItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      projectName: json['projectName']?.toString() ?? json['project_name']?.toString(),
      projectId: json['projectId'] is int ? json['projectId'] : int.tryParse(json['projectId']?.toString() ?? ''),
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString(),
      departmentId: json['departmentId'] is int ? json['departmentId'] : int.tryParse(json['departmentId']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'pending',
      priority: json['priority']?.toString() ?? 'medium',
      startDate: json['startDate']?.toString() ?? json['start_date']?.toString(),
      dueDate: json['dueDate']?.toString() ?? json['due_date']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      createdByUser: json['createdByUser'] != null
          ? TaskAssignee.fromJson(json['createdByUser'] as Map<String, dynamic>)
          : null,
      assignees: assigneesList,
      points: pointsList,
      lastMessage: json['lastMessage'] != null
          ? LastMessagePreview.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount']
          : int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0,
    );
  }

  TaskItem copyWith({
    int? id,
    String? title,
    String? description,
    String? projectName,
    int? projectId,
    String? departmentName,
    int? departmentId,
    String? status,
    String? priority,
    String? startDate,
    String? dueDate,
    String? createdAt,
    TaskAssignee? createdByUser,
    List<TaskAssignee>? assignees,
    List<ChecklistPoint>? points,
    LastMessagePreview? lastMessage,
    int? unreadCount,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      projectName: projectName ?? this.projectName,
      projectId: projectId ?? this.projectId,
      departmentName: departmentName ?? this.departmentName,
      departmentId: departmentId ?? this.departmentId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      createdByUser: createdByUser ?? this.createdByUser,
      assignees: assignees ?? this.assignees,
      points: points ?? this.points,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class TaskEvaluation {
  final int? id;
  final int employeeId;
  final String? employeeName;
  final String? designation;
  final String? employeeCode;
  final int rating;
  final String? remarks;
  final String? evaluatorName;
  final String? createdAt;

  TaskEvaluation({
    this.id,
    required this.employeeId,
    this.employeeName,
    this.designation,
    this.employeeCode,
    required this.rating,
    this.remarks,
    this.evaluatorName,
    this.createdAt,
  });

  factory TaskEvaluation.fromJson(Map<String, dynamic> json) {
    return TaskEvaluation(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      employeeId: json['employeeId'] is int
          ? json['employeeId']
          : int.tryParse(json['employeeId']?.toString() ?? '0') ?? 0,
      employeeName: json['employeeName']?.toString(),
      designation: json['designation']?.toString(),
      employeeCode: json['employeeCode']?.toString(),
      rating: json['rating'] is int ? json['rating'] : int.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      remarks: json['remarks']?.toString(),
      evaluatorName: json['evaluatorName']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'employeeId': employeeId,
    'rating': rating,
    'remarks': remarks,
  };
}
