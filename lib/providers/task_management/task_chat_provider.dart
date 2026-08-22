import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/services/task_management/task_api_service.dart';
import '../../core/services/task_management/task_socket_service.dart';
import '../../models/task_management/task_message_model.dart';
import '../../models/task_management/task_model.dart';

class TaskChatProvider extends ChangeNotifier {
  final TaskApiService _api = TaskApiService();
  final TaskSocketService _socket = TaskSocketService();

  int? _currentTaskId;
  TaskItem? _currentTask;
  List<TaskMessage> _messages = [];
  bool _loading = false;
  String? _error;

  TaskMessage? _replyingTo;
  TaskMessage? _editingMessage;
  File? _pendingImage;
  bool _isSending = false;

  final Map<int, String> _typingUsers = {};
  Timer? _typingDebounce;
  bool _isLocalTyping = false;

  StreamSubscription? _newMsgSub;
  StreamSubscription? _updateMsgSub;
  StreamSubscription? _deleteMsgSub;
  StreamSubscription? _typingSub;

  int? get currentTaskId => _currentTaskId;
  TaskItem? get currentTask => _currentTask;
  List<TaskMessage> get messages => _messages;
  bool get loading => _loading;
  String? get error => _error;
  TaskMessage? get replyingTo => _replyingTo;
  TaskMessage? get editingMessage => _editingMessage;
  File? get pendingImage => _pendingImage;
  bool get isSending => _isSending;
  List<String> get typingNames => _typingUsers.values.toList();

  TaskChatProvider() {
    _initSocketListeners();
  }

  void _initSocketListeners() {
    _newMsgSub = _socket.onNewMessage.listen((msg) {
      if (msg.taskId == _currentTaskId) {
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages.add(msg);
          notifyListeners();
        }
      }
    });

    _updateMsgSub = _socket.onUpdateMessage.listen((msg) {
      if (msg.taskId == _currentTaskId) {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx >= 0) {
          _messages[idx] = msg;
          notifyListeners();
        }
      }
    });

    _deleteMsgSub = _socket.onDeleteMessage.listen((msg) {
      if (msg.taskId == _currentTaskId) {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx >= 0) {
          _messages[idx] = msg;
          notifyListeners();
        }
      }
    });

    _typingSub = _socket.onTyping.listen((data) {
      final taskId = int.tryParse(data['taskId']?.toString() ?? '');
      final employeeId = int.tryParse(data['employeeId']?.toString() ?? '');
      final name = data['name']?.toString() ?? 'Someone';
      final isTyping = data['isTyping'] == true;

      if (taskId == _currentTaskId && employeeId != null) {
        if (isTyping) {
          _typingUsers[employeeId] = name;
        } else {
          _typingUsers.remove(employeeId);
        }
        notifyListeners();
      }
    });
  }

  Future<void> openConversation(TaskItem task) async {
    if (_currentTaskId == task.id) {
      _currentTask = task;
      notifyListeners();
      return;
    }

    // Leave previous
    if (_currentTaskId != null) {
      _socket.leaveTask(_currentTaskId!);
    }

    _currentTaskId = task.id;
    _currentTask = task;
    _messages = [];
    _loading = true;
    _error = null;
    _replyingTo = null;
    _editingMessage = null;
    _pendingImage = null;
    _typingUsers.clear();
    notifyListeners();

    _socket.joinTask(task.id);
    _api.markTaskRead(task.id);

    final res = await _api.fetchTaskMessages(task.id);
    if (res.success && res.data != null) {
      _messages = res.data!;
      _error = null;
    } else {
      _error = res.message ?? 'Could not load conversation.';
    }

    _loading = false;
    notifyListeners();
  }

  void setReplyingTo(TaskMessage? msg) {
    _replyingTo = msg;
    _editingMessage = null;
    notifyListeners();
  }

  void setEditingMessage(TaskMessage? msg) {
    _editingMessage = msg;
    _replyingTo = null;
    notifyListeners();
  }

  void setPendingImage(File? file) {
    _pendingImage = file;
    notifyListeners();
  }

  void clearActionState() {
    _replyingTo = null;
    _editingMessage = null;
    _pendingImage = null;
    notifyListeners();
  }

  void onTextChanged(String text) {
    if (_currentTaskId == null) return;
    if (text.isNotEmpty && !_isLocalTyping) {
      _isLocalTyping = true;
      _socket.startTyping(_currentTaskId!);
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1400), () {
      _isLocalTyping = false;
      if (_currentTaskId != null) {
        _socket.stopTyping(_currentTaskId!);
      }
    });
  }

  Future<bool> sendTextMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty || _currentTaskId == null) return false;

    _isSending = true;
    notifyListeners();

    _isLocalTyping = false;
    _typingDebounce?.cancel();
    _socket.stopTyping(_currentTaskId!);

    bool success = false;

    if (_editingMessage != null) {
      final msgId = _editingMessage!.id;
      final socketOk = await _socket.editMessage(
        taskId: _currentTaskId!,
        messageId: msgId,
        content: content,
      );

      if (!socketOk) {
        final restRes = await _api.editMessage(_currentTaskId!, msgId, content);
        if (restRes.success && restRes.data != null) {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx >= 0) _messages[idx] = restRes.data!;
          success = true;
        }
      } else {
        success = true;
      }
      _editingMessage = null;
    } else {
      final replyId = _replyingTo?.id;
      final socketOk = await _socket.sendTextMessage(
        taskId: _currentTaskId!,
        content: content,
        replyToId: replyId,
      );

      if (!socketOk) {
        final restRes = await _api.sendTextMessage(_currentTaskId!, content, replyToId: replyId);
        if (restRes.success && restRes.data != null) {
          if (!_messages.any((m) => m.id == restRes.data!.id)) {
            _messages.add(restRes.data!);
          }
          success = true;
        }
      } else {
        success = true;
      }
      _replyingTo = null;
    }

    _isSending = false;
    notifyListeners();
    return success;
  }

  Future<bool> sendImageMessage() async {
    if (_pendingImage == null || _currentTaskId == null) return false;

    _isSending = true;
    notifyListeners();

    bool success = false;
    final file = _pendingImage!;
    final replyId = _replyingTo?.id;

    try {
      final uploadRes = await _api.uploadImage(file);
      if (uploadRes.success && uploadRes.data != null) {
        final imageUrl = uploadRes.data!;
        final socketOk = await _socket.sendImageMessage(
          taskId: _currentTaskId!,
          imageUrl: imageUrl,
          replyToId: replyId,
        );

        if (!socketOk) {
          final restRes = await _api.sendImageMessage(_currentTaskId!, file, replyToId: replyId);
          if (restRes.success && restRes.data != null) {
            if (!_messages.any((m) => m.id == restRes.data!.id)) {
              _messages.add(restRes.data!);
            }
            success = true;
          }
        } else {
          success = true;
        }
        _pendingImage = null;
        _replyingTo = null;
      }
    } catch (_) {
      success = false;
    }

    _isSending = false;
    notifyListeners();
    return success;
  }

  Future<bool> deleteMessage(int messageId) async {
    if (_currentTaskId == null) return false;

    final socketOk = await _socket.deleteMessage(taskId: _currentTaskId!, messageId: messageId);
    if (!socketOk) {
      final res = await _api.deleteMessage(_currentTaskId!, messageId);
      if (res.success) {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx >= 0) {
          _messages[idx] = _messages[idx].copyWith(isDeleted: true);
          notifyListeners();
        }
        return true;
      }
      return false;
    }
    return true;
  }

  Future<void> toggleChecklistPoint(ChecklistPoint point) async {
    if (_currentTask == null || point.id == null) return;
    final taskId = _currentTask!.id;
    final newDone = !point.isDone;

    final updatedPoints = _currentTask!.points.map((p) {
      if (p.id == point.id) return p.copyWith(isDone: newDone);
      return p;
    }).toList();

    _currentTask = _currentTask!.copyWith(points: updatedPoints);
    notifyListeners();

    await _api.toggleTaskPoint(taskId, point.id!, newDone);
  }

  void closeConversation() {
    if (_currentTaskId != null) {
      _socket.leaveTask(_currentTaskId!);
    }
    _currentTaskId = null;
    _currentTask = null;
    _messages = [];
    _replyingTo = null;
    _editingMessage = null;
    _pendingImage = null;
    _typingUsers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    closeConversation();
    _newMsgSub?.cancel();
    _updateMsgSub?.cancel();
    _deleteMsgSub?.cancel();
    _typingSub?.cancel();
    _typingDebounce?.cancel();
    super.dispose();
  }
}
