import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/shared/models/room_model.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
  });

  String _getTimeText() {
    if (room.isLive) {
      if (room.startedAt != null) {
        final duration = DateTime.now().difference(room.startedAt!);
        if (duration.inMinutes < 1) {
          return 'Just started';
        } else if (duration.inMinutes < 60) {
          return 'Live for ${duration.inMinutes}m';
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
        return 'In ${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        return 'In ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        return timeago.format(room.scheduledAt, allowFromNow: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(int.parse(room.category.color.replaceFirst('#', '0xFF'))).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(room.category.icon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          room.category.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(int.parse(room.category.color.replaceFirst('#', '0xFF'))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Status badge
                  _StatusBadge(status: room.status),
                ],
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                room.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Sides for debates
              if (room.isDebate && room.sideALabel != null && room.sideBLabel != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _SideBadge(
                        label: room.sideALabel!,
                        count: room.sideACount,
                        color: AppColors.sideA,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('vs', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: _SideBadge(
                        label: room.sideBLabel!,
                        count: room.sideBCount,
                        color: AppColors.sideB,
                        alignRight: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Footer
              Row(
                children: [
                  Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${room.participantCount} joined',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _getTimeText(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: room.isLive ? AppColors.error : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final RoomStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == RoomStatus.live)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool alignRight;

  const _SideBadge({
    required this.label,
    required this.count,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignRight ? TextAlign.end : TextAlign.start,
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
