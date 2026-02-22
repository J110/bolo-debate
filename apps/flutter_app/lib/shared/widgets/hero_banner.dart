import 'dart:math';
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
  final List<String> imageUrls; // List of URLs for random selection

  const BannerItem({
    required this.title,
    required this.subtitle,
    required this.actionText,
    this.onAction,
    required this.gradientColors,
    this.icon,
    this.imageUrls = const [],
  });
  
  /// Get a random image URL from the list
  String? get randomImageUrl {
    if (imageUrls.isEmpty) return null;
    final random = Random();
    return imageUrls[random.nextInt(imageUrls.length)];
  }
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
                  'Bolaa',
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

class _BannerCard extends StatefulWidget {
  final BannerItem item;

  const _BannerCard({required this.item});

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard> {
  late String? _selectedImageUrl;

  @override
  void initState() {
    super.initState();
    // Select random image when card is created
    _selectedImageUrl = widget.item.randomImageUrl;
  }

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
          // Background abstract image - enhanced for artistic look
          if (_selectedImageUrl != null)
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.35, 0.35, 0.35, 0, -20,  // High contrast grayscale
                0.35, 0.35, 0.35, 0, -20,
                0.35, 0.35, 0.35, 0, -20,
                0,    0,    0,    1,   0,
              ]),
              child: CachedNetworkImage(
                imageUrl: _selectedImageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: widget.item.gradientColors.first.withOpacity(0.3),
                ),
                errorWidget: (context, url, error) => Container(
                  color: widget.item.gradientColors.first.withOpacity(0.3),
                ),
              ),
            ),
          // Primary color overlay with color blend mode
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.item.gradientColors.first.withOpacity(0.90),
                  widget.item.gradientColors.last.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              backgroundBlendMode: BlendMode.color,
            ),
          ),
          // Multiply layer for depth
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.item.gradientColors.first.withOpacity(0.45),
                  widget.item.gradientColors.last.withOpacity(0.55),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              backgroundBlendMode: BlendMode.multiply,
            ),
          ),
          // Soft light highlight for artistic glow
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.transparent,
                  widget.item.gradientColors.first.withOpacity(0.15),
                ],
                stops: const [0.0, 0.4, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              backgroundBlendMode: BlendMode.softLight,
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
                  widget.item.title,
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
                    widget.item.subtitle,
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
                  text: widget.item.actionText,
                  onPressed: widget.item.onAction,
                  gradientColors: widget.item.gradientColors,
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

/// Pre-built banner configurations for Bolaa Debate
class BoloBanners {
  BoloBanners._();

  // Use Lorem Picsum for reliable image loading (no hotlink restrictions)
  // These provide abstract/artistic images with seed for consistency
  static const _voiceImages = [
    'https://picsum.photos/seed/voice1/640/400',
    'https://picsum.photos/seed/voice2/640/400',
    'https://picsum.photos/seed/voice3/640/400',
    'https://picsum.photos/seed/voice4/640/400',
    'https://picsum.photos/seed/voice5/640/400',
  ];

  static const _debateImages = [
    'https://picsum.photos/seed/debate1/640/400',
    'https://picsum.photos/seed/debate2/640/400',
    'https://picsum.photos/seed/debate3/640/400',
    'https://picsum.photos/seed/debate4/640/400',
    'https://picsum.photos/seed/debate5/640/400',
  ];

  static const _trendingImages = [
    'https://picsum.photos/seed/trend1/640/400',
    'https://picsum.photos/seed/trend2/640/400',
    'https://picsum.photos/seed/trend3/640/400',
    'https://picsum.photos/seed/trend4/640/400',
    'https://picsum.photos/seed/trend5/640/400',
  ];

  static const _communityImages = [
    'https://picsum.photos/seed/community1/640/400',
    'https://picsum.photos/seed/community2/640/400',
    'https://picsum.photos/seed/community3/640/400',
    'https://picsum.photos/seed/community4/640/400',
    'https://picsum.photos/seed/community5/640/400',
  ];

  static BannerItem joinDebate({VoidCallback? onAction}) => BannerItem(
        title: 'Your Voice Matters',
        subtitle: 'Join live debates on trending topics and share your perspective',
        actionText: 'Join Now',
        onAction: onAction,
        gradientColors: [AppColors.primary, AppColors.primaryDark],
        imageUrls: _voiceImages,
      );

  static BannerItem startDebate({VoidCallback? onAction}) => BannerItem(
        title: 'Start a Debate',
        subtitle: 'Have a topic in mind? Create your own room and invite others',
        actionText: 'Create Room',
        onAction: onAction,
        gradientColors: [AppColors.accent, AppColors.accentDark],
        imageUrls: _debateImages,
      );

  static BannerItem trending({VoidCallback? onAction}) => BannerItem(
        title: 'Trending Now',
        subtitle: 'Hot topics are being discussed right now. Join the conversation!',
        actionText: 'Explore',
        onAction: onAction,
        gradientColors: [AppColors.coral, AppColors.secondary],
        imageUrls: _trendingImages,
      );

  static BannerItem community({VoidCallback? onAction}) => BannerItem(
        title: 'Growing Community',
        subtitle: 'Join thousands of debaters sharing ideas and perspectives',
        actionText: 'Learn More',
        onAction: onAction,
        gradientColors: [AppColors.secondaryDark, AppColors.secondary],
        imageUrls: _communityImages,
      );
}
