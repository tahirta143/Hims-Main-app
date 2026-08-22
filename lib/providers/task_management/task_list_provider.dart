import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/task_management/task_api_service.dart';
import '../../core/services/task_management/task_socket_service.dart';
import '../../models/task_management/task_model.dart';

class TaskListProvider extends ChangeNotifier {
  final TaskApiService _api = TaskApiService();
  final TaskSocketService _socket = TaskSocketService();

  List<TaskItem> _items = [];
  bool _loading = false;
  String? _error;
  String _scope = 'mine'; // 'mine' | 'all'
  String _search = '';
  String? _statusFilter;
  int? _projectFilter;
  int? _departmentFilter;

  StreamSubscription? _taskStateSub;
  StreamSubscription? _newMessageSub;

  List<TaskItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  String get scope => _scope;
  String get search => _search;
  String? get statusFilter => _statusFilter;
  int? get projectFilter => _projectFilter;
  int? get departmentFilter => _departmentFilter;

  TaskListProvider() {
    _initSocketListeners();
  }

  void _initSocketListeners() {
    _taskStateSub = _socket.onTaskState.listen((data) {
      final taskId = int.tryParse(data['taskId']?.toString() ?? '');
      if (taskId != null) {
        final lastMsg = data['lastMessage'];
        if (lastMsg is Map<String, dynamic>) {
          _updateTaskChatPreview(taskId, LastMessagePreview.fromJson(lastMsg));
        }
      }
    });

    _newMessageSub = _socket.onNewMessage.listen((msg) {
      _updateTaskChatPreview(
        msg.taskId,
        LastMessagePreview(
          id: msg.id,
          content: msg.content,
          type: msg.type,
          imageUrl: msg.imageUrl,
          senderName: msg.sender.name,
          createdAt: msg.createdAt,
          isDeleted: msg.isDeleted,
        ),
        incrementUnread: true,
      );
    });
  }

  void setScope(String newScope) {
    if (_scope != newScope) {
      _scope = newScope;
      loadTasks();
    }
  }

  void setSearch(String query) {
    _search = query;
    notifyListeners();
  }

  void setFilters({String? status, int? projectId, int? departmentId}) {
    _statusFilter = status;
    _projectFilter = projectId;
    _departmentFilter = departmentId;
    loadTasks();
  }

  Future<void> loadTasks({String? customScope, String? orderBy}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    final targetScope = customScope ?? _scope;
    final res = await _api.fetchTasks(
      scope: targetScope == 'mine' ? 'mine' : null,
      status: _statusFilter,
      projectId: _projectFilter,
      departmentId: _departmentFilter,
      orderBy: orderBy,
    );

    if (res.success && res.data != null) {
      _items = res.data!;
      _error = null;
    } else {
      _error = res.message ?? 'Could not load tasks.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> moveTask(int taskId, String targetStatus) async {
    final idx = _items.indexWhere((t) => t.id == taskId);
    if (idx == -1) return false;

    final oldTask = _items[idx];
    if (oldTask.status == targetStatus) return true;

    // Optimistic update
    _items[idx] = oldTask.copyWith(status: targetStatus);
    notifyListeners();

    final res = await _api.patchTask(taskId, {'status': targetStatus});
    if (res.success && res.data != null) {
      _items[idx] = res.data!;
      notifyListeners();
      return true;
    } else {
      // Rollback
      _items[idx] = oldTask;
      notifyListeners();
      return false;
    }
  }

  void upsertTask(TaskItem task) {
    final idx = _items.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      _items[idx] = task;
    } else {
      _items.insert(0, task);
    }
    notifyListeners();
  }

  void removeTask(int taskId) {
    _items.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  Future<bool> togglePoint(int taskId, int pointId, bool isDone) async {
    final taskIdx = _items.indexWhere((t) => t.id == taskId);
    if (taskIdx >= 0) {
      final task = _items[taskIdx];
      final updatedPoints = task.points.map((p) {
        if (p.id == pointId) return p.copyWith(isDone: isDone);
        return p;
      }).toList();
      _items[taskIdx] = task.copyWith(points: updatedPoints);
      notifyListeners();
    }

    final res = await _api.toggleTaskPoint(taskId, pointId, isDone);
    if (res.success && res.data != null) {
      if (taskIdx >= 0) {
        _items[taskIdx] = res.data!;
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  void clearUnread(int taskId) {
    final idx = _items.indexWhere((t) => t.id == taskId);
    if (idx >= 0 && _items[idx].unreadCount > 0) {
      _items[idx] = _items[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
    _api.markTaskRead(taskId);
  }

  void _updateTaskChatPreview(int taskId, LastMessagePreview lastMessage, {bool incrementUnread = false}) {
    final idx = _items.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      final current = _items[idx];
      _items[idx] = current.copyWith(
        lastMessage: lastMessage,
        unreadCount: incrementUnread ? current.unreadCount + 1 : current.unreadCount,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _taskStateSub?.cancel();
    _newMessageSub?.cancel();
    super.dispose();
  }
}
