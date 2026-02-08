import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bolo_debate/core/constants/app_constants.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/auth/presentation/providers/auth_provider.dart';
import 'package:bolo_debate/features/room/presentation/providers/room_provider.dart';
import 'package:bolo_debate/shared/models/room_model.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start timer for time remaining
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
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
          child: roomState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : roomState.room == null
                  ? const Center(child: Text('Room not found', style: TextStyle(color: Colors.white)))
                  : Column(
                      children: [
                        // Header
                        _buildHeader(roomState.room!),
                        
                        // Audio Visualizer
                        _AudioVisualizer(),
                        
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
        ),
      ),
    );
  }

  Widget _buildHeader(Room room) {
    final timeRemaining = room.timeRemaining;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _showLeaveDialog,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      room.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
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
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => _showOptionsMenu(room),
              ),
            ],
          ),
          
          // Sides indicator for debates
          if (room.isDebate && room.sideALabel != null && room.sideBLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sideA.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.sideALabel!,
                        style: const TextStyle(
                          color: AppColors.sideA,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sideB.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.sideBLabel!,
                        style: const TextStyle(
                          color: AppColors.sideB,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
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
    final participants = state.participants;
    final room = state.room;
    
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
      height: 150,
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _ControlButton(
            icon: state.isMuted ? Icons.mic_off : Icons.mic,
            label: state.isMuted ? 'Unmute' : 'Mute',
            color: state.isMuted ? Colors.red : Colors.green,
            onTap: () {
              ref.read(liveRoomProvider(widget.roomId).notifier).toggleMute(!state.isMuted);
            },
          ),
          
          // Hand raise button
          _ControlButton(
            icon: state.handRaised ? Icons.front_hand : Icons.front_hand_outlined,
            label: state.handRaised ? 'Lower' : 'Raise',
            color: state.handRaised ? AppColors.warning : Colors.white,
            onTap: () {
              ref.read(liveRoomProvider(widget.roomId).notifier).raiseHand(!state.handRaised);
            },
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
            onPressed: () {
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
                  // TODO: Share
                  Navigator.pop(context);
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
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
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

// Audio Visualizer Widget
class _AudioVisualizer extends StatefulWidget {
  @override
  State<_AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<_AudioVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = List.generate(20, (_) => 0.3);
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..repeat();
    _controller.addListener(_updateBars);
  }
  
  void _updateBars() {
    if (mounted) {
      setState(() {
        for (int i = 0; i < _barHeights.length; i++) {
          // Simulate audio levels - in real implementation, this would use actual audio data
          _barHeights[i] = 0.1 + (0.9 * _pseudoRandom(i + DateTime.now().millisecond));
        }
      });
    }
  }
  
  double _pseudoRandom(int seed) {
    // Simple pseudo-random for animation effect
    return ((seed * 1103515245 + 12345) % 100) / 100.0;
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_barHeights.length, (index) {
          // Create gradient colors from cyan to purple
          final hue = 180 + (index * 10);
          final color = HSLColor.fromAHSL(1.0, hue.toDouble() % 360, 0.8, 0.6).toColor();
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 10 + (_barHeights[index] * 35),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  color.withOpacity(0.5),
                  color,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
