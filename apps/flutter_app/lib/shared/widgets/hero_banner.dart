import 'package:flutter/material.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';

/// A banner item for the hero carousel
class BannerItem {
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback? onAction;
  final List<Color> gradientColors;
  final IconData? icon;

  const BannerItem({
    required this.title,
    required this.subtitle,
    required this.actionText,
    this.onAction,
    required this.gradientColors,
    this.icon,
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
        color: Colors.white.withOpacity(0.15),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          // Decorative mic/speech icons
          if (item.icon != null)
            Positioned(
              right: 16,
              top: 16,
              child: Icon(
                item.icon,
                size: 70,
                color: Colors.white.withOpacity(0.2),
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
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.3,
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

  static BannerItem joinDebate({VoidCallback? onAction}) => BannerItem(
        title: 'Your Voice Matters',
        subtitle: 'Join live debates on trending topics and share your perspective with the world',
        actionText: 'Join Now',
        onAction: onAction,
        gradientColors: [AppColors.primary, AppColors.primaryDark],
        icon: Icons.mic,
      );

  static BannerItem startDebate({VoidCallback? onAction}) => BannerItem(
        title: 'Start a Debate',
        subtitle: 'Have a topic in mind? Create your own room and invite others to discuss',
        actionText: 'Create Room',
        onAction: onAction,
        gradientColors: [AppColors.accent, AppColors.accentDark],
        icon: Icons.record_voice_over,
      );

  static BannerItem trending({VoidCallback? onAction}) => BannerItem(
        title: 'Trending Now',
        subtitle: 'Hot topics are being discussed right now. Don\'t miss out on the conversation!',
        actionText: 'Explore',
        onAction: onAction,
        gradientColors: [AppColors.coral, AppColors.secondary],
        icon: Icons.local_fire_department,
      );

  static BannerItem community({VoidCallback? onAction}) => BannerItem(
        title: 'Growing Community',
        subtitle: 'Join thousands of debaters sharing ideas and perspectives every day',
        actionText: 'Learn More',
        onAction: onAction,
        gradientColors: [AppColors.secondaryDark, AppColors.secondary],
        icon: Icons.groups,
      );
}
