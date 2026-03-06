import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bolo_debate/core/constants/app_constants.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/core/services/livekit_service.dart';
import 'package:bolo_debate/core/services/api_service.dart';
import 'package:bolo_debate/features/auth/presentation/providers/auth_provider.dart';
import 'package:bolo_debate/features/room/presentation/providers/room_provider.dart';
import 'package:bolo_debate/shared/models/room_model.dart';
import 'package:bolo_debate/shared/widgets/orbital_visualizer.dart';
import 'package:bolo_debate/shared/widgets/live_indicator.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? selectedSide;

  const RoomScreen({super.key, required this.roomId, this.selectedSide});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  static const MethodChannel _nativeShareChannel = MethodChannel('bolo/native_share');
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  final List<_FloatingReaction> _floatingReactions = [];
  
  // LiveKit service for audio
  final LiveKitService _liveKitService = LiveKitService();
  bool _isLiveKitConnected = false;
  double _currentAudioLevel = 0.0;
  List<double> _frequencyBands = List.filled(20, 0.0);
  // Measured height of the bottom controls so the input overlay can sit above it.
  final GlobalKey _bottomControlsKey = GlobalKey();
  double _bottomControlsHeight = 72.0;
  // Estimated height of the input overlay (used for list padding).
  final double _inputOverlayHeight = 48.0;
  // Keys for message widgets so we can ensureVisible the newly-added message
  final Map<String, GlobalKey> _messageKeys = {};
  
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
        final url = response['data']['url'] as String?; // Get LiveKit URL from API
        final connected = await _liveKitService.connect(token, widget.roomId, url: url);
        
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

  Future<void> _shareRoom() async {
    final roomState = ref.read(liveRoomProvider(widget.roomId));
    final room = roomState.room;
    if (room == null) return;

    final shareUrl = 'https://bolaa.app/#/room/${widget.roomId}';
    final hasSides = (room.sideALabel?.trim().isNotEmpty ?? false) &&
        (room.sideBLabel?.trim().isNotEmpty ?? false);
    final sidesLine = hasSides ? '\n${room.sideALabel} vs ${room.sideBLabel}\n' : '\n';
    final shareText = '''🎙️ Join the debate on Bolaa!

📢 "${room.title}"
$sidesLine

Join now and voice your opinion! 👇
$shareUrl''';
    final isApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isApple) {
      try {
        await _nativeShareChannel.invokeMethod('shareText', {
          'text': shareText,
          'subject': 'Join my debate on Bolaa!',
        });
      } catch (e) {
        // Last-resort fallback
        await Clipboard.setData(ClipboardData(text: shareText));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed, invite copied instead: $e')),
          );
        }
      }
      return;
    }

    try {
      // Deterministic non-zero origin always inside current screen bounds.
      // This avoids iOS zero-rect errors from transient/disposed render boxes.
      final size = MediaQuery.of(context).size;
      final safeOrigin = Rect.fromLTWH(
        (size.width / 2).clamp(1.0, size.width - 1),
        (size.height / 2).clamp(1.0, size.height - 1),
        1,
        1,
      );

      await Share.share(
        shareText,
        subject: 'Join my debate on Bolaa!',
        sharePositionOrigin: safeOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open share sheet: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(liveRoomProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider);
    
    // Debug: log message count to help diagnose missing UI messages
    // (kept lightweight so it only prints in debug runs)
    assert(() {
      // ignore: avoid_print
      print('🔎 [RoomScreen] roomId=${widget.roomId} messages=${roomState.messages.length} participants=${roomState.participants.length}');
      return true;
    }());
    // Measure bottom controls after layout so overlay can position itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _bottomControlsKey.currentContext;
      if (ctx != null) {
        final rawH = ctx.size?.height ?? _bottomControlsHeight;
        // Clamp measured height to reasonable bounds to avoid overlay being pushed off-screen
        final h = rawH.clamp(56.0, 140.0);
        if ((h - _bottomControlsHeight).abs() > 1 && mounted) {
          setState(() {
            _bottomControlsHeight = h;
          });
        }
      }
    });

    return WillPopScope(
      onWillPop: () async {
        _showLeaveDialog();
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
        child: Stack(
          clipBehavior: Clip.hardEdge,
            children: [
              // Main content
              roomState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : roomState.room == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Room not found', style: TextStyle(color: Colors.white, fontSize: 16)),
                              const SizedBox(height: 8),
                              if (roomState.error != null) ...[
                                Text('Error: ${roomState.error}', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 8),
                              ],
                              ElevatedButton(
                                onPressed: () {
                                  // Retry loading provider
                                  ref.invalidate(liveRoomProvider(widget.roomId));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retrying...')));
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Header banner with room illustration
                            _buildHeader(roomState.room!),
                            
                            // Sides indicator for debates
                            _buildSidesIndicator(roomState.room!),
                            const SizedBox(height: 8),
                            
                            // Orbital Audio Visualizer - prominent, meditative design
                            Center(
                              child: OrbitalVisualizer(
                                isActive: _isLiveKitConnected,
                                frequencyBands: _frequencyBands,
                                size: 120,
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
                            
                            // Chat section — show message count header for debugging
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                children: [
                                  Text('Messages: ${roomState.messages.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                            _buildChatSection(roomState),
                            
                            // Bottom controls (measured)
                            Container(key: _bottomControlsKey, child: _buildBottomControls(roomState, currentUser?.id)),
                          ],
                        ),
              // Floating reactions overlay
              ..._floatingReactions.map((reaction) => _FloatingReactionWidget(
                key: ValueKey(reaction.id),
                emoji: reaction.emoji,
                startX: reaction.startX,
              )),
              // Chat input overlay - only show after successfully joined the room
              if (roomState.isJoined) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (MediaQuery.of(context).viewInsets.bottom > 0)
                      ? (MediaQuery.of(context).viewInsets.bottom + 8)
                      : (_bottomControlsHeight + 8),
                  child: SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Builder(builder: (ctx) {
                        final theme = Theme.of(ctx);
                        final bgColor = theme.brightness == Brightness.dark
                            ? AppColors.surfaceDark.withOpacity(0.95)
                            : Colors.white.withOpacity(0.95);
                        final hintColor = theme.brightness == Brightness.dark
                            ? Colors.white38
                            : Colors.black45;
                        final textColor = theme.colorScheme.onSurface;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          height: 56,
                          constraints: const BoxConstraints(maxWidth: 900),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.keyboard_arrow_down, color: hintColor),
                                onPressed: () => FocusScope.of(ctx).unfocus(),
                                splashRadius: 18,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.done,
                                  onEditingComplete: () => FocusScope.of(ctx).unfocus(),
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(color: hintColor),
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                  onPressed: _sendMessage,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
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
    final categoryColor = Color(int.parse(room.category.color.replaceFirst('#', '0xFF')));
    
    // Use room's illustration or fallback to category-based image
    final imageUrl = room.illustrationUrl ?? 
        'https://picsum.photos/seed/${room.category.name.toLowerCase()}1/600/300';
    
    return Container(
      height: 120,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with artistic filter
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              1.5, -0.3, -0.3, 0, -40,
              -0.3, 1.5, -0.3, 0, -40,
              -0.3, -0.3, 1.5, 0, -40,
              0, 0, 0, 1, 0,
            ]),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppColors.error.withOpacity(0.3)),
              errorWidget: (context, url, error) => Container(color: AppColors.error.withOpacity(0.3)),
            ),
          ),
          
          // Color overlay - red tint for live rooms
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.error.withOpacity(0.7),
                  categoryColor.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              backgroundBlendMode: BlendMode.color,
            ),
          ),
          
          // Dark gradient for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Top row with close button, claim host, and menu
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _showLeaveDialog,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    // Claim Host button (visible if AI-hosted and no host)
                    if (canClaimHost)
                      TextButton.icon(
                        onPressed: () {
                          ref.read(liveRoomProvider(widget.roomId).notifier).claimHost();
                        },
                        icon: const Icon(Icons.person_add, color: AppColors.warning, size: 16),
                        label: const Text('Claim Host', style: TextStyle(color: AppColors.warning, fontSize: 11)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          backgroundColor: AppColors.warning.withOpacity(0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () => _showOptionsMenu(room),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                // Title (scale down to avoid overflow on narrow screens)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      room.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // LIVE badge, time, host info
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LiveIndicator(
                      fontSize: 10,
                      dotSize: 6,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    ),
                    if (timeRemaining != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: timeRemaining.inMinutes < 5 ? AppColors.warning : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ],
                    if (isHost) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 12),
                            SizedBox(width: 3),
                            Text('HOST', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Host/AI info
                if (room.host != null && !isHost) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Hosted by ${room.host!.displayName}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                      shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                    ),
                  ),
                ] else if (room.isAiHosted && room.host == null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.smart_toy, color: Colors.cyan.withOpacity(0.9), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'AI Hosted • Claim to become host',
                        style: TextStyle(
                          color: Colors.cyan.withOpacity(0.9),
                          fontSize: 10,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSidesIndicator(Room room) {
    if (!room.isDebate || room.sideALabel == null || room.sideBLabel == null) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    room.sideALabel!,
                    style: const TextStyle(
                      color: AppColors.sideA,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    room.sideBLabel!,
                    style: const TextStyle(
                      color: AppColors.sideB,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
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
    // Make the chat section flexible so it can shrink when vertical space is low.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (state.messages.isEmpty) {
      return Flexible(
        fit: FlexFit.loose,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Center(
            child: Text('No messages yet', style: TextStyle(color: Colors.white54)),
          ),
        ),
      );
    }

    return Flexible(
      fit: FlexFit.loose,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView.builder(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          reverse: true,
          // Ensure last messages are visible above the input overlay and bottom controls.
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            // Cap bottom padding so it doesn't create excessive scrollable area
            math.min(_bottomControlsHeight + _inputOverlayHeight + 16 + bottomInset, MediaQuery.of(context).size.height * 0.45),
          ),
          itemCount: state.messages.length,
          itemBuilder: (context, index) {
            final message = state.messages[state.messages.length - 1 - index];
            final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());
            return KeyedSubtree(key: key, child: _ChatBubble(message: message));
          },
        ),
      ),
    );
  }

  Widget _buildBottomControls(LiveRoomState state, String? currentUserId) {
    // Use LiveKit state for mute if connected, otherwise fallback to state
    final isMuted = _isLiveKitConnected ? _liveKitService.isMuted : state.isMuted;
    final currentUser = ref.watch(currentUserProvider);
    final isHost = state.room?.host?.id == currentUser?.id;
    
    // Can only unmute if: 1. is host, OR 2. hand is raised
    final canSpeak = isHost || state.handRaised;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button - disabled if not allowed to speak
          _ControlButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            // Always allow mute/unmute; default is muted (isMuted == true)
            label: isMuted ? 'Unmute' : 'Mute',
            color: isMuted ? Colors.red : Colors.green,
            onTap: () {
              // Toggle LiveKit audio immediately when possible
              if (_isLiveKitConnected) {
                _liveKitService.toggleMicrophone().then((success) {
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_liveKitService.error ?? 'Failed to toggle microphone'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                });
              } else {
                // Attempt to connect to LiveKit in background, but still update local/backend state
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connecting to audio server...'),
                    duration: Duration(seconds: 2),
                  ),
                );
                _connectToLiveKit();
              }

              // Update backend state and local UI
              ref.read(liveRoomProvider(widget.roomId).notifier).toggleMute(!isMuted);
              setState(() {});
            },
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
      // Close keyboard and scroll to bottom after frame so the new message is visible.
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_scrollController.hasClients) {
          // Wait a short moment for layout to settle, then ensure the newest message widget is visible.
          await Future.delayed(const Duration(milliseconds: 120));
          final roomState = ref.read(liveRoomProvider(widget.roomId));
          if (roomState.messages.isNotEmpty) {
            final newest = roomState.messages.last;
            final key = _messageKeys[newest.id];
                  if (key != null && key.currentContext != null) {
              try {
                await Scrollable.ensureVisible(
                  key.currentContext!,
                  alignment: 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              } catch (_) {
                // Fallback: animate to top (reversed list)
                if (_scrollController.hasClients) {
                  try {
                    _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                  } catch (_) {
                    _scrollController.jumpTo(0.0);
                  }
                }
              }
              } else {
              // No key found yet; fallback to animating to top
              if (_scrollController.hasClients) {
                try {
                  _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                } catch (_) {
                  _scrollController.jumpTo(0.0);
                }
              }
            }
          }
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
                  // Open share sheet after bottom sheet dismiss completes.
                  Future.delayed(const Duration(milliseconds: 220), () async {
                    if (mounted) {
                      try {
                        await _shareRoom();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unable to open share: $e')),
                          );
                        }
                      }
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.white),
                title: const Text('Report Issue', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(room);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportDialog(Room room) {
    final reportController = TextEditingController();
    final currentUser = ref.read(currentUserProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please describe the issue you\'re experiencing:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reportController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe the issue...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final description = reportController.text.trim();
              if (description.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please describe the issue')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              // Send email
              final subject = Uri.encodeComponent('Issue Report: ${room.title}');
              final body = Uri.encodeComponent('''
Issue Report for Bolaa Debate

Room: ${room.title}
Room ID: ${room.id}
Reporter: ${currentUser?.displayName ?? 'Unknown'} (${currentUser?.username ?? 'Unknown'})
Time: ${DateTime.now().toIso8601String()}

Issue Description:
$description
''');
              
              final emailUri = Uri.parse('mailto:developers@turings.xyz?subject=$subject&body=$body');
              
              try {
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open email app. Please email developers@turings.xyz directly.'),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
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
                  message.isBot ? 'Bolaa Bot' : message.user.displayName,
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
    
    _positionAnimation = Tween<double>(begin: 0, end: 300).animate(
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
          bottom: 120 + _positionAnimation.value,
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
