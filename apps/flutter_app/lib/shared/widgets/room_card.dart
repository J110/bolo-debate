import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/shared/models/room_model.dart';

// ============================================================================
// TOPIC-BASED ILLUSTRATION SYSTEM
// Uses 3D rendered and illustrated artistic images from Unsplash
// These have an illustrated/artistic quality rather than photographic
// ============================================================================

/// Topic keywords mapped to artistic/illustrated style images
const Map<String, List<String>> _topicIllustrations = {
  // Sports - 3D/Artistic renders
  'basketball': [
    'https://images.unsplash.com/photo-1608245449230-4ac19066d2d0?w=400&h=200&fit=crop', // 3D basketball
    'https://images.unsplash.com/photo-1559692048-79a3f837883d?w=400&h=200&fit=crop', // Artistic court
  ],
  'nba': [
    'https://images.unsplash.com/photo-1608245449230-4ac19066d2d0?w=400&h=200&fit=crop',
  ],
  'cricket': [
    'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=400&h=200&fit=crop',
  ],
  'ipl': [
    'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=400&h=200&fit=crop',
  ],
  'football': [
    'https://images.unsplash.com/photo-1552318965-6e6be7484ada?w=400&h=200&fit=crop', // Artistic football
  ],
  'soccer': [
    'https://images.unsplash.com/photo-1552318965-6e6be7484ada?w=400&h=200&fit=crop',
  ],
  
  // Space - Artistic/3D
  'mars': [
    'https://images.unsplash.com/photo-1614732414444-096e5f1122d5?w=400&h=200&fit=crop', // Artistic Mars
    'https://images.unsplash.com/photo-1614313913007-2b4ae8ce32d6?w=400&h=200&fit=crop', // 3D planet
  ],
  'space': [
    'https://images.unsplash.com/photo-1462331940025-496dfbfc7564?w=400&h=200&fit=crop', // Nebula art
    'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=400&h=200&fit=crop', // Space art
  ],
  'astronaut': [
    'https://images.unsplash.com/photo-1614728894747-a83421e2b9c9?w=400&h=200&fit=crop', // Artistic astronaut
    'https://images.unsplash.com/photo-1614313913007-2b4ae8ce32d6?w=400&h=200&fit=crop',
  ],
  'moon': [
    'https://images.unsplash.com/photo-1532693322450-2cb5c511067d?w=400&h=200&fit=crop', // Artistic moon
  ],
  'elon': [
    'https://images.unsplash.com/photo-1457364559154-aa2644600ebb?w=400&h=200&fit=crop', // Rocket art
    'https://images.unsplash.com/photo-1614728894747-a83421e2b9c9?w=400&h=200&fit=crop',
  ],
  'rocket': [
    'https://images.unsplash.com/photo-1457364559154-aa2644600ebb?w=400&h=200&fit=crop',
  ],
  
  // AI & Technology - 3D/Abstract
  'ai': [
    'https://images.unsplash.com/photo-1677442136019-21780ecad995?w=400&h=200&fit=crop', // AI art
    'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=400&h=200&fit=crop', // Robot face art
  ],
  'artificial intelligence': [
    'https://images.unsplash.com/photo-1677442136019-21780ecad995?w=400&h=200&fit=crop',
  ],
  'robot': [
    'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=400&h=200&fit=crop', // White robot
  ],
  'chatgpt': [
    'https://images.unsplash.com/photo-1677442136019-21780ecad995?w=400&h=200&fit=crop',
  ],
  'tech': [
    'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=400&h=200&fit=crop', // Abstract tech
  ],
  
  // Social Media - Artistic/Abstract
  'social media': [
    'https://images.unsplash.com/photo-1611162616305-c69b3fa7fbe0?w=400&h=200&fit=crop', // Social icons art
    'https://images.unsplash.com/photo-1611162618071-b39a2ec055fb?w=400&h=200&fit=crop',
  ],
  'influencer': [
    'https://images.unsplash.com/photo-1611162616305-c69b3fa7fbe0?w=400&h=200&fit=crop',
  ],
  'twitter': [
    'https://images.unsplash.com/photo-1611605698335-8b1569810432?w=400&h=200&fit=crop', // Twitter 3D
  ],
  'instagram': [
    'https://images.unsplash.com/photo-1611162618071-b39a2ec055fb?w=400&h=200&fit=crop', // Instagram 3D
  ],
  'youtube': [
    'https://images.unsplash.com/photo-1611162616475-46b635cb6868?w=400&h=200&fit=crop', // YouTube 3D
  ],
  
  // Crypto - 3D renders
  'crypto': [
    'https://images.unsplash.com/photo-1621761191319-c6fb62004040?w=400&h=200&fit=crop', // 3D crypto
    'https://images.unsplash.com/photo-1622630998477-20aa696ecb05?w=400&h=200&fit=crop',
  ],
  'bitcoin': [
    'https://images.unsplash.com/photo-1622630998477-20aa696ecb05?w=400&h=200&fit=crop', // 3D Bitcoin
    'https://images.unsplash.com/photo-1621761191319-c6fb62004040?w=400&h=200&fit=crop',
  ],
  'blockchain': [
    'https://images.unsplash.com/photo-1639762681485-074b7f938ba0?w=400&h=200&fit=crop', // Blockchain art
  ],
  
  // Finance - Abstract/Artistic
  'stock': [
    'https://images.unsplash.com/photo-1642790106117-e829e14a795f?w=400&h=200&fit=crop', // Abstract chart
    'https://images.unsplash.com/photo-1535320903710-d993d3d77d29?w=400&h=200&fit=crop',
  ],
  'market': [
    'https://images.unsplash.com/photo-1642790106117-e829e14a795f?w=400&h=200&fit=crop',
  ],
  'economy': [
    'https://images.unsplash.com/photo-1535320903710-d993d3d77d29?w=400&h=200&fit=crop', // Abstract economy
  ],
  'investment': [
    'https://images.unsplash.com/photo-1633158829585-23ba8f7c8caf?w=400&h=200&fit=crop', // Growth art
  ],
  'money': [
    'https://images.unsplash.com/photo-1633158829585-23ba8f7c8caf?w=400&h=200&fit=crop',
  ],
  'bank': [
    'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400&h=200&fit=crop', // Abstract finance
  ],
  
  // Energy - Artistic
  'energy': [
    'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=400&h=200&fit=crop', // Power lines art
    'https://images.unsplash.com/photo-1509391366360-2e959784a276?w=400&h=200&fit=crop', // Solar art
  ],
  'solar': [
    'https://images.unsplash.com/photo-1509391366360-2e959784a276?w=400&h=200&fit=crop',
  ],
  'renewable': [
    'https://images.unsplash.com/photo-1466611653911-95081537e5b7?w=400&h=200&fit=crop', // Wind art
  ],
  'power': [
    'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=400&h=200&fit=crop',
  ],
  
  // Politics - Abstract/Artistic
  'government': [
    'https://images.unsplash.com/photo-1569389397653-c04fe624e663?w=400&h=200&fit=crop', // Abstract gov
  ],
  'parliament': [
    'https://images.unsplash.com/photo-1569389397653-c04fe624e663?w=400&h=200&fit=crop',
  ],
  'election': [
    'https://images.unsplash.com/photo-1598518619776-eae3f8a34eac?w=400&h=200&fit=crop', // Vote art
  ],
  'vote': [
    'https://images.unsplash.com/photo-1598518619776-eae3f8a34eac?w=400&h=200&fit=crop',
  ],
  'democracy': [
    'https://images.unsplash.com/photo-1569389397653-c04fe624e663?w=400&h=200&fit=crop',
  ],
  'law': [
    'https://images.unsplash.com/photo-1589994965851-a8f479c573a9?w=400&h=200&fit=crop', // Justice art
  ],
  'court': [
    'https://images.unsplash.com/photo-1589994965851-a8f479c573a9?w=400&h=200&fit=crop',
  ],
  'justice': [
    'https://images.unsplash.com/photo-1589994965851-a8f479c573a9?w=400&h=200&fit=crop',
  ],
  'police': [
    'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=400&h=200&fit=crop', // Abstract law
  ],
  'security': [
    'https://images.unsplash.com/photo-1563013544-824ae1b704d3?w=400&h=200&fit=crop', // Security art
  ],
  'hate': [
    'https://images.unsplash.com/photo-1585829365295-ab7cd400c167?w=400&h=200&fit=crop', // Speech art
  ],
  
  // Entertainment - Artistic
  'movie': [
    'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=400&h=200&fit=crop', // Cinema art
    'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=400&h=200&fit=crop',
  ],
  'film': [
    'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=400&h=200&fit=crop', // Film reel art
  ],
  'cinema': [
    'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=400&h=200&fit=crop',
  ],
  'bollywood': [
    'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=400&h=200&fit=crop',
  ],
  'music': [
    'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=400&h=200&fit=crop', // Music art
    'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=400&h=200&fit=crop',
  ],
  'concert': [
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=400&h=200&fit=crop', // Concert art
  ],
  'gaming': [
    'https://images.unsplash.com/photo-1612287230202-1ff1d85d1bdf?w=400&h=200&fit=crop', // Gaming art
    'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=400&h=200&fit=crop',
  ],
  'game': [
    'https://images.unsplash.com/photo-1612287230202-1ff1d85d1bdf?w=400&h=200&fit=crop',
  ],
  'netflix': [
    'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?w=400&h=200&fit=crop', // Streaming art
  ],
  'ott': [
    'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?w=400&h=200&fit=crop',
  ],
  
  // Environment - Artistic
  'climate': [
    'https://images.unsplash.com/photo-1569163139599-0f4517e36f51?w=400&h=200&fit=crop', // Climate art
  ],
  'environment': [
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=200&fit=crop', // Nature art
  ],
  'pollution': [
    'https://images.unsplash.com/photo-1569163139599-0f4517e36f51?w=400&h=200&fit=crop',
  ],
  
  // Education - Artistic
  'education': [
    'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=400&h=200&fit=crop', // Books art
    'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=400&h=200&fit=crop',
  ],
  'school': [
    'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=400&h=200&fit=crop',
  ],
  'university': [
    'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=400&h=200&fit=crop', // Graduation art
  ],
  
  // Health - Artistic
  'health': [
    'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=400&h=200&fit=crop', // Health art
  ],
  'hospital': [
    'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=400&h=200&fit=crop',
  ],
  'doctor': [
    'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=400&h=200&fit=crop',
  ],
  'covid': [
    'https://images.unsplash.com/photo-1584483766114-2cea6facdf57?w=400&h=200&fit=crop', // Virus art
  ],
  'vaccine': [
    'https://images.unsplash.com/photo-1615631648086-325025c9e51e?w=400&h=200&fit=crop', // Vaccine art
  ],
  
  // Social - Artistic
  'women': [
    'https://images.unsplash.com/photo-1489924309280-8791d2dfc2cd?w=400&h=200&fit=crop', // Women art
  ],
  'farmer': [
    'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=400&h=200&fit=crop', // Farm art
  ],
  'agriculture': [
    'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=400&h=200&fit=crop',
  ],
  
  // Business - Artistic
  'startup': [
    'https://images.unsplash.com/photo-1559136555-9303baea8ebd?w=400&h=200&fit=crop', // Startup art
  ],
  'business': [
    'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=400&h=200&fit=crop', // Business art
  ],
  'manufacturing': [
    'https://images.unsplash.com/photo-1565043589221-1a6fd9ae45c7?w=400&h=200&fit=crop', // Factory art
  ],
};

/// Category fallback illustrations (artistic style)
const Map<String, List<String>> _categoryFallbackIllustrations = {
  'Politics': [
    'https://images.unsplash.com/photo-1569389397653-c04fe624e663?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1598518619776-eae3f8a34eac?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1589994965851-a8f479c573a9?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1541872703-74c5e44368f9?w=400&h=200&fit=crop',
  ],
  'Technology': [
    'https://images.unsplash.com/photo-1677442136019-21780ecad995?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=400&h=200&fit=crop',
  ],
  'Business': [
    'https://images.unsplash.com/photo-1642790106117-e829e14a795f?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1633158829585-23ba8f7c8caf?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400&h=200&fit=crop',
  ],
  'Sports': [
    'https://images.unsplash.com/photo-1608245449230-4ac19066d2d0?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1552318965-6e6be7484ada?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1461896836934-eba62b1e38c1?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=400&h=200&fit=crop',
  ],
  'Entertainment': [
    'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1612287230202-1ff1d85d1bdf?w=400&h=200&fit=crop',
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=400&h=200&fit=crop',
  ],
};

/// Get the best matching illustration URL for a room
String _getImageUrl(Room room) {
  final lowerTitle = room.title.toLowerCase();
  
  // Try to find a keyword match
  for (final entry in _topicIllustrations.entries) {
    if (lowerTitle.contains(entry.key)) {
      final images = entry.value;
      final index = room.id.hashCode.abs() % images.length;
      return images[index];
    }
  }
  
  // Fallback to category illustrations
  final categoryImages = _categoryFallbackIllustrations[room.category.name] ?? 
      _categoryFallbackIllustrations['Technology']!;
  final index = room.id.hashCode.abs() % categoryImages.length;
  return categoryImages[index];
}

/// Get category-specific gradient for overlay
List<Color> _getCategoryGradient(String categoryName) {
  switch (categoryName) {
    case 'Politics':
      return [const Color(0xFFE53935), const Color(0xFFFF7043)];
    case 'Technology':
      return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
    case 'Business':
      return [const Color(0xFFF57C00), const Color(0xFFFFB74D)];
    case 'Sports':
      return [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];
    case 'Entertainment':
      return [const Color(0xFF7B1FA2), const Color(0xFFBA68C8)];
    default:
      return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
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
            // Image section - full coverage with relevant topic image
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Topic-relevant image
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
                    ),
                  ),
                  // Subtle gradient overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
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
