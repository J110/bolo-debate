import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/shared/models/room_model.dart';

/// Category-specific base keywords for image search
const Map<String, String> _categoryBaseKeywords = {
  'Politics': 'government,parliament,politics',
  'Technology': 'technology,digital,computer',
  'Business': 'business,finance,office',
  'Sports': 'sports,athlete,stadium',
  'Entertainment': 'entertainment,movie,cinema',
};

/// Topic keywords to detect and use for more relevant images
const Map<String, String> _topicKeywordMap = {
  // Technology topics
  'ai': 'artificial-intelligence,robot,technology',
  'artificial intelligence': 'artificial-intelligence,robot,futuristic',
  'social media': 'social-media,smartphone,app',
  'twitter': 'social-media,technology,digital',
  'facebook': 'social-media,technology,network',
  'instagram': 'social-media,phone,app',
  'cyber': 'cybersecurity,hacker,computer',
  'software': 'coding,programming,developer',
  'startup': 'startup,entrepreneur,office',
  'digital': 'digital,technology,innovation',
  'internet': 'internet,network,technology',
  'app': 'mobile-app,smartphone,technology',
  'data': 'data,analytics,technology',
  'cloud': 'cloud-computing,server,technology',
  '5g': 'network,technology,communication',
  
  // Sports topics
  'cricket': 'cricket,bat,stadium',
  'ipl': 'cricket,stadium,sports',
  'football': 'football,soccer,stadium',
  'hockey': 'hockey,sports,team',
  'tennis': 'tennis,court,sports',
  'olympic': 'olympics,medal,athlete',
  'athlete': 'athlete,sports,fitness',
  'match': 'sports,stadium,competition',
  'team': 'team,sports,players',
  'player': 'sports,athlete,player',
  'sport': 'sports,athlete,competition',
  'fitness': 'fitness,gym,workout',
  
  // Politics topics
  'election': 'election,vote,ballot',
  'parliament': 'parliament,government,politics',
  'minister': 'government,politics,meeting',
  'government': 'government,capitol,politics',
  'law': 'law,justice,court',
  'court': 'court,justice,law',
  'policy': 'government,policy,meeting',
  'vote': 'voting,election,democracy',
  'congress': 'congress,parliament,politics',
  
  // Business topics
  'stock': 'stock-market,trading,finance',
  'market': 'stock-market,finance,business',
  'economy': 'economy,finance,growth',
  'tax': 'tax,finance,money',
  'bank': 'bank,finance,money',
  'investment': 'investment,finance,growth',
  'trade': 'trade,business,commerce',
  'rupee': 'currency,money,finance',
  'gdp': 'economy,growth,chart',
  'company': 'business,corporate,office',
  
  // Entertainment topics
  'bollywood': 'bollywood,film,cinema',
  'movie': 'movie,cinema,film',
  'film': 'film,cinema,camera',
  'actor': 'actor,celebrity,film',
  'music': 'music,concert,performance',
  'ott': 'streaming,television,entertainment',
  'netflix': 'streaming,television,entertainment',
  'celebrity': 'celebrity,entertainment,star',
  'award': 'award,trophy,celebration',
};

/// Generate a relevant image URL based on room title and category
String _getImageUrl(Room room) {
  final title = room.title.toLowerCase();
  final category = room.category.name;
  
  // First, try to find topic-specific keywords from the title
  String? matchedKeywords;
  for (final entry in _topicKeywordMap.entries) {
    if (title.contains(entry.key)) {
      matchedKeywords = entry.value;
      break;
    }
  }
  
  // Fall back to category base keywords if no topic match
  final keywords = matchedKeywords ?? _categoryBaseKeywords[category] ?? 'debate,discussion';
  
  // Use room ID for cache-busting but keep same image for same room
  final sig = room.id.hashCode.abs() % 1000;
  
  // Use Unsplash Source API with keywords for relevant images
  return 'https://source.unsplash.com/400x200/?$keywords&sig=$sig';
}

/// Get category-specific gradient colors
List<Color> _getCategoryGradient(String categoryName) {
  switch (categoryName) {
    case 'Politics':
      return [const Color(0xFFE53935), const Color(0xFFFF7043)];
    case 'Technology':
      return [const Color(0xFF1E88E5), const Color(0xFF42A5F5)];
    case 'Business':
      return [const Color(0xFFFFA726), const Color(0xFFFFCC02)];
    case 'Sports':
      return [const Color(0xFF43A047), const Color(0xFF66BB6A)];
    case 'Entertainment':
      return [const Color(0xFF8E24AA), const Color(0xFFBA68C8)];
    default:
      return [AppColors.primary, AppColors.secondary];
  }
}

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;
  final bool showShareButton;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.showShareButton = true,
  });

  void _shareRoom() {
    final shareUrl = 'https://bolo-debate.vercel.app/room/${room.id}';
    final statusEmoji = room.isLive ? '🔴 LIVE' : '📅 Upcoming';
    final shareText = '''🎙️ Join the debate on Bolo!

$statusEmoji
📢 "${room.title}"

${room.sideALabel ?? ''} vs ${room.sideBLabel ?? ''}

Join now and voice your opinion! 👇
$shareUrl''';

    Share.share(shareText, subject: 'Join my debate on Bolo!');
  }

  String _getTimeText() {
    if (room.isLive) {
      if (room.startedAt != null) {
        final duration = DateTime.now().difference(room.startedAt!);
        if (duration.inMinutes < 1) {
          return 'Just started';
        } else if (duration.inMinutes < 60) {
          return '${duration.inMinutes}m ago';
        } else {
          return '${duration.inHours}h ${duration.inMinutes % 60}m';
        }
      }
      return 'Live now';
    } else {
      final now = DateTime.now();
      final diff = room.scheduledAt.difference(now);
      if (diff.isNegative) {
        return 'Starting soon';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m left';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h left';
      } else {
        return '${diff.inDays}d left';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(int.parse(room.category.color.replaceFirst('#', '0xFF')));
    final gradientColors = _getCategoryGradient(room.category.name);
    
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with gradient overlay
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  CachedNetworkImage(
                    imageUrl: _getImageUrl(room),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        _getCategoryIcon(room.category.name),
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                  // Gradient overlay for better text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Status badge (top right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _StatusBadge(status: room.status),
                  ),
                  // Language badge (top left, if not English)
                  if (room.language != 'English')
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          room.language,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Row(
                      children: [
                        Text(
                          room.category.icon,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          room.category.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Expanded(
                      child: Text(
                        room.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Footer with stats and join button
                    Row(
                      children: [
                        // Participants
                        Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${room.participantCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Time
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeText(),
                          style: TextStyle(
                            fontSize: 12,
                            color: room.isLive ? AppColors.error : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        // Join button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            room.isLive ? 'Join' : 'View',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _getCategoryIcon(String categoryName) {
  switch (categoryName) {
    case 'Politics':
      return Icons.account_balance;
    case 'Technology':
      return Icons.computer;
    case 'Business':
      return Icons.trending_up;
    case 'Sports':
      return Icons.sports_soccer;
    case 'Entertainment':
      return Icons.movie;
    default:
      return Icons.category;
  }
}

class _StatusBadge extends StatelessWidget {
  final RoomStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color bgColor;
    late Color textColor;
    late String label;

    switch (status) {
      case RoomStatus.live:
        bgColor = AppColors.error;
        textColor = Colors.white;
        label = 'LIVE';
        break;
      case RoomStatus.scheduled:
        bgColor = Colors.white;
        textColor = AppColors.warning;
        label = 'UPCOMING';
        break;
      case RoomStatus.ended:
        bgColor = Colors.grey[800]!;
        textColor = Colors.white;
        label = 'ENDED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == RoomStatus.live)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
