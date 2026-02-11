import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';

/// A header banner widget that replaces AppBar
/// Image is the background, text overlays on top with good contrast
class PageHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Color> gradientColors;
  final String? imageUrl;
  final List<String> fallbackImageUrls;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final double height;
  final bool showBackButton;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.gradientColors,
    this.imageUrl,
    this.fallbackImageUrls = const [],
    this.onBack,
    this.actions,
    this.height = 180,
    this.showBackButton = true,
  });

  @override
  State<PageHeader> createState() => _PageHeaderState();
}

class _PageHeaderState extends State<PageHeader> {
  late String? _displayImageUrl;

  @override
  void initState() {
    super.initState();
    _displayImageUrl = widget.imageUrl ??
        (widget.fallbackImageUrls.isNotEmpty
            ? widget.fallbackImageUrls[Random().nextInt(widget.fallbackImageUrls.length)]
            : null);
  }

  @override
  void didUpdateWidget(PageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _displayImageUrl = widget.imageUrl ??
          (widget.fallbackImageUrls.isNotEmpty
              ? widget.fallbackImageUrls[Random().nextInt(widget.fallbackImageUrls.length)]
              : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height + MediaQuery.of(context).padding.top,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with artistic filter
          if (_displayImageUrl != null)
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  1.5, -0.3, -0.3, 0, -40,
                  -0.3, 1.5, -0.3, 0, -40,
                  -0.3, -0.3, 1.5, 0, -40,
                  0, 0, 0, 1, 0,
                ]),
                child: CachedNetworkImage(
                  imageUrl: _displayImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: widget.gradientColors.first,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: widget.gradientColors.first,
                  ),
                ),
              ),
            )
          else
            Container(color: widget.gradientColors.first),

          // Saturation layer
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.gradientColors.first.withOpacity(0.6),
                  widget.gradientColors.last.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              backgroundBlendMode: BlendMode.saturation,
            ),
          ),

          // Color overlay - creates duotone effect
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.gradientColors.first.withOpacity(0.75),
                  widget.gradientColors.last.withOpacity(0.70),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              backgroundBlendMode: BlendMode.color,
            ),
          ),

          // Dark gradient from bottom for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.3, 1.0],
              ),
            ),
          ),

          // Screen highlight at top
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.transparent,
                ],
                center: Alignment.topLeft,
                radius: 1.2,
              ),
              backgroundBlendMode: BlendMode.screen,
            ),
          ),

          // Content
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with back button and actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      if (widget.showBackButton)
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      if (widget.actions != null) ...widget.actions!,
                    ],
                  ),
                ),

                const Spacer(),

                // Title and subtitle at bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 14,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Factory methods for common page headers
class PageHeaders {
  static const _profileImages = [
    'https://picsum.photos/seed/profile1/600/300',
    'https://picsum.photos/seed/profile2/600/300',
    'https://picsum.photos/seed/profile3/600/300',
  ];

  static const _friendsImages = [
    'https://picsum.photos/seed/friends1/600/300',
    'https://picsum.photos/seed/friends2/600/300',
    'https://picsum.photos/seed/friends3/600/300',
  ];

  static const _createRoomImages = [
    'https://picsum.photos/seed/create1/600/300',
    'https://picsum.photos/seed/create2/600/300',
    'https://picsum.photos/seed/create3/600/300',
  ];

  static const _settingsImages = [
    'https://picsum.photos/seed/settings1/600/300',
    'https://picsum.photos/seed/settings2/600/300',
    'https://picsum.photos/seed/settings3/600/300',
  ];

  static const _allRoomsImages = [
    'https://picsum.photos/seed/rooms1/600/300',
    'https://picsum.photos/seed/rooms2/600/300',
    'https://picsum.photos/seed/rooms3/600/300',
  ];

  static PageHeader profile({
    String? username,
    VoidCallback? onBack,
    List<Widget>? actions,
  }) =>
      PageHeader(
        title: 'Your Profile',
        subtitle: username != null ? 'Welcome back, $username!' : 'Manage your account',
        gradientColors: [AppColors.primary, AppColors.primaryDark],
        fallbackImageUrls: _profileImages,
        onBack: onBack,
        actions: actions,
      );

  static PageHeader friends({
    VoidCallback? onBack,
    List<Widget>? actions,
  }) =>
      PageHeader(
        title: 'Friends',
        subtitle: 'Connect with fellow debaters',
        gradientColors: [AppColors.accent, AppColors.accentDark],
        fallbackImageUrls: _friendsImages,
        onBack: onBack,
        actions: actions,
      );

  static PageHeader createRoom({
    VoidCallback? onBack,
  }) =>
      PageHeader(
        title: 'Create Room',
        subtitle: 'Start your own debate or discussion',
        gradientColors: [AppColors.secondary, AppColors.secondaryDark],
        fallbackImageUrls: _createRoomImages,
        onBack: onBack,
      );

  static PageHeader settings({
    VoidCallback? onBack,
  }) =>
      PageHeader(
        title: 'Settings',
        subtitle: 'Customize your experience',
        gradientColors: [AppColors.coral, const Color(0xFFE85D75)],
        fallbackImageUrls: _settingsImages,
        onBack: onBack,
      );

  static PageHeader allRooms({
    VoidCallback? onBack,
  }) =>
      PageHeader(
        title: 'All Rooms',
        subtitle: 'Browse live and upcoming debates',
        gradientColors: [AppColors.info, const Color(0xFF2563EB)],
        fallbackImageUrls: _allRoomsImages,
        onBack: onBack,
      );

  /// Room detail header - uses room's illustration
  static PageHeader roomDetail({
    required String title,
    required String categoryName,
    required String categoryIcon,
    required Color categoryColor,
    required bool isLive,
    String? illustrationUrl,
    VoidCallback? onBack,
    List<Widget>? actions,
  }) {
    final gradientColors = isLive
        ? [AppColors.error, const Color(0xFFDC2626)]
        : [categoryColor, categoryColor.withOpacity(0.8)];

    return PageHeader(
      title: title,
      subtitle: '$categoryIcon $categoryName${isLive ? ' • LIVE NOW' : ''}',
      gradientColors: gradientColors,
      imageUrl: illustrationUrl,
      fallbackImageUrls: [
        'https://picsum.photos/seed/${categoryName.toLowerCase()}1/600/300',
        'https://picsum.photos/seed/${categoryName.toLowerCase()}2/600/300',
      ],
      onBack: onBack,
      actions: actions,
      height: 200,
    );
  }
}
