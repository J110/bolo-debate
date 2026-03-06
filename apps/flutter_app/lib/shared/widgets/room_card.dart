import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/shared/models/room_model.dart';
import 'package:bolo_debate/shared/utils/image_utils.dart';
import 'package:bolo_debate/shared/widgets/live_indicator.dart';

// ============================================================================
// TOPIC-BASED ILLUSTRATION SYSTEM
// Uses Pixabay illustrations with colored overlay for cohesive branding
// ============================================================================

/// Color themes for overlay - creates uniform look across all images
class _OverlayTheme {
  final Color primary;
  final Color secondary;
  final double opacity;
  
  const _OverlayTheme({
    required this.primary,
    required this.secondary,
    this.opacity = 0.55,
  });
}

/// Diverse color themes that rotate based on room hash
const List<_OverlayTheme> _colorThemes = [
  _OverlayTheme(primary: Color(0xFF6366F1), secondary: Color(0xFF8B5CF6)), // Indigo-Purple
  _OverlayTheme(primary: Color(0xFF14B8A6), secondary: Color(0xFF06B6D4)), // Teal-Cyan
  _OverlayTheme(primary: Color(0xFFF59E0B), secondary: Color(0xFFEF4444)), // Amber-Red
  _OverlayTheme(primary: Color(0xFF10B981), secondary: Color(0xFF34D399)), // Emerald
  _OverlayTheme(primary: Color(0xFFEC4899), secondary: Color(0xFFF472B6)), // Pink
  _OverlayTheme(primary: Color(0xFF3B82F6), secondary: Color(0xFF60A5FA)), // Blue
  _OverlayTheme(primary: Color(0xFF8B5CF6), secondary: Color(0xFFA78BFA)), // Violet
  _OverlayTheme(primary: Color(0xFFEF4444), secondary: Color(0xFFF87171)), // Red
  _OverlayTheme(primary: Color(0xFF06B6D4), secondary: Color(0xFF22D3EE)), // Cyan
  _OverlayTheme(primary: Color(0xFFF97316), secondary: Color(0xFFFB923C)), // Orange
];

/// Get color theme based on room ID for consistent but diverse colors
_OverlayTheme _getOverlayTheme(String roomId) {
  final hash = roomId.hashCode.abs();
  return _colorThemes[hash % _colorThemes.length];
}

/// Hindi to English keyword mapping
/// Maps common Hindi words to English equivalents for image search
const Map<String, String> _hindiToEnglish = {
  // Business & Finance
  'बैंक': 'bank',
  'बैंकिंग': 'bank',
  'जब्ती': 'bank',
  'फोरक्लोजर': 'bank',
  'व्यापार': 'business',
  'कारोबार': 'business',
  'अर्थव्यवस्था': 'economy',
  'पैसा': 'money',
  'निवेश': 'investment',
  
  // Celebrity & Entertainment
  'सेलिब्रिटी': 'celebrity',
  'एंडोर्समेंट': 'endorsement',
  'ब्रांड': 'brand',
  'फिल्म': 'film',
  'मूवी': 'movie',
  'बॉलीवुड': 'bollywood',
  'संगीत': 'music',
  'मनोरंजन': 'entertainment',
  
  // Politics & Government  
  'सरकार': 'government',
  'राजनीति': 'politics',
  'चुनाव': 'election',
  'कानून': 'law',
  'न्याय': 'justice',
  'पुलिस': 'police',
  'भारत': 'india',
  'भारतीय': 'india',
  'नियंत्रित': 'regulate',
  
  // Technology & Security
  'सुरक्षा': 'security',
  'हथियार': 'weapon',
  'आतंक': 'terror',
  'आतंकवाद': 'terror',
  'तकनीक': 'technology',
  'इंटरनेट': 'internet',
  'साइबर': 'cyber',
  
  // Sports & Health
  'खेल': 'sports',
  'क्रिकेट': 'cricket',
  'चोट': 'injury',
  'स्वास्थ्य': 'health',
  'डॉक्टर': 'doctor',
  'अस्पताल': 'hospital',
  
  // Social
  'शादी': 'marriage',
  'विवाह': 'marriage',
  'महिला': 'women',
  'शिक्षा': 'education',
  'स्कूल': 'school',
  
  // Environment
  'पर्यावरण': 'environment',
  'जलवायु': 'climate',
  'ऊर्जा': 'energy',
  'किसान': 'farmer',
  
  // Common words
  'उत्पाद': 'product',
  'पारंपरिक': 'traditional',
  'पुनर्जीवित': 'revive',
  'आक्रामक': 'aggressive',
  'कार्यवाही': 'proceedings',
  'लड़ाई': 'fight',
  'सही': 'right',
};

/// Simple illustration URLs from Pixabay (searched with "simple [keyword] illustration")
const Map<String, List<String>> _topicIllustrations = {
  // Bank & Finance
  'bank': [
    'https://cdn.pixabay.com/photo/2017/09/07/08/54/money-2724241_640.png',
    'https://cdn.pixabay.com/photo/2013/07/12/18/17/wallet-153458_640.png',
  ],
  'money': [
    'https://cdn.pixabay.com/photo/2017/09/07/08/54/money-2724241_640.png',
    'https://cdn.pixabay.com/photo/2013/07/12/18/17/wallet-153458_640.png',
  ],
  'investment': [
    'https://cdn.pixabay.com/photo/2017/01/31/20/36/chart-2027905_640.png',
  ],
  'foreclosure': [
    'https://cdn.pixabay.com/photo/2013/07/12/18/17/wallet-153458_640.png',
  ],
  
  // Business
  'business': [
    'https://cdn.pixabay.com/photo/2017/01/31/20/36/chart-2027905_640.png',
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
  ],
  'economy': [
    'https://cdn.pixabay.com/photo/2017/01/31/20/36/chart-2027905_640.png',
  ],
  'product': [
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
  ],
  'traditional': [
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
  ],
  'revive': [
    'https://cdn.pixabay.com/photo/2017/01/31/20/36/chart-2027905_640.png',
  ],
  'aggressive': [
    'https://cdn.pixabay.com/photo/2017/01/31/17/34/balance-2025786_640.png',
  ],
  'regulate': [
    'https://cdn.pixabay.com/photo/2017/01/31/17/34/balance-2025786_640.png',
  ],
  
  // Celebrity & Entertainment
  'celebrity': [
    'https://cdn.pixabay.com/photo/2016/11/22/19/15/hand-1850120_640.png',
    'https://cdn.pixabay.com/photo/2014/04/02/10/55/people-304353_640.png',
  ],
  'endorsement': [
    'https://cdn.pixabay.com/photo/2016/11/22/19/15/hand-1850120_640.png',
  ],
  'brand': [
    'https://cdn.pixabay.com/photo/2016/11/22/19/15/hand-1850120_640.png',
  ],
  'film': [
    'https://cdn.pixabay.com/photo/2017/11/24/10/43/admission-2974645_640.png',
    'https://cdn.pixabay.com/photo/2013/07/12/14/07/film-147631_640.png',
  ],
  'movie': [
    'https://cdn.pixabay.com/photo/2017/11/24/10/43/admission-2974645_640.png',
  ],
  'bollywood': [
    'https://cdn.pixabay.com/photo/2017/11/24/10/43/admission-2974645_640.png',
  ],
  'entertainment': [
    'https://cdn.pixabay.com/photo/2013/07/12/14/07/film-147631_640.png',
  ],
  'music': [
    'https://cdn.pixabay.com/photo/2014/04/05/11/38/music-316587_640.png',
  ],
  
  // Sports
  'sports': [
    'https://cdn.pixabay.com/photo/2013/07/13/10/51/football-157930_640.png',
    'https://cdn.pixabay.com/photo/2014/04/03/10/32/basketball-311553_640.png',
  ],
  'cricket': [
    'https://cdn.pixabay.com/photo/2013/07/13/10/51/football-157930_640.png',
  ],
  'injury': [
    'https://cdn.pixabay.com/photo/2017/10/04/09/56/physician-2816640_640.png',
  ],
  
  // Politics & Government
  'government': [
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
    'https://cdn.pixabay.com/photo/2017/01/31/17/34/balance-2025786_640.png',
  ],
  'politics': [
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
  ],
  'india': [
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
  ],
  'election': [
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
  ],
  'law': [
    'https://cdn.pixabay.com/photo/2017/01/31/17/34/balance-2025786_640.png',
  ],
  'justice': [
    'https://cdn.pixabay.com/photo/2017/01/31/17/34/balance-2025786_640.png',
  ],
  'police': [
    'https://cdn.pixabay.com/photo/2012/04/14/16/26/shield-34407_640.png',
  ],
  
  // Security & Weapons
  'security': [
    'https://cdn.pixabay.com/photo/2012/04/14/16/26/shield-34407_640.png',
  ],
  'weapon': [
    'https://cdn.pixabay.com/photo/2012/04/14/16/26/shield-34407_640.png',
  ],
  'terror': [
    'https://cdn.pixabay.com/photo/2012/04/14/16/26/shield-34407_640.png',
  ],
  'fight': [
    'https://cdn.pixabay.com/photo/2012/04/14/16/26/shield-34407_640.png',
  ],
  
  // Technology
  'technology': [
    'https://cdn.pixabay.com/photo/2019/03/21/15/51/chatbot-4071274_640.png',
  ],
  'ai': [
    'https://cdn.pixabay.com/photo/2019/03/21/15/51/chatbot-4071274_640.png',
  ],
  'internet': [
    'https://cdn.pixabay.com/photo/2019/03/21/15/51/chatbot-4071274_640.png',
  ],
  'cyber': [
    'https://cdn.pixabay.com/photo/2019/03/21/15/51/chatbot-4071274_640.png',
  ],
  
  // Health
  'health': [
    'https://cdn.pixabay.com/photo/2017/10/04/09/56/physician-2816640_640.png',
  ],
  'doctor': [
    'https://cdn.pixabay.com/photo/2017/10/04/09/56/physician-2816640_640.png',
  ],
  'hospital': [
    'https://cdn.pixabay.com/photo/2017/10/04/09/56/physician-2816640_640.png',
  ],
  
  // Social
  'marriage': [
    'https://cdn.pixabay.com/photo/2014/04/02/10/55/people-304353_640.png',
  ],
  'women': [
    'https://cdn.pixabay.com/photo/2014/04/02/10/55/people-304353_640.png',
  ],
  'education': [
    'https://cdn.pixabay.com/photo/2018/03/21/07/16/learning-3245793_640.png',
  ],
  'school': [
    'https://cdn.pixabay.com/photo/2018/03/21/07/16/learning-3245793_640.png',
  ],
  
  // Environment
  'environment': [
    'https://cdn.pixabay.com/photo/2016/11/29/09/32/climate-change-1868772_640.png',
  ],
  'climate': [
    'https://cdn.pixabay.com/photo/2016/11/29/09/32/climate-change-1868772_640.png',
  ],
  'energy': [
    'https://cdn.pixabay.com/photo/2016/11/29/09/32/climate-change-1868772_640.png',
  ],
  'farmer': [
    'https://cdn.pixabay.com/photo/2016/11/29/09/32/climate-change-1868772_640.png',
  ],
};

/// Category fallback illustrations (simple Pixabay style)
const Map<String, List<String>> _categoryFallbackIllustrations = {
  'Politics': [
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
    'https://cdn.pixabay.com/photo/2017/01/31/17/34/balance-2025786_640.png',
  ],
  'Technology': [
    'https://cdn.pixabay.com/photo/2019/03/21/15/51/chatbot-4071274_640.png',
    'https://cdn.pixabay.com/photo/2012/04/14/16/26/shield-34407_640.png',
  ],
  'Business': [
    'https://cdn.pixabay.com/photo/2017/01/31/20/36/chart-2027905_640.png',
    'https://cdn.pixabay.com/photo/2013/07/12/18/17/wallet-153458_640.png',
    'https://cdn.pixabay.com/photo/2013/07/12/14/45/handshake-148695_640.png',
  ],
  'Sports': [
    'https://cdn.pixabay.com/photo/2013/07/13/10/51/football-157930_640.png',
    'https://cdn.pixabay.com/photo/2014/04/03/10/32/basketball-311553_640.png',
  ],
  'Entertainment': [
    'https://cdn.pixabay.com/photo/2017/11/24/10/43/admission-2974645_640.png',
    'https://cdn.pixabay.com/photo/2013/07/12/14/07/film-147631_640.png',
    'https://cdn.pixabay.com/photo/2014/04/05/11/38/music-316587_640.png',
  ],
  'Social': [
    'https://cdn.pixabay.com/photo/2014/04/02/10/55/people-304353_640.png',
    'https://cdn.pixabay.com/photo/2018/03/21/07/16/learning-3245793_640.png',
  ],
  'Environment': [
    'https://cdn.pixabay.com/photo/2016/11/29/09/32/climate-change-1868772_640.png',
  ],
};

/// Get the best illustration URL for a room
/// Prefers room.illustrationUrl (from Pixabay API), falls back to local matching
String _getImageUrl(Room room) {
  return getCanonicalRoomImageUrl(room);
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
    final shareUrl = 'https://bolaa.app/#/room/${room.id}';
    final statusEmoji = room.isLive ? '🔴 LIVE' : '📅 Upcoming';
    final hasSides = (room.sideALabel?.trim().isNotEmpty ?? false) &&
        (room.sideBLabel?.trim().isNotEmpty ?? false);
    final sidesLine = hasSides ? '\n${room.sideALabel} vs ${room.sideBLabel}\n' : '\n';
    final shareText = '''🎙️ Join the debate on Bolaa!

$statusEmoji
📢 "${room.title}"
$sidesLine

Join now and voice your opinion! 👇
$shareUrl''';

    Share.share(shareText, subject: 'Join my debate on Bolaa!');
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
    final overlayTheme = _getOverlayTheme(room.id);
    final imageUrl = _getImageUrl(room);
    final fallbackUrl = 'https://picsum.photos/seed/${room.id}/640/300';

    // Start preloading images after the first frame to improve perceived load speed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(NetworkImage(imageUrl), context).catchError((_) {});
      precacheImage(NetworkImage(fallbackUrl), context).catchError((_) {});
    });
    
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with artistic duotone effect
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [overlayTheme.primary, overlayTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // STEP 1: High contrast + posterize matrix - reduces detail like a drawing
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      1.5, -0.3, -0.3, 0, -40,  // Boost red, reduce others, darken
                      -0.3, 1.5, -0.3, 0, -40,  // Boost green, reduce others, darken
                      -0.3, -0.3, 1.5, 0, -40,  // Boost blue, reduce others, darken
                      0,    0,    0,   1,   0,
                    ]),
                    child: _RetryingNetworkImage(
                      imageUrl: _getImageUrl(room),
                      fallbackUrl: 'https://picsum.photos/seed/${room.id}/640/300',
                      fit: BoxFit.cover,
                      overlayTheme: overlayTheme,
                    ),
                  ),
                  // STEP 2: Saturation boost layer - makes colors more vibrant/painted
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          overlayTheme.primary.withOpacity(0.70),
                          overlayTheme.secondary.withOpacity(0.65),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      backgroundBlendMode: BlendMode.saturation,
                    ),
                  ),
                  // STEP 3: Color overlay - creates the duotone illustration effect
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          overlayTheme.primary.withOpacity(0.80),
                          overlayTheme.secondary.withOpacity(0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      backgroundBlendMode: BlendMode.color,
                    ),
                  ),
                  // STEP 4: Darken layer - creates painted shadow depth
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.15),
                          overlayTheme.primary.withOpacity(0.35),
                          overlayTheme.secondary.withOpacity(0.45),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      backgroundBlendMode: BlendMode.darken,
                    ),
                  ),
                  // STEP 5: Screen highlight - adds painted light effect
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                        center: Alignment.topLeft,
                        radius: 1.2,
                      ),
                      backgroundBlendMode: BlendMode.screen,
                    ),
                  ),
                  // STEP 6: Overlay for final painted texture look
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          overlayTheme.secondary.withOpacity(0.15),
                          overlayTheme.primary.withOpacity(0.20),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      backgroundBlendMode: BlendMode.overlay,
                    ),
                  ),
                  // Status badge (top right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _StatusBadge(status: room.status),
                  ),
                  // Topic type + Language badges (top left)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        // Topic type badge (Local or Evergreen)
                        if (room.topicTypeLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: room.isTrending 
                                  ? const Color(0xFF10B981) // Green for Local/Trending
                                  : const Color(0xFF8B5CF6), // Purple for Evergreen/Generic
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  room.isTrending ? Icons.trending_up : Icons.star,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  room.topicTypeLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Language badge (if not English)
                        if (room.language != 'English') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black38,
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
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content section (simplified)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(room.category.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        room.category.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: categoryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${room.participantCount}', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_getTimeText(), style: TextStyle(fontSize: 12, color: room.isLive ? AppColors.error : Colors.grey[600], fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                        child: Text(room.isLive ? 'Join' : 'View', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
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
    // Use pulsating indicator for live rooms
    if (status == RoomStatus.live) {
      return const LiveIndicator(
        fontSize: 10,
        dotSize: 6,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      );
    }

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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

/// Image widget with retry and fallback behavior.
class _RetryingNetworkImage extends StatefulWidget {
  final String imageUrl;
  final String fallbackUrl;
  final BoxFit fit;
  final _OverlayTheme overlayTheme;

  const _RetryingNetworkImage({
    required this.imageUrl,
    required this.fallbackUrl,
    this.fit = BoxFit.cover,
    required this.overlayTheme,
  });

  @override
  State<_RetryingNetworkImage> createState() => _RetryingNetworkImageState();
}

class _RetryingNetworkImageState extends State<_RetryingNetworkImage> {
  int _attempt = 0;
  final int _maxAttempts = 2;
  bool _useFallback = false;
  bool _hasError = false;

  String get _currentUrl => _useFallback ? widget.fallbackUrl : widget.imageUrl;

  void _onError() {
    if (!_useFallback && _attempt < _maxAttempts) {
      _attempt++;
      // mark that an error occurred (show broken icon) while we retry
      if (mounted) setState(() => _hasError = true);
      // retry after small delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() {});
      });
    } else if (!_useFallback) {
      setState(() {
        _useFallback = true;
        _attempt = 0;
        _hasError = false; // allow fallback to show its own loading state
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: ValueKey('img_${_currentUrl}_a$_attempt'),
      imageUrl: _currentUrl,
      fit: widget.fit,
      imageBuilder: (context, imageProvider) {
        if (_hasError) {
          // clear error state when image successfully loads
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = false);
          });
        }
        return Image(image: imageProvider, fit: widget.fit);
      },
      placeholder: (context, url) => Container(
        color: widget.overlayTheme.primary.withOpacity(0.2),
        child: _hasError
            ? const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 36))
            : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
      ),
      errorWidget: (context, url, error) {
        // mark error and trigger retry/fallback logic
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hasError = true);
          _onError();
        });
        return Container(
          color: widget.overlayTheme.primary.withOpacity(0.25),
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 36),
          ),
        );
      },
    );
  }
}
