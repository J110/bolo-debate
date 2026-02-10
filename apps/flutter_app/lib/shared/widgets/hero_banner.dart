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

  // Curated Pixabay ILLUSTRATION URLs for banners - verified working URLs
  static const _voiceImages = [
    'https://cdn.pixabay.com/photo/2016/11/23/14/37/audio-1853532_640.jpg',
    'https://cdn.pixabay.com/photo/2016/11/22/19/17/buildings-1850129_640.jpg',
    'https://cdn.pixabay.com/photo/2018/09/27/09/22/artificial-intelligence-3706562_640.jpg',
    'https://cdn.pixabay.com/photo/2017/03/23/09/34/artificial-intelligence-2167835_640.jpg',
    'https://cdn.pixabay.com/photo/2016/12/29/18/44/blog-1939451_640.jpg',
  ];

  static const _debateImages = [
    'https://cdn.pixabay.com/photo/2018/03/10/12/00/teamwork-3213924_640.jpg',
    'https://cdn.pixabay.com/photo/2017/08/10/08/47/laptop-2620118_640.jpg',
    'https://cdn.pixabay.com/photo/2015/01/08/18/27/startup-593341_640.jpg',
    'https://cdn.pixabay.com/photo/2016/11/29/06/18/home-office-1867761_640.jpg',
    'https://cdn.pixabay.com/photo/2019/04/14/10/27/book-4126483_640.jpg',
  ];

  static const _trendingImages = [
    'https://cdn.pixabay.com/photo/2016/11/27/21/42/stock-1863880_640.jpg',
    'https://cdn.pixabay.com/photo/2017/07/10/23/43/question-mark-2492009_640.jpg',
    'https://cdn.pixabay.com/photo/2018/05/18/15/30/web-design-3411373_640.jpg',
    'https://cdn.pixabay.com/photo/2016/10/09/08/32/digital-marketing-1725340_640.jpg',
    'https://cdn.pixabay.com/photo/2017/10/10/21/47/computer-2838921_640.jpg',
  ];

  static const _communityImages = [
    'https://cdn.pixabay.com/photo/2017/08/06/22/01/people-2596150_640.jpg',
    'https://cdn.pixabay.com/photo/2019/10/09/07/28/development-4536630_640.jpg',
    'https://cdn.pixabay.com/photo/2017/01/14/10/56/people-1979261_640.jpg',
    'https://cdn.pixabay.com/photo/2016/02/19/11/53/networking-1209738_640.jpg',
    'https://cdn.pixabay.com/photo/2016/06/03/13/57/digital-marketing-1433427_640.jpg',
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
