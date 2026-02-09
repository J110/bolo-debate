import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/auth/presentation/providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bubbleController;

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final size = MediaQuery.of(context).size;
    
    // Show loading while checking auth state
    if (authState.isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            // Dark gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A0E17),
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 50,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/bolo_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return Scaffold(
      body: Stack(
        children: [
          // Dark gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0E17),
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ],
              ),
            ),
          ),
          
          // Animated floating bubbles
          AnimatedBuilder(
            animation: _bubbleController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _BubblePainter(
                  animationValue: _bubbleController.value,
                ),
              );
            },
          ),
          
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  
                  // Bolo Logo with glow
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 50,
                          spreadRadius: 15,
                        ),
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.2),
                          blurRadius: 80,
                          spreadRadius: 25,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/bolo_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Main title
                  Text(
                    'Welcome to',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Bolo',
                    style: GoogleFonts.nunito(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Tagline
                  Text(
                    'Voice your opinion on topics that matter',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Features
                  _FeatureItem(
                    icon: Icons.record_voice_over_rounded,
                    title: 'Live Audio Debates',
                    description: 'Join discussions on trending topics',
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 18),
                  _FeatureItem(
                    icon: Icons.people_alt_rounded,
                    title: 'Real People',
                    description: 'Connect with other like minded humans',
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 18),
                  _FeatureItem(
                    icon: Icons.shield_rounded,
                    title: 'Anonymous & Safe',
                    description: 'Express freely without revealing identity',
                    color: AppColors.lavenderDark,
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Get Started Button
                  _PrimaryButton(
                    text: 'Get Started',
                    onPressed: () => context.push('/auth/register'),
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Sign In Button
                  _SecondaryButton(
                    text: 'I already have an account',
                    onPressed: () => context.push('/auth/login'),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final double animationValue;

  _BubblePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final bubbles = [
      // Teal bubbles
      _Bubble(0.12, 0.08, 40, AppColors.primary.withOpacity(0.5)),
      _Bubble(0.88, 0.05, 30, AppColors.primaryLight.withOpacity(0.4)),
      _Bubble(0.08, 0.85, 25, AppColors.primary.withOpacity(0.35)),
      
      // Orange bubbles
      _Bubble(0.92, 0.18, 35, AppColors.secondary.withOpacity(0.45)),
      _Bubble(0.78, 0.9, 22, AppColors.secondaryLight.withOpacity(0.35)),
      _Bubble(0.15, 0.65, 18, AppColors.secondary.withOpacity(0.3)),
      
      // Purple/Lavender bubbles
      _Bubble(0.22, 0.15, 28, AppColors.lavender.withOpacity(0.5)),
      _Bubble(0.7, 0.12, 32, AppColors.lavenderDark.withOpacity(0.4)),
      _Bubble(0.85, 0.75, 20, AppColors.lavender.withOpacity(0.3)),
      
      // Coral accents
      _Bubble(0.05, 0.4, 15, AppColors.coral.withOpacity(0.45)),
      _Bubble(0.95, 0.55, 12, AppColors.coralLight.withOpacity(0.35)),
      
      // Small accent dots
      _Bubble(0.35, 0.05, 8, Colors.white.withOpacity(0.25)),
      _Bubble(0.6, 0.95, 10, Colors.white.withOpacity(0.2)),
      _Bubble(0.48, 0.08, 6, AppColors.primary.withOpacity(0.25)),
      _Bubble(0.03, 0.25, 10, Colors.white.withOpacity(0.15)),
      _Bubble(0.97, 0.4, 8, AppColors.secondary.withOpacity(0.25)),
    ];

    for (final bubble in bubbles) {
      // Animate position with gentle floating
      final offsetX = math.sin(animationValue * 2 * math.pi + bubble.x * 12) * 10;
      final offsetY = math.cos(animationValue * 2 * math.pi + bubble.y * 12) * 10;
      
      final center = Offset(
        size.width * bubble.x + offsetX,
        size.height * bubble.y + offsetY,
      );
      
      final paint = Paint()
        ..color = bubble.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, bubble.radius, paint);
      
      // Add subtle glow
      final glowPaint = Paint()
        ..color = bubble.color.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center, bubble.radius * 1.3, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _Bubble {
  final double x;
  final double y;
  final double radius;
  final Color color;

  _Bubble(this.x, this.y, this.radius, this.color);
}
