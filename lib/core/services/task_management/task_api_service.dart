import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:hims_app/global/global_api.dart';
import '../../services/auth_storage_service.dart';
import '../../../models/task_management/task_model.dart';
import '../../../models/task_management/task_message_model.dart';
import '../../../models/task_management/project_model.dart';
import '../../../models/task_management/task_report_model.dart';
import '../../../models/task_management/task_session_model.dart';

class TaskApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? code;

  TaskApiResponse({
    required this.success,
    this.data,
    this.message,
    this.code,
  });
}

class TaskCurrentUser {
  final int id;
  final String name;
  final String? employeeCode;
  final String? designation;
  final String? departmentName;
  final int? departmentId;
  final bool isAdmin;
  final bool canViewAllTasks;

  TaskCurrentUser({
    required this.id,
    required this.name,
    this.employeeCode,
    this.designation,
    this.departmentName,
    this.departmentId,
    this.isAdmin = false,
    this.canViewAllTasks = false,
  });

  factory TaskCurrentUser.fromJson(Map<String, dynamic> json) {
    return TaskCurrentUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString(),
      designation: json['designation']?.toString(),
      departmentName: json['departmentName']?.toString() ?? json['department_name']?.toString(),
      departmentId: json['departmentId'] is int ? json['departmentId'] : int.tryParse(json['departmentId']?.toString() ?? ''),
      isAdmin: json['isAdmin'] == true,
      canViewAllTasks: json['canViewAllTasks'] == true,
    );
  }
}

class TaskApiService {
  final AuthStorageService _storage = AuthStorageService();

  String get _baseUrl => '${GlobalApi.baseUrl}/tasks';

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Me ─────────────────────────────────────────────────────────────────────
  Future<TaskApiResponse<TaskCurrentUser>> fetchMe() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/me'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && (json['success'] == true || json['item'] != null)) {
        return TaskApiResponse(
          success: true,
          data: TaskCurrentUser.fromJson(json['item'] as Map<String, dynamic>),
        );
      }
      return TaskApiResponse(
        success: false,
        message: json['message']?.toString() ?? 'Could not identify workspace user.',
        code: json['code']?.toString(),
      );
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<int> fetchUnreadTotal() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/me/unread'), headers: await _headers());
      final json = jsonDecode(res.body);
      return json['count'] is int ? json['count'] : int.tryParse(json['count']?.toString() ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────
  Future<TaskApiResponse<List<TaskItem>>> fetchTasks({
    String? scope,
    String? status,
    String? priority,
    int? projectId,
    int? departmentId,
    String? orderBy,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (scope != null) queryParams['scope'] = scope;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;
      if (projectId != null) queryParams['projectId'] = projectId.toString();
      if (departmentId != null) queryParams['departmentId'] = departmentId.toString();
      if (orderBy != null) queryParams['orderBy'] = orderBy;

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await http.get(uri, headers: await _headers());
      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load tasks');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskItem>> fetchTask(int id) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/$id'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskItem.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load task');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskItem>> createTask(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      final json = jsonDecode(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskItem.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to create task');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskItem>> patchTask(int id, Map<String, dynamic> patch) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/$id'),
        headers: await _headers(),
        body: jsonEncode(patch),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskItem.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to update task');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<void>> deleteTask(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/$id'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 || json['success'] == true) {
        return TaskApiResponse(success: true);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to delete task');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskItem>> replaceTaskAssignees(int id, List<int> assigneeIds) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/$id/assignees'),
        headers: await _headers(),
        body: jsonEncode({'assigneeIds': assigneeIds}),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskItem.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to update assignees');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskItem>> toggleTaskPoint(int taskId, int pointId, bool isDone) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/$taskId/points/$pointId'),
        headers: await _headers(),
        body: jsonEncode({'isDone': isDone}),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskItem.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to update checklist');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────
  Future<TaskApiResponse<List<TaskMessage>>> fetchTaskMessages(int taskId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/$taskId/messages'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TaskMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load messages');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskMessage>> sendTextMessage(int taskId, String content, {int? replyToId}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$taskId/messages/text'),
        headers: await _headers(),
        body: jsonEncode({'content': content, 'replyToId': replyToId}),
      );
      final json = jsonDecode(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskMessage.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to send message');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskMessage>> sendImageMessage(int taskId, File imageFile, {int? replyToId}) async {
    try {
      final token = await _storage.getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/$taskId/messages/image'));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (replyToId != null) {
        request.fields['replyToId'] = replyToId.toString();
      }
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);
      final json = jsonDecode(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskMessage.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to send image');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<String>> uploadImage(File imageFile) async {
    try {
      final token = await _storage.getToken();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/uploads/image'));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);
      final json = jsonDecode(res.body);

      if ((res.statusCode == 200 || res.statusCode == 201) && json['item'] != null) {
        final url = json['item']['url']?.toString() ?? '';
        return TaskApiResponse(success: true, data: url);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to upload image');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskMessage>> editMessage(int taskId, int messageId, String content) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/$taskId/messages/$messageId'),
        headers: await _headers(),
        body: jsonEncode({'content': content}),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskMessage.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to edit message');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<void>> deleteMessage(int taskId, int messageId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/$taskId/messages/$messageId'),
        headers: await _headers(),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return TaskApiResponse(success: true);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to delete message');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<void> markTaskRead(int taskId) async {
    try {
      await http.post(Uri.parse('$_baseUrl/$taskId/read'), headers: await _headers());
    } catch (_) {}
  }

  // ── Evaluations ────────────────────────────────────────────────────────────
  Future<TaskApiResponse<List<TaskEvaluation>>> fetchEvaluations(int taskId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/$taskId/evaluations'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TaskEvaluation.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load evaluations');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<List<TaskEvaluation>>> saveEvaluation(int taskId, int employeeId, int rating, String? remarks) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/$taskId/evaluations'),
        headers: await _headers(),
        body: jsonEncode({'employeeId': employeeId, 'rating': rating, 'remarks': remarks}),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TaskEvaluation.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to save evaluation');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  // ── Projects ───────────────────────────────────────────────────────────────
  Future<TaskApiResponse<List<ProjectItem>>> fetchProjects({bool includeClosed = true}) async {
    try {
      final uri = Uri.parse('$_baseUrl/projects').replace(
        queryParameters: {'includeClosed': includeClosed.toString()},
      );
      final res = await http.get(uri, headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => ProjectItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load projects');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<List<TaskAssignee>>> fetchProjectMembers(int projectId) async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/projects/$projectId/members'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TaskAssignee.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load project members');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<ProjectItem>> createProject(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/projects'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      final json = jsonDecode(res.body);
      if ((res.statusCode == 200 || res.statusCode == 201) && json['item'] != null) {
        return TaskApiResponse(success: true, data: ProjectItem.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to create project');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<ProjectItem>> updateProject(int id, Map<String, dynamic> payload) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/projects/$id'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json['item'] != null) {
        return TaskApiResponse(success: true, data: ProjectItem.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to update project');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<void>> deleteProject(int id) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/projects/$id'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return TaskApiResponse(success: true);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to delete project');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<List<TaskAssignee>>> setProjectMembers(int projectId, List<int> memberIds) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/projects/$projectId/members'),
        headers: await _headers(),
        body: jsonEncode({'memberIds': memberIds}),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TaskAssignee.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to set project members');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  // ── People & Departments ───────────────────────────────────────────────────
  Future<TaskApiResponse<List<TaskAssignee>>> fetchPeople() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/people'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TaskAssignee.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load people');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<List<TaskDepartment>>> fetchDepartments() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/departments'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TaskDepartment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load departments');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<TaskDepartment>> createDepartment(String name) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/departments'),
        headers: await _headers(),
        body: jsonEncode({'name': name}),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json['item'] != null) {
        return TaskApiResponse(success: true, data: TaskDepartment.fromJson(json['item'] as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to create department');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<void>> setPersonDepartment(int personId, int? departmentId) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/people/$personId/department'),
        headers: await _headers(),
        body: jsonEncode({'departmentId': departmentId}),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return TaskApiResponse(success: true);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to set department');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  // ── Progress & Reports ─────────────────────────────────────────────────────
  Future<TaskApiResponse<List<ProgressTaskRow>>> fetchProgress() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/progress'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => ProgressTaskRow.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load progress');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<List<UserPerformanceReport>>> fetchUserPerformance() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/reports/user-performance'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => UserPerformanceReport.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load user performance');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<OverviewReport>> fetchOverviewReport() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/reports/overview'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        // Targeted 'data' key based on React unwrapData helper
        final data = json['data'] ?? json;
        return TaskApiResponse(success: true, data: OverviewReport.fromJson(data as Map<String, dynamic>));
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load overview');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<List<DepartmentSummaryReport>>> fetchDepartmentSummary() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/reports/department-summary'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => DepartmentSummaryReport.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load department summary');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<String>> fetchAiInsights() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/reports/ai-insights'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return TaskApiResponse(success: true, data: json['insights']?.toString() ?? '');
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load AI insights');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<String>> sendAiChat(String prompt, {List<dynamic> history = const []}) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/reports/ai-chat'),
        headers: await _headers(),
        body: jsonEncode({'prompt': prompt, 'history': history}),
      );
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return TaskApiResponse(success: true, data: json['reply']?.toString() ?? '');
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to get AI reply');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  // ── Tracking ───────────────────────────────────────────────────────────────
  Future<TaskApiResponse<List<TrackedSession>>> fetchTrackedSessions() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/tracking'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final items = (json['items'] as List<dynamic>?)
                ?.map((e) => TrackedSession.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return TaskApiResponse(success: true, data: items);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to load sessions');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<void>> terminateSession(String sessionTokenId) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/tracking/$sessionTokenId'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return TaskApiResponse(success: true);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to terminate session');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }

  Future<TaskApiResponse<void>> terminateAllForEmployee(int employeeId) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/tracking/employee/$employeeId'), headers: await _headers());
      final json = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return TaskApiResponse(success: true);
      }
      return TaskApiResponse(success: false, message: json['message']?.toString() ?? 'Failed to terminate sessions');
    } catch (e) {
      return TaskApiResponse(success: false, message: e.toString());
    }
  }
}
