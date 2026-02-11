import 'package:flutter/material.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';

/// A pulsating LIVE indicator widget with ripple/ping effect
/// Used throughout the app to show live status with animation
class LiveIndicator extends StatefulWidget {
  final double fontSize;
  final double dotSize;
  final bool showLabel;
  final Color? backgroundColor;
  final EdgeInsets padding;

  const LiveIndicator({
    super.key,
    this.fontSize = 10,
    this.dotSize = 6,
    this.showLabel = true,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  State<LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<LiveIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rippleController1;
  late AnimationController _rippleController2;
  late AnimationController _rippleController3;

  @override
  void initState() {
    super.initState();
    
    // Three ripple animations staggered
    _rippleController1 = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _rippleController2 = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rippleController3 = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Stagger the ripples
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _rippleController2.repeat();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _rippleController3.repeat();
    });
  }

  @override
  void dispose() {
    _rippleController1.dispose();
    _rippleController2.dispose();
    _rippleController3.dispose();
    super.dispose();
  }

  Widget _buildRipple(AnimationController controller, double maxScale) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + (controller.value * maxScale);
        final opacity = (1.0 - controller.value) * 0.4;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4 * scale),
              border: Border.all(
                color: (widget.backgroundColor ?? AppColors.error).withOpacity(opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.backgroundColor ?? AppColors.error;
    
    return SizedBox(
      width: 65,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ripple rings
          Positioned.fill(
            child: _buildRipple(_rippleController1, 0.6),
          ),
          Positioned.fill(
            child: _buildRipple(_rippleController2, 0.6),
          ),
          Positioned.fill(
            child: _buildRipple(_rippleController3, 0.6),
          ),
          
          // Main button
          Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                if (widget.showLabel) ...[
                  SizedBox(width: widget.dotSize * 0.7),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A smaller, chip-style live indicator for use in lists/cards
class LiveChip extends StatefulWidget {
  final double fontSize;
  final Color? color;

  const LiveChip({
    super.key,
    this.fontSize = 10,
    this.color,
  });

  @override
  State<LiveChip> createState() => _LiveChipState();
}

class _LiveChipState extends State<LiveChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.error;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15 + (_pulseAnimation.value * 0.1)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(_pulseAnimation.value),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color.withOpacity(_pulseAnimation.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(_pulseAnimation.value * 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  color: color,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Minimal pulsating dot only (no label, no background)
class PulsatingDot extends StatefulWidget {
  final double size;
  final Color color;

  const PulsatingDot({
    super.key,
    this.size = 8,
    this.color = AppColors.error,
  });

  @override
  State<PulsatingDot> createState() => _PulsatingDotState();
}

class _PulsatingDotState extends State<PulsatingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.6),
                blurRadius: widget.size * 0.8,
                spreadRadius: widget.size * 0.2,
              ),
            ],
          ),
        );
      },
    );
  }
}
