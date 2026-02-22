import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  
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
    _usernameController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authStateProvider.notifier).login(
            _usernameController.text.trim(),
          );

      if (mounted) {
        setState(() => _isLoading = false);
        final authState = ref.read(authStateProvider);
        
        if (authState.error != null) {
          // Check if user doesn't exist - guide them to register
          final error = authState.error!;
          if (error.toLowerCase().contains('not found') || 
              error.toLowerCase().contains('user') ||
              error.toLowerCase().contains('404')) {
            _showUserNotFoundDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        // If login succeeded, router will automatically redirect to /home
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showUserNotFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'User not found',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'No account exists with this username. Would you like to create one?',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/auth/register');
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
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
            child: Column(
              children: [
                // Top section with logo and greeting
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with glow effect
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.2),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/bolo_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Main greeting text
                      Text(
                        "Let's get you",
                        style: GoogleFonts.nunito(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        'signed in!',
                        style: GoogleFonts.nunito(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom white card with form
                Expanded(
                  flex: 6,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header text
                            Text(
                              "You don't have an account yet?",
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => context.push('/auth/register'),
                              child: Text(
                                'Sign Up',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Username field
                            TextFormField(
                              controller: _usernameController,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: AppColors.textPrimaryLight,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter your username',
                                hintStyle: GoogleFonts.nunito(
                                  color: Colors.grey[400],
                                ),
                                prefixIcon: Icon(
                                  Icons.person_outline_rounded,
                                  color: Colors.grey[400],
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Forgot username link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Show info dialog
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        'Username Recovery',
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        'No worries! Just enter any username to continue. Your username helps others identify you in debates.',
                                        style: GoogleFonts.nunito(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Got it!'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot username?',
                                  style: GoogleFonts.nunito(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Sign In button with wave shape
                            _SignInButton(
                              isLoading: _isLoading,
                              onPressed: _login,
                            ),
                            // Social login intentionally hidden for review build
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
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

class _SignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.backgroundDark,
              Color(0xFF1E293B),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.backgroundDark.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: CustomPaint(
            painter: _WaveButtonPainter(),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Sign In',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.4,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.6,
      size.width,
      size.height * 0.4,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Icon(icon, color: color, size: 28),
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
      _Bubble(0.15, 0.12, 35, AppColors.primary.withOpacity(0.6)),
      _Bubble(0.85, 0.08, 25, AppColors.primaryLight.withOpacity(0.5)),
      _Bubble(0.1, 0.35, 20, AppColors.primary.withOpacity(0.4)),
      
      // Orange bubbles
      _Bubble(0.9, 0.25, 30, AppColors.secondary.withOpacity(0.5)),
      _Bubble(0.75, 0.4, 18, AppColors.secondaryLight.withOpacity(0.4)),
      
      // Purple/Lavender bubbles
      _Bubble(0.2, 0.22, 22, AppColors.lavender.withOpacity(0.6)),
      _Bubble(0.65, 0.15, 28, AppColors.lavenderDark.withOpacity(0.5)),
      
      // Coral accents
      _Bubble(0.05, 0.18, 15, AppColors.coral.withOpacity(0.5)),
      _Bubble(0.95, 0.35, 12, AppColors.coralLight.withOpacity(0.4)),
      
      // Small accent dots
      _Bubble(0.3, 0.08, 8, Colors.white.withOpacity(0.3)),
      _Bubble(0.55, 0.3, 10, Colors.white.withOpacity(0.2)),
      _Bubble(0.45, 0.12, 6, AppColors.primary.withOpacity(0.3)),
    ];

    for (final bubble in bubbles) {
      // Animate position slightly
      final offsetX = math.sin(animationValue * 2 * math.pi + bubble.x * 10) * 8;
      final offsetY = math.cos(animationValue * 2 * math.pi + bubble.y * 10) * 8;
      
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
        ..color = bubble.color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(center, bubble.radius * 1.2, glowPaint);
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
