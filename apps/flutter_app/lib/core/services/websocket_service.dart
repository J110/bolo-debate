import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:bolo_debate/core/constants/app_constants.dart';

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  String? _currentRoomId;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _isConnected = false;
  StreamSubscription? _subscription;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;

    try {
      final wsUrl = AppConstants.wsUrl.endsWith('/ws') 
          ? AppConstants.wsUrl 
          : '${AppConstants.wsUrl}/ws';
      
      print('Connecting to WebSocket: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _isConnected = true;
      _isConnecting = false;
      print('WebSocket connected');

      // Rejoin room if we were in one
      if (_currentRoomId != null) {
        joinRoom(_currentRoomId!);
      }

      // Start ping timer to keep connection alive
      _startPingTimer();
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      if (type == 'pong') {
        // Ping response, connection is alive
        return;
      }

      if (type != null) {
        _messageController.add({
          'type': type,
          'payload': data['payload'],
          'roomId': data['roomId'],
          'timestamp': data['timestamp'],
        });
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  void _onError(dynamic error) {
    print('WebSocket error: $error');
    _handleDisconnect();
  }

  void _onDone() {
    print('WebSocket connection closed');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _stopPingTimer();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      print('Attempting to reconnect WebSocket...');
      connect();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _sendRaw({'type': 'ping'});
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _sendRaw(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        print('Error sending WebSocket message: $e');
      }
    }
  }

  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    _sendRaw({'type': 'join_room', 'roomId': roomId});
  }

  void leaveRoom() {
    if (_currentRoomId != null) {
      _sendRaw({'type': 'leave_room', 'roomId': _currentRoomId});
      _currentRoomId = null;
    }
  }

  void sendMessage(String roomId, String content) {
    _sendRaw({
      'type': 'send_message',
      'roomId': roomId,
      'content': content,
    });
  }

  void sendReaction(String roomId, String emoji) {
    _sendRaw({
      'type': 'send_reaction',
      'roomId': roomId,
      'emoji': emoji,
    });
  }

  void disconnect() {
    _currentRoomId = null;
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
