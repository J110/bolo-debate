import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';

/// A banner item for the hero carousel
class BannerItem {
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback? onAction;
  final List<Color> gradientColors;
  final IconData? icon;
  final String? imageUrl;

  const BannerItem({
    required this.title,
    required this.subtitle,
    required this.actionText,
    this.onAction,
    required this.gradientColors,
    this.icon,
    this.imageUrl,
  });
}

/// Hero banner widget that displays promotional content
/// Includes integrated header with app name and notification icon
class HeroBanner extends StatefulWidget {
  final List<BannerItem> items;
  final Duration autoPlayDuration;
  final VoidCallback? onNotificationTap;

  const HeroBanner({
    super.key,
    required this.items,
    this.autoPlayDuration = const Duration(seconds: 5),
    this.onNotificationTap,
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.items.length > 1) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    Future.delayed(widget.autoPlayDuration, () {
      if (mounted && widget.items.length > 1) {
        final nextPage = (_currentPage + 1) % widget.items.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        _startAutoPlay();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.items.isNotEmpty 
                ? widget.items[_currentPage].gradientColors.first
                : AppColors.primary,
            widget.items.isNotEmpty 
                ? widget.items[_currentPage].gradientColors.last
                : AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row with app name and notification
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bolo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    color: Colors.white,
                    onPressed: widget.onNotificationTap,
                  ),
                ),
              ],
            ),
          ),
          // Banner carousel
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _BannerCard(item: widget.items[index]),
                );
              },
            ),
          ),
          if (widget.items.length > 1) ...[
            const SizedBox(height: 12),
            _PageIndicator(
              count: widget.items.length,
              currentIndex: _currentPage,
              activeColor: Colors.white,
              inactiveColor: Colors.white.withOpacity(0.4),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final BannerItem item;

  const _BannerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with grayscale filter
          if (item.imageUrl != null)
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0,    0,    0,    1, 0,
              ]),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: item.gradientColors.first.withOpacity(0.3),
                ),
                errorWidget: (context, url, error) => Container(
                  color: item.gradientColors.first.withOpacity(0.3),
                ),
              ),
            ),
          // Gradient overlay for theme color
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  item.gradientColors.first.withOpacity(0.85),
                  item.gradientColors.last.withOpacity(0.75),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          // Subtle highlight gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.transparent,
                  Colors.black.withOpacity(0.1),
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Decorative elements
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.55,
                  child: Text(
                    item.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.3,
                      shadows: const [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                _ActionButton(
                  text: item.actionText,
                  onPressed: item.onAction,
                  gradientColors: item.gradientColors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;

  const _ActionButton({
    required this.text,
    this.onPressed,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: gradientColors.first,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: gradientColors.first,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Color? activeColor;
  final Color? inactiveColor;

  const _PageIndicator({
    required this.count,
    required this.currentIndex,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive 
                ? (activeColor ?? AppColors.primary) 
                : (inactiveColor ?? Colors.grey[300]),
          ),
        );
      }),
    );
  }
}

/// Pre-built banner configurations for Bolo Debate
class BoloBanners {
  BoloBanners._();

  // Curated Pixabay ILLUSTRATION URLs for banners - multiple per category for variety
  static const _voiceImages = [
    'https://cdn.pixabay.com/photo/2017/01/31/17/53/microphone-2025459_640.png',
    'https://cdn.pixabay.com/photo/2016/10/09/19/19/microphone-1726379_640.png',
    'https://cdn.pixabay.com/photo/2014/04/02/10/55/microphone-304176_640.png',
    'https://cdn.pixabay.com/photo/2013/07/12/18/20/microphone-153585_640.png',
    'https://cdn.pixabay.com/photo/2016/08/16/09/53/international-conference-1597531_640.jpg',
  ];

  static const _debateImages = [
    'https://cdn.pixabay.com/photo/2017/01/31/14/03/interview-2024328_640.png',
    'https://cdn.pixabay.com/photo/2018/03/22/02/37/speech-bubble-3249879_640.png',
    'https://cdn.pixabay.com/photo/2017/06/20/08/44/speaking-2422015_640.jpg',
    'https://cdn.pixabay.com/photo/2016/06/03/15/35/presentation-1433291_640.png',
    'https://cdn.pixabay.com/photo/2017/10/31/00/44/video-conference-2904716_640.png',
  ];

  static const _trendingImages = [
    'https://cdn.pixabay.com/photo/2017/06/10/07/18/list-2389219_640.png',
    'https://cdn.pixabay.com/photo/2016/06/03/15/35/business-1433291_640.png',
    'https://cdn.pixabay.com/photo/2016/03/26/13/09/cup-1280537_640.png',
    'https://cdn.pixabay.com/photo/2017/01/29/13/21/mobile-phone-2017658_640.png',
    'https://cdn.pixabay.com/photo/2016/11/19/15/40/chart-1839304_640.png',
  ];

  static const _communityImages = [
    'https://cdn.pixabay.com/photo/2017/01/31/20/53/network-2027147_640.png',
    'https://cdn.pixabay.com/photo/2016/11/08/05/26/woman-1807533_640.jpg',
    'https://cdn.pixabay.com/photo/2017/07/31/11/44/group-2557408_640.jpg',
    'https://cdn.pixabay.com/photo/2016/10/09/08/32/digital-marketing-1725340_640.jpg',
    'https://cdn.pixabay.com/photo/2019/10/09/07/28/development-4536630_640.png',
  ];

  /// Pick a random image from a list
  static String _randomImage(List<String> images) {
    final index = DateTime.now().microsecond % images.length;
    return images[index];
  }

  static BannerItem joinDebate({VoidCallback? onAction}) => BannerItem(
        title: 'Your Voice Matters',
        subtitle: 'Join live debates on trending topics and share your perspective',
        actionText: 'Join Now',
        onAction: onAction,
        gradientColors: [AppColors.primary, AppColors.primaryDark],
        imageUrl: _randomImage(_voiceImages),
      );

  static BannerItem startDebate({VoidCallback? onAction}) => BannerItem(
        title: 'Start a Debate',
        subtitle: 'Have a topic in mind? Create your own room and invite others',
        actionText: 'Create Room',
        onAction: onAction,
        gradientColors: [AppColors.accent, AppColors.accentDark],
        imageUrl: _randomImage(_debateImages),
      );

  static BannerItem trending({VoidCallback? onAction}) => BannerItem(
        title: 'Trending Now',
        subtitle: 'Hot topics are being discussed right now. Join the conversation!',
        actionText: 'Explore',
        onAction: onAction,
        gradientColors: [AppColors.coral, AppColors.secondary],
        imageUrl: _randomImage(_trendingImages),
      );

  static BannerItem community({VoidCallback? onAction}) => BannerItem(
        title: 'Growing Community',
        subtitle: 'Join thousands of debaters sharing ideas and perspectives',
        actionText: 'Learn More',
        onAction: onAction,
        gradientColors: [AppColors.secondaryDark, AppColors.secondary],
        imageUrl: _randomImage(_communityImages),
      );
}
