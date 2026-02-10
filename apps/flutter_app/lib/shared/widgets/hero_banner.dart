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
/// Can be extended to a carousel in the future
class HeroBanner extends StatefulWidget {
  final List<BannerItem> items;
  final Duration autoPlayDuration;

  const HeroBanner({
    super.key,
    required this.items,
    this.autoPlayDuration = const Duration(seconds: 5),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      height: 180,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                return _BannerCard(item: widget.items[index]);
              },
            ),
          ),
          if (widget.items.length > 1) ...[
            const SizedBox(height: 8),
            _PageIndicator(
              count: widget.items.length,
              currentIndex: _currentPage,
            ),
          ],
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
        gradient: LinearGradient(
          colors: item.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: item.gradientColors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          // Decorative mic/speech icons
          if (item.icon != null)
            Positioned(
              right: 20,
              top: 20,
              child: Icon(
                item.icon,
                size: 80,
                color: Colors.white.withOpacity(0.15),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
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

  const _PageIndicator({
    required this.count,
    required this.currentIndex,
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
            color: isActive ? AppColors.primary : Colors.grey[300],
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
