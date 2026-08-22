import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hims_app/global/global_api.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../services/auth_storage_service.dart';
import '../../../models/task_management/task_message_model.dart';

class TaskSocketService {
  static final TaskSocketService _instance = TaskSocketService._internal();
  factory TaskSocketService() => _instance;
  TaskSocketService._internal();

  final AuthStorageService _storage = AuthStorageService();

  IO.Socket? _presenceSocket;
  IO.Socket? _chatSocket;
  String? _presenceSessionId;

  // Stream controllers for real-time events
  final _newMessageController = StreamController<TaskMessage>.broadcast();
  final _updateMessageController = StreamController<TaskMessage>.broadcast();
  final _deleteMessageController = StreamController<TaskMessage>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _sessionTerminatedController = StreamController<String?>.broadcast();
  final _taskStateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<TaskMessage> get onNewMessage => _newMessageController.stream;
  Stream<TaskMessage> get onUpdateMessage => _updateMessageController.stream;
  Stream<TaskMessage> get onDeleteMessage => _deleteMessageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<String?> get onSessionTerminated => _sessionTerminatedController.stream;
  Stream<Map<String, dynamic>> get onTaskState => _taskStateController.stream;

  String get _socketOrigin {
    return GlobalApi.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  }

  // ── Presence Socket ────────────────────────────────────────────────────────
  Future<void> connectPresence() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) return;

    if (_presenceSocket != null && _presenceSocket!.connected) return;

    _presenceSocket?.dispose();
    _presenceSocket = IO.io(
      '$_socketOrigin/tm-presence',
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token, if (_presenceSessionId != null) 'sessionId': _presenceSessionId})
          .build(),
    );

    _presenceSocket!.onConnect((_) {
      debugPrint('⚡ Connected to /tm-presence');
    });

    _presenceSocket!.on('presence:ready', (data) {
      if (data is Map && data['sessionId'] != null) {
        _presenceSessionId = data['sessionId'].toString();
      }
    });

    _presenceSocket!.on('session:terminated', (data) {
      final reason = data is Map ? data['reason']?.toString() : null;
      _sessionTerminatedController.add(reason);
      disconnect();
    });

    _presenceSocket!.on('task:new_message', (data) {
      if (data is Map) {
        _taskStateController.add(Map<String, dynamic>.from(data));
      }
    });

    _presenceSocket!.connect();
  }

  // ── Chat Socket ────────────────────────────────────────────────────────────
  Future<void> connectChat() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) return;

    if (_chatSocket != null && _chatSocket!.connected) return;

    _chatSocket?.dispose();
    _chatSocket = IO.io(
      '$_socketOrigin/tm-chat',
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _chatSocket!.onConnect((_) {
      debugPrint('⚡ Connected to /tm-chat');
      _chatSocket!.emit('user:join');
    });

    _chatSocket!.on('message:new', (data) {
      if (data is Map) {
        try {
          final msg = TaskMessage.fromJson(Map<String, dynamic>.from(data));
          _newMessageController.add(msg);
        } catch (e) {
          debugPrint('Error parsing new message: $e');
        }
      }
    });

    _chatSocket!.on('message:update', (data) {
      if (data is Map) {
        try {
          final msg = TaskMessage.fromJson(Map<String, dynamic>.from(data));
          _updateMessageController.add(msg);
        } catch (e) {
          debugPrint('Error parsing update message: $e');
        }
      }
    });

    _chatSocket!.on('message:delete', (data) {
      if (data is Map) {
        try {
          final msg = TaskMessage.fromJson(Map<String, dynamic>.from(data));
          _deleteMessageController.add(msg);
        } catch (e) {
          debugPrint('Error parsing delete message: $e');
        }
      }
    });

    _chatSocket!.on('typing', (data) {
      if (data is Map) {
        _typingController.add(Map<String, dynamic>.from(data));
      }
    });

    _chatSocket!.on('task:message_state', (data) {
      if (data is Map) {
        _taskStateController.add(Map<String, dynamic>.from(data));
      }
    });

    _chatSocket!.on('task:new_message', (data) {
      if (data is Map) {
        _taskStateController.add(Map<String, dynamic>.from(data));
      }
    });

    _chatSocket!.connect();
  }

  void joinTask(int taskId) {
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emit('task:join', {'taskId': taskId});
    }
  }

  void leaveTask(int taskId) {
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emit('task:leave', {'taskId': taskId});
    }
  }

  void startTyping(int taskId) {
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emit('typing:start', {'taskId': taskId});
    }
  }

  void stopTyping(int taskId) {
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emit('typing:stop', {'taskId': taskId});
    }
  }

  Future<bool> sendTextMessage({required int taskId, required String content, int? replyToId}) async {
    final completer = Completer<bool>();
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emitWithAck(
        'message:send',
        {'taskId': taskId, 'content': content, 'replyToId': replyToId},
        ack: (ack) {
          if (ack is Map && ack['ok'] == true) {
            completer.complete(true);
          } else {
            completer.complete(false);
          }
        },
      );
    } else {
      completer.complete(false);
    }
    return completer.future;
  }

  Future<bool> sendImageMessage({required int taskId, required String imageUrl, int? replyToId}) async {
    final completer = Completer<bool>();
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emitWithAck(
        'message:image',
        {'taskId': taskId, 'imageUrl': imageUrl, 'replyToId': replyToId},
        ack: (ack) {
          if (ack is Map && ack['ok'] == true) {
            completer.complete(true);
          } else {
            completer.complete(false);
          }
        },
      );
    } else {
      completer.complete(false);
    }
    return completer.future;
  }

  Future<bool> editMessage({required int taskId, required int messageId, required String content}) async {
    final completer = Completer<bool>();
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emitWithAck(
        'message:edit',
        {'taskId': taskId, 'messageId': messageId, 'content': content},
        ack: (ack) {
          if (ack is Map && ack['ok'] == true) {
            completer.complete(true);
          } else {
            completer.complete(false);
          }
        },
      );
    } else {
      completer.complete(false);
    }
    return completer.future;
  }

  Future<bool> deleteMessage({required int taskId, required int messageId}) async {
    final completer = Completer<bool>();
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emitWithAck(
        'message:delete',
        {'taskId': taskId, 'messageId': messageId},
        ack: (ack) {
          if (ack is Map && ack['ok'] == true) {
            completer.complete(true);
          } else {
            completer.complete(false);
          }
        },
      );
    } else {
      completer.complete(false);
    }
    return completer.future;
  }

  void disconnect() {
    _presenceSocket?.disconnect();
    _presenceSocket?.dispose();
    _presenceSocket = null;

    _chatSocket?.disconnect();
    _chatSocket?.dispose();
    _chatSocket = null;

    _presenceSessionId = null;
  }
}
