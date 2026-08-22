import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/task_management/task_api_service.dart';
import '../../core/services/task_management/task_socket_service.dart';

class TaskWorkspaceBlockedState {
  final String code;
  final String message;

  TaskWorkspaceBlockedState({required this.code, required this.message});
}

class TaskWorkspaceProvider extends ChangeNotifier {
  final TaskApiService _api = TaskApiService();
  final TaskSocketService _socket = TaskSocketService();

  bool _ready = false;
  bool _loading = false;
  TaskCurrentUser? _me;
  TaskWorkspaceBlockedState? _blocked;
  int _unreadCount = 0;

  StreamSubscription? _taskStateSub;
  StreamSubscription? _sessionTerminatedSub;

  bool get ready => _ready;
  bool get loading => _loading;
  TaskCurrentUser? get me => _me;
  TaskWorkspaceBlockedState? get blocked => _blocked;
  int get unreadCount => _unreadCount;
  bool get isBlocked => _blocked != null;

  Future<void> initializeWorkspace() async {
    _loading = true;
    _blocked = null;
    notifyListeners();

    try {
      final meRes = await _api.fetchMe();
      if (meRes.success && meRes.data != null) {
        _me = meRes.data;
        _blocked = null;
        await refreshUnread();

        // Connect presence & chat sockets
        await _socket.connectPresence();
        await _socket.connectChat();

        _listenToSocketEvents();
      } else {
        _me = null;
        _blocked = TaskWorkspaceBlockedState(
          code: meRes.code ?? 'BLOCKED',
          message: meRes.message ??
              'Your login is not linked to an employee record, so Task Management cannot identify you.',
        );
      }
    } catch (e) {
      _blocked = TaskWorkspaceBlockedState(
        code: 'ERROR',
        message: 'Could not connect to Task Management. Please check your network.',
      );
    } finally {
      _loading = false;
      _ready = true;
      notifyListeners();
    }
  }

  void _listenToSocketEvents() {
    _taskStateSub?.cancel();
    _taskStateSub = _socket.onTaskState.listen((_) {
      refreshUnread();
    });

    _sessionTerminatedSub?.cancel();
    _sessionTerminatedSub = _socket.onSessionTerminated.listen((reason) {
      debugPrint('Task Session terminated: $reason');
      notifyListeners();
    });
  }

  Future<void> refreshUnread() async {
    final count = await _api.fetchUnreadTotal();
    _unreadCount = count;
    notifyListeners();
  }

  void decrementUnread(int amount) {
    if (_unreadCount > 0) {
      _unreadCount = (_unreadCount - amount).clamp(0, 9999);
      notifyListeners();
    }
  }

  void reset() {
    _taskStateSub?.cancel();
    _sessionTerminatedSub?.cancel();
    _socket.disconnect();
    _ready = false;
    _loading = false;
    _me = null;
    _blocked = null;
    _unreadCount = 0;
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
