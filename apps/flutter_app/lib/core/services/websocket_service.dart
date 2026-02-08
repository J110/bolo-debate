import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:bolo_debate/core/constants/app_constants.dart';

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  io.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  String? _currentRoomId;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      AppConstants.wsUrl.replaceFirst('ws://', 'http://'),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('WebSocket connected');
      // Rejoin room if we were in one
      if (_currentRoomId != null) {
        joinRoom(_currentRoomId!);
      }
    });

    _socket!.onDisconnect((_) {
      print('WebSocket disconnected');
    });

    _socket!.onError((error) {
      print('WebSocket error: $error');
    });

    // Listen for all room events
    _socket!.on('room:joined', (data) => _handleMessage('room:joined', data));
    _socket!.on('room:update', (data) => _handleMessage('room:update', data));
    _socket!.on('participant:joined', (data) => _handleMessage('participant:joined', data));
    _socket!.on('participant:left', (data) => _handleMessage('participant:left', data));
    _socket!.on('participant:updated', (data) => _handleMessage('participant:updated', data));
    _socket!.on('message:new', (data) => _handleMessage('message:new', data));
    _socket!.on('reaction:new', (data) => _handleMessage('reaction:new', data));
    _socket!.on('hand:raised', (data) => _handleMessage('hand:raised', data));
    _socket!.on('hand:lowered', (data) => _handleMessage('hand:lowered', data));
    _socket!.on('speaker:changed', (data) => _handleMessage('speaker:changed', data));
    _socket!.on('ai:suggestion', (data) => _handleMessage('ai:suggestion', data));
    _socket!.on('room:ending_soon', (data) => _handleMessage('room:ending_soon', data));
    _socket!.on('room:ended', (data) => _handleMessage('room:ended', data));

    _socket!.connect();
  }

  void _handleMessage(String type, dynamic data) {
    try {
      final message = data is String ? jsonDecode(data) : data;
      _messageController.add({
        'type': type,
        ...message as Map<String, dynamic>,
      });
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    _socket?.emit('join_room', {'roomId': roomId});
  }

  void leaveRoom() {
    if (_currentRoomId != null) {
      _socket?.emit('leave_room', {'roomId': _currentRoomId});
      _currentRoomId = null;
    }
  }

  void sendMessage(String roomId, String content) {
    _socket?.emit('send_message', {
      'roomId': roomId,
      'content': content,
    });
  }

  void sendReaction(String roomId, String emoji) {
    _socket?.emit('send_reaction', {
      'roomId': roomId,
      'emoji': emoji,
    });
  }

  void disconnect() {
    _currentRoomId = null;
    _socket?.disconnect();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
