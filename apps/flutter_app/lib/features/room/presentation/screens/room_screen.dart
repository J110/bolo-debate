import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bolo_debate/core/constants/app_constants.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/core/services/livekit_service.dart';
import 'package:bolo_debate/core/services/api_service.dart';
import 'package:bolo_debate/features/auth/presentation/providers/auth_provider.dart';
import 'package:bolo_debate/features/room/presentation/providers/room_provider.dart';
import 'package:bolo_debate/shared/models/room_model.dart';
import 'package:bolo_debate/shared/widgets/orbital_visualizer.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? selectedSide;

  const RoomScreen({super.key, required this.roomId, this.selectedSide});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  final List<_FloatingReaction> _floatingReactions = [];
  
  // LiveKit service for audio
  final LiveKitService _liveKitService = LiveKitService();
  bool _isLiveKitConnected = false;
  double _currentAudioLevel = 0.0;
  List<double> _frequencyBands = List.filled(20, 0.0);
  
  ParticipantSide _getSelectedSide() {
    switch (widget.selectedSide) {
      case 'A':
        return ParticipantSide.a;
      case 'B':
        return ParticipantSide.b;
      default:
        return ParticipantSide.neutral;
    }
  }

  @override
  void initState() {
    super.initState();
    // Start timer for time remaining
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    
    // Listen for audio level changes from LiveKit
    _liveKitService.onAudioLevelChanged = (level) {
      if (mounted) {
        setState(() {
          _currentAudioLevel = level;
        });
      }
    };
    
    // Listen for frequency data changes from LiveKit
    _liveKitService.onFrequencyDataChanged = (bands) {
      if (mounted) {
        setState(() {
          _frequencyBands = bands;
        });
      }
    };
    
    // Listen for LiveKit state changes
    _liveKitService.addListener(_onLiveKitUpdate);
    
    // Auto-join room after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoom();
    });
  }
  
  void _onLiveKitUpdate() {
    if (mounted) {
      setState(() {
        _isLiveKitConnected = _liveKitService.isConnected;
        _currentAudioLevel = _liveKitService.audioLevel;
        _frequencyBands = _liveKitService.frequencyBands;
      });
    }
  }
  
  Future<void> _joinRoom() async {
    // First join via API
    await ref.read(liveRoomProvider(widget.roomId).notifier).joinRoom(widget.selectedSide);
    
    // Then connect to LiveKit
    await _connectToLiveKit();
  }
  
  Future<void> _connectToLiveKit() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getRoomToken(widget.roomId);
      
      if (response['success'] == true && response['data'] != null) {
        final token = response['data']['token'] as String;
        final connected = await _liveKitService.connect(token, widget.roomId);
        
        if (mounted) {
          setState(() {
            _isLiveKitConnected = connected;
          });
        }
        
        if (connected) {
          print('✅ LiveKit connected successfully');
        }
      }
    } catch (e) {
      print('❌ Failed to connect to LiveKit: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    _liveKitService.removeListener(_onLiveKitUpdate);
    _liveKitService.disconnect();
    _liveKitService.dispose();
    super.dispose();
  }

  void _shareRoom() {
    final roomState = ref.read(liveRoomProvider(widget.roomId));
    final room = roomState.room;
    if (room == null) return;

    final shareUrl = 'https://bolo-debate.vercel.app/room/${widget.roomId}';
    final shareText = '''🎙️ Join the debate on Bolo!

📢 "${room.title}"

${room.sideALabel} vs ${room.sideBLabel}

Join now and voice your opinion! 👇
$shareUrl''';

    Share.share(shareText, subject: 'Join my debate on Bolo!');
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(liveRoomProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider);

    return WillPopScope(
      onWillPop: () async {
        _showLeaveDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              roomState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : roomState.room == null
                      ? const Center(child: Text('Room not found', style: TextStyle(color: Colors.white)))
                      : Column(
                          children: [
                            // Header
                            _buildHeader(roomState.room!),
                            
                            // Orbital Audio Visualizer - prominent, meditative design
                            Center(
                              child: OrbitalVisualizer(
                                isActive: _isLiveKitConnected,
                                frequencyBands: _frequencyBands,
                                size: 200,
                              ),
                            ),
                            
                            // Audio connection status
                            if (!_isLiveKitConnected)
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: _liveKitService.isConnecting
                                          ? const CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.orange,
                                            )
                                          : const Icon(Icons.wifi_off, size: 12, color: Colors.orange),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _liveKitService.isConnecting 
                                          ? 'Connecting to audio...' 
                                          : 'Audio unavailable - chat only',
                                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // Participants grid
                            Expanded(
                              child: _buildParticipantsArea(roomState),
                            ),
                            
                            // Chat section
                            _buildChatSection(roomState),
                            
                            // Bottom controls
                            _buildBottomControls(roomState, currentUser?.id),
                          ],
                        ),
              // Floating reactions overlay
              ..._floatingReactions.map((reaction) => _FloatingReactionWidget(
                key: ValueKey(reaction.id),
                emoji: reaction.emoji,
                startX: reaction.startX,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Room room) {
    final timeRemaining = room.timeRemaining;
    final currentUser = ref.watch(currentUserProvider);
    final isHost = room.host?.id == currentUser?.id;
    final canClaimHost = room.isAiHosted && room.host == null;
    
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _showLeaveDialog,
              ),
              Expanded(
                child: Column(
                  children: [
                    // Room title - allow multiple lines
                    Text(
                      room.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (timeRemaining != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: timeRemaining.inMinutes < 5 ? AppColors.warning : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        // Host indicator (for current user)
                        if (isHost) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: AppColors.primary, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Show host info (visible to everyone)
                    const SizedBox(height: 4),
                    if (room.host != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber.withOpacity(0.8),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Hosted by ${room.host!.displayName}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    else if (room.isAiHosted)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.smart_toy,
                            color: Colors.cyan.withOpacity(0.8),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI Hosted • Claim to become host',
                            style: TextStyle(
                              color: Colors.cyan.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Claim Host button (visible if AI-hosted and no host)
              if (canClaimHost)
                TextButton.icon(
                  onPressed: () {
                    ref.read(liveRoomProvider(widget.roomId).notifier).claimHost();
                  },
                  icon: const Icon(Icons.person_add, color: AppColors.warning, size: 18),
                  label: const Text('Claim Host', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: AppColors.warning.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showOptionsMenu(room),
                ),
            ],
          ),
          
          // Sides indicator for debates
          if (room.isDebate && room.sideALabel != null && room.sideBLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sideA.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.sideALabel!,
                        style: const TextStyle(
                          color: AppColors.sideA,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sideB.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.sideBLabel!,
                        style: const TextStyle(
                          color: AppColors.sideB,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsArea(LiveRoomState state) {
    final room = state.room;
    final currentUser = ref.watch(currentUserProvider);
    
    // Build participants list, adding current user if not already present
    List<RoomParticipant> participants = [...state.participants];
    
    // Add current user if joined and not in list
    if (state.isJoined && currentUser != null) {
      final userInList = participants.any((p) => p.user.id == currentUser.id);
      if (!userInList) {
        // Get the side from route extra or default to neutral
        final selectedSide = _getSelectedSide();
        participants.insert(0, RoomParticipant(
          id: 'current-user',
          user: currentUser,
          side: selectedSide,
          role: selectedSide == ParticipantSide.neutral ? ParticipantRole.listener : ParticipantRole.speaker,
          handRaised: state.handRaised,
          isMuted: state.isMuted,
          joinedAt: DateTime.now(),
        ));
      }
    }
    
    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for participants...',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Split participants by side
    final sideA = participants.where((p) => p.side == ParticipantSide.a).toList();
    final sideB = participants.where((p) => p.side == ParticipantSide.b).toList();
    final neutral = participants.where((p) => p.side == ParticipantSide.neutral).toList();

    if (room?.isDebate == true) {
      return Row(
        children: [
          // Side A Column
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sideA.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sideA.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      room?.sideALabel ?? 'Side A',
                      style: const TextStyle(
                        color: AppColors.sideA,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: sideA.isEmpty
                        ? const Center(
                            child: Text('No participants', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          )
                        : _buildParticipantGrid(sideA),
                  ),
                ],
              ),
            ),
          ),
          // Side B Column
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sideB.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sideB.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      room?.sideBLabel ?? 'Side B',
                      style: const TextStyle(
                        color: AppColors.sideB,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: sideB.isEmpty
                        ? const Center(
                            child: Text('No participants', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          )
                        : _buildParticipantGrid(sideB),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Non-debate room - show all participants in grid
    return _buildParticipantGrid([...sideA, ...sideB, ...neutral]);
  }

  Widget _buildParticipantGrid(List<RoomParticipant> participants) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return _ParticipantTile(participant: participants[index]);
      },
    );
  }

  Widget _buildChatSection(LiveRoomState state) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final message = state.messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),
          // Message input
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(LiveRoomState state, String? currentUserId) {
    // Use LiveKit state for mute if connected, otherwise fallback to state
    final isMuted = _isLiveKitConnected ? _liveKitService.isMuted : state.isMuted;
    final currentUser = ref.watch(currentUserProvider);
    final isHost = state.room?.host?.id == currentUser?.id;
    
    // Can only unmute if: 1) is host, OR 2) hand is raised
    final canSpeak = isHost || state.handRaised;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button - disabled if not allowed to speak
          _ControlButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            label: isMuted 
                ? (canSpeak ? 'Unmute' : 'Raise Hand') 
                : 'Mute',
            color: isMuted 
                ? (canSpeak ? Colors.red : Colors.grey) 
                : Colors.green,
            onTap: canSpeak || !isMuted
                ? () {
                    if (isMuted && !canSpeak) {
                      // Show hint to raise hand first
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Raise your hand first to request to speak'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    
                    // Toggle LiveKit audio
                    if (_isLiveKitConnected) {
                      _liveKitService.toggleMicrophone().then((success) {
                        if (!success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_liveKitService.error ?? 'Failed to enable microphone'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      });
                    } else {
                      // LiveKit not connected - try to reconnect
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connecting to audio server...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      _connectToLiveKit();
                    }
                    // Also update backend state
                    ref.read(liveRoomProvider(widget.roomId).notifier).toggleMute(!isMuted);
                    setState(() {});
                  }
                : null,
          ),
          
          // Hand raise button (not needed for hosts)
          if (!isHost)
            _ControlButton(
              icon: state.handRaised ? Icons.front_hand : Icons.front_hand_outlined,
              label: state.handRaised ? 'Lower' : 'Raise',
              color: state.handRaised ? AppColors.warning : Colors.white,
              onTap: () {
                final newRaised = !state.handRaised;
                
                // If lowering hand, also mute
                if (!newRaised && !isMuted) {
                  if (_isLiveKitConnected) {
                    _liveKitService.disableMicrophone();
                  }
                  ref.read(liveRoomProvider(widget.roomId).notifier).toggleMute(true);
                }
                
                ref.read(liveRoomProvider(widget.roomId).notifier).raiseHand(newRaised);
                setState(() {});
              },
            )
          else
            // Show host indicator instead of hand raise
            _ControlButton(
              icon: Icons.star,
              label: 'Host',
              color: AppColors.primary,
              onTap: null, // Not clickable, just informational
            ),
          
          // Reactions button
          _ControlButton(
            icon: Icons.emoji_emotions_outlined,
            label: 'React',
            onTap: () => _showReactionsSheet(),
          ),
          
          // Leave button
          _ControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            color: AppColors.error,
            onTap: _showLeaveDialog,
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    final currentUser = ref.read(currentUserProvider);
    if (content.isNotEmpty) {
      ref.read(liveRoomProvider(widget.roomId).notifier).sendMessage(
        content, 
        currentUser: currentUser,
      );
      _messageController.clear();
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showReactionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: AppConstants.reactions.map((emoji) {
              return GestureDetector(
                onTap: () {
                  _addFloatingReaction(emoji);
                  ref.read(liveRoomProvider(widget.roomId).notifier).sendReaction(emoji);
                  Navigator.pop(context);
                },
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              );
            }).toList(),
          ),
        );
      },
    );
  }
  
  void _addFloatingReaction(String emoji) {
    final reaction = _FloatingReaction(
      emoji: emoji,
      id: DateTime.now().millisecondsSinceEpoch,
      startX: 50 + (DateTime.now().millisecond % 200).toDouble(),
    );
    setState(() {
      _floatingReactions.add(reaction);
    });
    // Remove after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _floatingReactions.removeWhere((r) => r.id == reaction.id);
        });
      }
    });
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Room?'),
        content: const Text('Are you sure you want to leave this room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              // Disconnect LiveKit
              await _liveKitService.disconnect();
              // Leave room via API
              ref.read(liveRoomProvider(widget.roomId).notifier).leaveRoom();
              Navigator.pop(context);
              context.go('/home');
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(Room room) {
    final currentUser = ref.read(currentUserProvider);
    final isHost = room.host?.id == currentUser?.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isHost) ...[
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('Extend time (+5 min)', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '${3 - room.extensionsUsed} extensions remaining',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  enabled: room.canExtend,
                  onTap: room.canExtend
                      ? () {
                          ref.read(liveRoomProvider(widget.roomId).notifier).extendRoom();
                          Navigator.pop(context);
                        }
                      : null,
                ),
                const Divider(color: Colors.white24),
              ],
              if (room.isAiHosted && room.host == null) ...[
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.white),
                  title: const Text('Claim Host', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    ref.read(liveRoomProvider(widget.roomId).notifier).claimHost();
                    Navigator.pop(context);
                  },
                ),
                const Divider(color: Colors.white24),
              ],
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Share Room', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _shareRoom();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.white),
                title: const Text('Report Issue', style: TextStyle(color: Colors.white)),
                onTap: () {
                  // TODO: Report
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final RoomParticipant participant;

  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white24;
    Color backgroundColor = AppColors.primary.withOpacity(0.2);
    
    if (participant.side == ParticipantSide.a) {
      borderColor = AppColors.sideA;
      backgroundColor = AppColors.sideA.withOpacity(0.2);
    } else if (participant.side == ParticipantSide.b) {
      borderColor = AppColors.sideB;
      backgroundColor = AppColors.sideB.withOpacity(0.2);
    }

    // Add glow effect when speaking (not muted)
    final isSpeaking = !participant.isMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Outer glow when speaking
            if (isSpeaking)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            // Main avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 3),
                color: backgroundColor,
                gradient: RadialGradient(
                  colors: [
                    backgroundColor,
                    backgroundColor.withOpacity(0.5),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  participant.user.displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: borderColor == Colors.white24 ? AppColors.primary : borderColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            // Host badge
            if (participant.isHost)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.backgroundDark, width: 2),
                  ),
                  child: const Icon(Icons.star, size: 10, color: Colors.white),
                ),
              ),
            // Hand raised badge
            if (participant.handRaised)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.backgroundDark, width: 2),
                  ),
                  child: const Text('✋', style: TextStyle(fontSize: 10)),
                ),
              ),
            // Mic status badge
            Positioned(
              bottom: -2,
              left: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: participant.isMuted ? Colors.red : Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.backgroundDark, width: 2),
                ),
                child: Icon(
                  participant.isMuted ? Icons.mic_off : Icons.mic,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          participant.user.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isBot)
            const Icon(Icons.smart_toy, size: 16, color: AppColors.info)
          else
            CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.primary.withOpacity(0.3),
              child: Text(
                message.user.displayName[0],
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isBot ? 'Bolo Bot' : message.user.displayName,
                  style: TextStyle(
                    color: message.isBot ? AppColors.info : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  message.content,
                  style: TextStyle(
                    color: message.isBot ? AppColors.info.withOpacity(0.8) : Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (color ?? Colors.white).withOpacity(0.1),
            ),
            child: Icon(icon, color: color ?? Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Floating reaction data class
class _FloatingReaction {
  final String emoji;
  final int id;
  final double startX;
  
  _FloatingReaction({required this.emoji, required this.id, required this.startX});
}

// Floating reaction animation widget
class _FloatingReactionWidget extends StatefulWidget {
  final String emoji;
  final double startX;
  
  const _FloatingReactionWidget({super.key, required this.emoji, required this.startX});
  
  @override
  State<_FloatingReactionWidget> createState() => _FloatingReactionWidgetState();
}

class _FloatingReactionWidgetState extends State<_FloatingReactionWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _positionAnimation = Tween<double>(begin: 0, end: 400).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: 150 + _positionAnimation.value,
          left: widget.startX + (math.sin(_positionAnimation.value / 50) * 30),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                widget.emoji,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
        );
      },
    );
  }
}
