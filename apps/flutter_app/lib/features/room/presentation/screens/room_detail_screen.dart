import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:bolo_debate/core/constants/app_constants.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/home/presentation/providers/data_providers.dart';
import 'package:bolo_debate/shared/models/room_model.dart';
import 'package:bolo_debate/shared/widgets/page_header.dart';
import 'package:bolo_debate/shared/widgets/live_indicator.dart';
import 'package:bolo_debate/shared/utils/image_utils.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;

  const RoomDetailScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  static const MethodChannel _nativeShareChannel = MethodChannel('bolo/native_share');
  String? _selectedSide;

  Future<void> _shareRoom(Room room) async {
    final shareUrl = 'https://bolaa.app/#/room/${room.id}';
    final statusEmoji = room.isLive ? '🔴 LIVE' : '📅 Scheduled';
    final hasSides = (room.sideALabel?.trim().isNotEmpty ?? false) &&
        (room.sideBLabel?.trim().isNotEmpty ?? false);
    final sidesLine = hasSides ? '\n${room.sideALabel} vs ${room.sideBLabel}\n' : '\n';
    final shareText = '''🎙️ Join the debate on Bolaa!

$statusEmoji
📢 "${room.title}"
$sidesLine

${room.description ?? ''}

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
        await Clipboard.setData(ClipboardData(text: shareText));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed, invite copied instead: $e')),
          );
        }
      }
      return;
    }

    await Share.share(shareText, subject: 'Join my debate on Bolaa!');
  }

  void _onSideSelected(BuildContext context, Room room, String side) {
    setState(() => _selectedSide = side);
    // Auto-show pledge dialog when side is selected for live rooms
    if (room.isLive) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _showPledgeDialog(context, room);
        }
      });
    }
  }

  String _getTimeDisplayText(Room room) {
    if (room.isLive) {
      if (room.startedAt != null) {
        final duration = DateTime.now().difference(room.startedAt!);
        if (duration.inMinutes < 1) {
          return 'Started just now';
        } else if (duration.inMinutes < 60) {
          return 'Live for ${duration.inMinutes} min';
        } else {
          return 'Live for ${duration.inHours}h ${duration.inMinutes % 60}m';
        }
      }
      return 'Live now';
    } else {
      final now = DateTime.now();
      final diff = room.scheduledAt.difference(now);
      if (diff.isNegative) {
        return 'Starting soon';
      } else if (diff.inMinutes < 60) {
        return 'Starts in ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        return 'Starts ${timeago.format(room.scheduledAt, allowFromNow: true)}';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomDetailProvider(widget.roomId));

    return Scaffold(
      body: roomAsync.when(
        data: (room) {
          if (room == null) {
            return const Center(child: Text('Room not found'));
          }
    return _buildContent(context, room);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      // For non-debate rooms or scheduled rooms, show a join/reminder button
      bottomNavigationBar: roomAsync.when(
        data: (room) {
          if (room == null || room.status == RoomStatus.ended) {
            return const SizedBox.shrink();
          }
          // For debate rooms that are live, joining is automatic on side selection
          if (room.isDebate && room.isLive) {
            return const SizedBox.shrink();
          }
          // For non-debate live rooms, show join button
          if (!room.isDebate && room.isLive) {
            return _buildNonDebateJoinButton(context, room);
          }
          // For scheduled rooms, show reminder button
          if (room.status == RoomStatus.scheduled) {
            return _buildReminderButton(context, room);
          }
          return const SizedBox.shrink();
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildNonDebateJoinButton(BuildContext context, Room room) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => _showPledgeDialog(context, room),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic),
              SizedBox(width: 8),
              Text(
                'Join Live Room',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderButton(BuildContext context, Room room) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reminder set! We\'ll notify you when this room goes live.')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_active),
              SizedBox(width: 8),
              Text(
                'Set Reminder',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Room room) {
    final categoryColor = Color(int.parse(room.category.color.replaceFirst('#', '0xFF')));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner with room's illustration (replaces AppBar)
          PageHeaders.roomDetail(
            title: room.title,
            categoryName: room.category.name,
            categoryIcon: room.category.icon,
            categoryColor: categoryColor,
            isLive: room.isLive,
            illustrationUrl: getCanonicalRoomImageUrl(room, width: 600, height: 300),
            onBack: () => Navigator.of(context).pop(),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () async {
                  try {
                    await _shareRoom(room);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unable to share: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and category chips
                Row(
                  children: [
                    _StatusChip(status: room.status),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(room.category.icon),
                          const SizedBox(width: 4),
                          Text(
                            room.category.name,
                            style: TextStyle(
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                if (room.description != null) ...[
                  Text(
                    room.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Region and time
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${room.region.name}, ${room.region.state}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 16, color: room.isLive ? AppColors.error : Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeDisplayText(room),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: room.isLive ? AppColors.error : null,
                            fontWeight: room.isLive ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sides for debate
                if (room.isDebate && room.sideALabel != null && room.sideBLabel != null) ...[
                  Text(
                    room.isLive ? 'Choose your side to join' : 'Choose your side',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SideCard(
                          label: room.sideALabel!,
                          count: room.sideACount,
                          color: AppColors.sideA,
                          isSelected: _selectedSide == 'A',
                          onTap: () => _onSideSelected(context, room, 'A'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                        child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      ),
                      Expanded(
                        child: _SideCard(
                          label: room.sideBLabel!,
                          count: room.sideBCount,
                          color: AppColors.sideB,
                          isSelected: _selectedSide == 'B',
                          onTap: () => _onSideSelected(context, room, 'B'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _onSideSelected(context, room, 'NEUTRAL'),
                      icon: Icon(
                        _selectedSide == 'NEUTRAL' ? Icons.check_circle : Icons.remove_red_eye,
                        size: 18,
                        color: _selectedSide == 'NEUTRAL' ? AppColors.primary : Colors.grey,
                      ),
                      label: Text(
                        _selectedSide == 'NEUTRAL' ? 'Joining as neutral listener' : 'Join as neutral listener',
                        style: TextStyle(
                          color: _selectedSide == 'NEUTRAL' ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Host info
                if (room.host != null) ...[
                  Text(
                    'Hosted by',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        child: Text(
                          room.host!.displayName[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.host!.displayName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '@${room.host!.username}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else if (room.isAiHosted) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.smart_toy, color: AppColors.info),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI-Hosted Room',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'You can claim host once you join',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Participants count
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.people,
                        label: 'Participants',
                        value: '${room.participantCount}',
                      ),
                      if (room.isDebate) ...[
                        _StatItem(
                          icon: Icons.thumb_up,
                          label: room.sideALabel ?? 'Side A',
                          value: '${room.sideACount}',
                          color: AppColors.sideA,
                        ),
                        _StatItem(
                          icon: Icons.thumb_down,
                          label: room.sideBLabel ?? 'Side B',
                          value: '${room.sideBCount}',
                          color: AppColors.sideB,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPledgeDialog(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.pledgeTitle),
        content: SingleChildScrollView(
          child: Text(AppStrings.pledgeContent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/room/${widget.roomId}', extra: _selectedSide);
            },
            child: const Text('I Pledge'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final RoomStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    // Use pulsating indicator for live rooms
    if (status == RoomStatus.live) {
      return const LiveChip(fontSize: 12);
    }

    late Color color;
    late String label;

    switch (status) {
      case RoomStatus.live:
        color = AppColors.error;
        label = 'LIVE';
        break;
      case RoomStatus.scheduled:
        color = AppColors.warning;
        label = 'SCHEDULED';
        break;
      case RoomStatus.ended:
        color = Colors.grey;
        label = 'ENDED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SideCard({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full text display with wrapping
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? color : null,
              ),
              textAlign: TextAlign.center,
              // Allow text to wrap to multiple lines
              softWrap: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count joined',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Icon(Icons.check_circle, color: color, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
