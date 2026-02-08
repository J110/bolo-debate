import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bolo_debate/core/services/api_service.dart';
import 'package:bolo_debate/core/services/websocket_service.dart';
import 'package:bolo_debate/shared/models/room_model.dart';
import 'package:bolo_debate/shared/models/user_model.dart';

// Room state for live room
class LiveRoomState {
  final Room? room;
  final List<RoomParticipant> participants;
  final List<ChatMessage> messages;
  final bool isJoined;
  final bool isLoading;
  final String? error;
  final String? livekitToken;
  final bool handRaised;
  final bool isMuted;

  const LiveRoomState({
    this.room,
    this.participants = const [],
    this.messages = const [],
    this.isJoined = false,
    this.isLoading = false,
    this.error,
    this.livekitToken,
    this.handRaised = false,
    this.isMuted = true,
  });

  LiveRoomState copyWith({
    Room? room,
    List<RoomParticipant>? participants,
    List<ChatMessage>? messages,
    bool? isJoined,
    bool? isLoading,
    String? error,
    String? livekitToken,
    bool? handRaised,
    bool? isMuted,
  }) {
    return LiveRoomState(
      room: room ?? this.room,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      isJoined: isJoined ?? this.isJoined,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      livekitToken: livekitToken ?? this.livekitToken,
      handRaised: handRaised ?? this.handRaised,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

class LiveRoomNotifier extends StateNotifier<LiveRoomState> {
  final String roomId;
  final ApiService _api;
  final WebSocketService _ws;
  StreamSubscription? _wsSubscription;

  LiveRoomNotifier(this.roomId, this._api, this._ws) : super(const LiveRoomState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Load room details
      final response = await _api.getRoom(roomId);
      if (response['success'] == true) {
        final room = Room.fromJson(response['data']);
        final participants = (response['data']['participants'] as List?)
            ?.map((p) => RoomParticipant.fromJson(p))
            .toList() ?? [];
        
        state = state.copyWith(
          room: room,
          participants: participants,
          isLoading: false,
        );
      }

      // Load messages
      final messagesResponse = await _api.getMessages(roomId);
      if (messagesResponse['success'] == true) {
        final messages = (messagesResponse['data'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .toList();
        state = state.copyWith(messages: messages);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> joinRoom(String? side) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _api.joinRoom(roomId, side: side, pledgeAccepted: true);
      
      if (response['success'] == true) {
        // Connect to WebSocket
        _ws.connect();
        _ws.joinRoom(roomId);
        
        // Listen for WebSocket messages
        _wsSubscription = _ws.messageStream.listen(_handleWsMessage);

        // Get LiveKit token if room is live
        if (state.room?.isLive == true) {
          final tokenResponse = await _api.getRoomToken(roomId);
          if (tokenResponse['success'] == true) {
            state = state.copyWith(
              isJoined: true,
              isLoading: false,
              livekitToken: tokenResponse['data']['token'],
            );
            return;
          }
        }
        
        state = state.copyWith(isJoined: true, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response['error']);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> leaveRoom() async {
    try {
      await _api.leaveRoom(roomId);
      _ws.leaveRoom();
      _wsSubscription?.cancel();
      state = state.copyWith(isJoined: false, livekitToken: null);
    } catch (e) {
      // Ignore errors on leave
    }
  }

  Future<void> raiseHand(bool raised) async {
    try {
      await _api.raiseHand(roomId, raised);
      state = state.copyWith(handRaised: raised);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleMute(bool muted) async {
    try {
      await _api.toggleMute(roomId, muted);
      state = state.copyWith(isMuted: muted);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> sendMessage(String content, {User? currentUser}) async {
    try {
      // Optimistically add message immediately
      if (currentUser != null) {
        final tempMessage = ChatMessage(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          user: currentUser,
          content: content,
          isBot: false,
          createdAt: DateTime.now(),
        );
        state = state.copyWith(
          messages: [...state.messages, tempMessage],
        );
      }
      await _api.sendMessage(roomId, content);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> sendReaction(String emoji) async {
    try {
      await _api.sendReaction(roomId, emoji);
    } catch (e) {
      // Ignore reaction errors
    }
  }

  Future<void> extendRoom() async {
    try {
      final response = await _api.extendRoom(roomId);
      if (response['success'] == true) {
        // Room update will come via WebSocket
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> claimHost() async {
    try {
      final response = await _api.claimHost(roomId);
      if (response['success'] == true && response['data'] != null) {
        // Immediately update room state with new host info
        final roomData = response['data'] as Map<String, dynamic>;
        User? newHost;
        if (roomData['host'] != null) {
          final hostData = roomData['host'] as Map<String, dynamic>;
          newHost = User(
            id: hostData['id'] as String,
            username: hostData['username'] as String,
            displayName: hostData['displayName'] as String,
            avatarUrl: hostData['avatarUrl'] as String?,
            createdAt: DateTime.now(),
          );
        }
        
        if (state.room != null && newHost != null) {
          state = state.copyWith(
            room: state.room!.copyWith(
              host: newHost,
              isAiHosted: false,
            ),
          );
        }
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> kickParticipant(String oderId) async {
    try {
      await _api.kickParticipant(roomId, oderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _handleWsMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    
    switch (type) {
      case 'participant:joined':
        final participant = RoomParticipant.fromJson(message['payload']);
        state = state.copyWith(
          participants: [...state.participants, participant],
        );
        break;
        
      case 'participant:left':
        final oderId = message['payload']['oderId'] as String;
        state = state.copyWith(
          participants: state.participants.where((p) => p.user.id != oderId).toList(),
        );
        break;
        
      case 'message:new':
        final chatMessage = ChatMessage.fromJson(message['payload']);
        state = state.copyWith(
          messages: [...state.messages, chatMessage],
        );
        break;
        
      case 'ai:suggestion':
        final botMessage = ChatMessage(
          id: message['payload']['id'],
          user: User(
            id: 'bot',
            username: 'bolo_bot',
            displayName: 'Bolo Bot',
            createdAt: DateTime.now(),
          ),
          content: message['payload']['content'],
          isBot: true,
          createdAt: DateTime.parse(message['payload']['createdAt']),
        );
        state = state.copyWith(
          messages: [...state.messages, botMessage],
        );
        break;
        
      case 'room:update':
        // Handle room updates (host, status, endsAt, etc.)
        final payload = message['payload'] as Map<String, dynamic>?;
        if (payload != null && state.room != null) {
          User? newHost;
          if (payload['host'] != null) {
            final hostData = payload['host'] as Map<String, dynamic>;
            newHost = User(
              id: hostData['id'] as String,
              username: hostData['username'] as String,
              displayName: hostData['displayName'] as String,
              avatarUrl: hostData['avatarUrl'] as String?,
              createdAt: DateTime.now(),
            );
          }
          
          state = state.copyWith(
            room: state.room!.copyWith(
              host: newHost ?? state.room!.host,
              isAiHosted: payload['isAiHosted'] as bool? ?? state.room!.isAiHosted,
            ),
          );
        }
        break;
        
      case 'room:ended':
        state = state.copyWith(
          room: state.room?.copyWith(status: RoomStatus.ended),
          isJoined: false,
        );
        break;
        
      case 'hand:raised':
      case 'hand:lowered':
        final oderId = message['payload']['oderId'] as String;
        final raised = type == 'hand:raised';
        state = state.copyWith(
          participants: state.participants.map((p) {
            if (p.user.id == oderId) {
              return RoomParticipant(
                id: p.id,
                user: p.user,
                side: p.side,
                role: p.role,
                handRaised: raised,
                isMuted: p.isMuted,
                joinedAt: p.joinedAt,
              );
            }
            return p;
          }).toList(),
        );
        break;
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _ws.leaveRoom();
    super.dispose();
  }
}

// Extension to add copyWith to Room
extension RoomCopyWith on Room {
  Room copyWith({
    String? id,
    String? title,
    String? description,
    User? host,
    Region? region,
    Category? category,
    RoomType? type,
    String? sideALabel,
    String? sideBLabel,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endsAt,
    int? extensionsUsed,
    RoomStatus? status,
    bool? isAiHosted,
    int? participantCount,
    int? sideACount,
    int? sideBCount,
  }) {
    return Room(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      host: host ?? this.host,
      region: region ?? this.region,
      category: category ?? this.category,
      type: type ?? this.type,
      sideALabel: sideALabel ?? this.sideALabel,
      sideBLabel: sideBLabel ?? this.sideBLabel,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endsAt: endsAt ?? this.endsAt,
      extensionsUsed: extensionsUsed ?? this.extensionsUsed,
      status: status ?? this.status,
      isAiHosted: isAiHosted ?? this.isAiHosted,
      participantCount: participantCount ?? this.participantCount,
      sideACount: sideACount ?? this.sideACount,
      sideBCount: sideBCount ?? this.sideBCount,
    );
  }
}

// Provider factory for live room
final liveRoomProvider = StateNotifierProvider.family<LiveRoomNotifier, LiveRoomState, String>(
  (ref, roomId) {
    return LiveRoomNotifier(
      roomId,
      ref.watch(apiServiceProvider),
      ref.watch(websocketServiceProvider),
    );
  },
);
