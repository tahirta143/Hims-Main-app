import 'task_model.dart';

class TaskDepartment {
  final int id;
  final String name;

  TaskDepartment({
    required this.id,
    required this.name,
  });

  factory TaskDepartment.fromJson(Map<String, dynamic> json) {
    return TaskDepartment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class ProjectItem {
  final int id;
  final String name;
  final String? description;
  final int? departmentId;
  final String? departmentName;
  final String? startDate;
  final String? deadlineDate;
  final String status; // 'active' | 'completed' | 'on_hold'
  final int memberCount;
  final int taskCount;
  final int completedTaskCount;
  final double progressPercent;
  final List<TaskAssignee> members;

  ProjectItem({
    required this.id,
    required this.name,
    this.description,
    this.departmentId,
    this.departmentName,
    this.startDate,
    this.deadlineDate,
    required this.status,
    this.memberCount = 0,
    this.taskCount = 0,
    this.completedTaskCount = 0,
    this.progressPercent = 0.0,
    this.members = const [],
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    final membersList = (json['members'] as List<dynamic>?)
            ?.map((e) => TaskAssignee.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final totalTasks = json['taskCount'] is int
        ? json['taskCount']
        : int.tryParse(json['taskCount']?.toString() ?? '0') ?? 0;
    final doneTasks = json['completedTaskCount'] is int
        ? json['completedTaskCount']
        : int.tryParse(json['completedTaskCount']?.toString() ?? '0') ?? 0;
    final pct = totalTasks > 0 ? (doneTasks / totalTasks) * 100 : 0.0;

    return ProjectItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      departmentId: json['departmentId'] is int
          ? json['departmentId']
          : int.tryParse(json['departmentId']?.toString() ?? ''),
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString(),
      startDate: json['startDate']?.toString() ?? json['start_date']?.toString(),
      deadlineDate: json['deadlineDate']?.toString() ?? json['deadline_date']?.toString(),
      status: json['status']?.toString() ?? 'active',
      memberCount: json['memberCount'] is int
          ? json['memberCount']
          : int.tryParse(json['memberCount']?.toString() ?? '0') ?? membersList.length,
      taskCount: totalTasks,
      completedTaskCount: doneTasks,
      progressPercent: json['progressPercent'] != null
          ? (json['progressPercent'] is num ? (json['progressPercent'] as num).toDouble() : double.tryParse(json['progressPercent'].toString()) ?? pct)
          : pct,
      members: membersList,
    );
  }
}

class ProjectCompletion {
  final int id;
  final int projectId;
  final String evaluationDate;
  final double score;
  final String? feedback;
  final String? evaluatorName;

  ProjectCompletion({
    required this.id,
    required this.projectId,
    required this.evaluationDate,
    required this.score,
    this.feedback,
    this.evaluatorName,
  });

  factory ProjectCompletion.fromJson(Map<String, dynamic> json) {
    return ProjectCompletion(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId: json['projectId'] is int ? json['projectId'] : int.tryParse(json['projectId']?.toString() ?? '0') ?? 0,
      evaluationDate: json['evaluationDate']?.toString() ?? json['evaluation_date']?.toString() ?? '',
      score: json['score'] is num ? (json['score'] as num).toDouble() : double.tryParse(json['score']?.toString() ?? '0') ?? 0.0,
      feedback: json['feedback']?.toString(),
      evaluatorName: json['evaluatorName']?.toString() ?? json['evaluator_name']?.toString(),
    );
  }
}
