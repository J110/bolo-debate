import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bolo_debate/core/theme/app_theme.dart';
import 'package:bolo_debate/features/auth/presentation/providers/auth_provider.dart';
import 'package:bolo_debate/features/home/presentation/providers/data_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _selectedRegionId;
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  
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
    _displayNameController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String username) async {
    if (username.length < 3) {
      setState(() {
        _isUsernameAvailable = null;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    final available = await ref.read(authStateProvider.notifier).checkUsername(username);

    if (mounted) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = available;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUsernameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please choose an available username',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await ref.read(authStateProvider.notifier).register(
          username: _usernameController.text.trim(),
          displayName: _displayNameController.text.trim(),
          regionId: _selectedRegionId,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      final error = ref.read(authStateProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final regionsAsync = ref.watch(regionsProvider);

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
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with glow effect
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 50,
                              spreadRadius: 15,
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
                      const SizedBox(height: 20),
                      // Main greeting text
                      Text(
                        'Join the',
                        style: GoogleFonts.nunito(
                          fontSize: 26,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        'conversation!',
                        style: GoogleFonts.nunito(
                          fontSize: 30,
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
                  flex: 7,
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
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header text
                            Text(
                              'Already have an account?',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => context.push('/auth/login'),
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Username field
                            _buildTextField(
                              controller: _usernameController,
                              hint: 'Choose a username',
                              icon: Icons.alternate_email_rounded,
                              onChanged: _checkUsername,
                              suffix: _isCheckingUsername
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : _isUsernameAvailable == null
                                      ? null
                                      : Icon(
                                          _isUsernameAvailable!
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_rounded,
                                          color: _isUsernameAvailable!
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a username';
                                }
                                if (value.length < 3) {
                                  return 'Username must be at least 3 characters';
                                }
                                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                                  return 'Only letters, numbers, and underscores';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            
                            // Display name field
                            _buildTextField(
                              controller: _displayNameController,
                              hint: 'Display name',
                              icon: Icons.person_outline_rounded,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a display name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            
                            // Region dropdown
                            regionsAsync.when(
                              data: (regions) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedRegionId,
                                  decoration: InputDecoration(
                                    hintText: 'Select your region (Optional)',
                                    hintStyle: GoogleFonts.nunito(
                                      color: Colors.grey[400],
                                    ),
                                    prefixIcon: Icon(
                                      Icons.location_on_outlined,
                                      color: Colors.grey[400],
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                  dropdownColor: Colors.white,
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        'Select your region',
                                        style: GoogleFonts.nunito(
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                    ...regions.map((region) => DropdownMenuItem(
                                          value: region.id,
                                          child: Text(
                                            '${region.name}, ${region.state}',
                                            style: GoogleFonts.nunito(),
                                          ),
                                        )),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedRegionId = value);
                                  },
                                ),
                              ),
                              loading: () => Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                              error: (_, __) => Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Failed to load regions',
                                  style: GoogleFonts.nunito(color: Colors.grey[500]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Info card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.1),
                                    AppColors.secondary.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.shield_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Your identity remains anonymous. Only your display name is visible.',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Create Account button
                            _CreateAccountButton(
                              isLoading: _isLoading,
                              onPressed: _register,
                            ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    Widget? suffix,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.nunito(
        fontSize: 16,
        color: AppColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
          color: Colors.grey[400],
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.grey[400],
        ),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: suffix,
              )
            : null,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class _CreateAccountButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CreateAccountButton({
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
                      'Create Account',
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
      ..color = AppColors.secondary.withOpacity(0.15)
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

class _BubblePainter extends CustomPainter {
  final double animationValue;

  _BubblePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final bubbles = [
      // Teal bubbles
      _Bubble(0.15, 0.06, 28, AppColors.primary.withOpacity(0.6)),
      _Bubble(0.85, 0.04, 22, AppColors.primaryLight.withOpacity(0.5)),
      _Bubble(0.1, 0.18, 16, AppColors.primary.withOpacity(0.4)),
      
      // Orange bubbles
      _Bubble(0.9, 0.12, 25, AppColors.secondary.withOpacity(0.5)),
      _Bubble(0.75, 0.22, 14, AppColors.secondaryLight.withOpacity(0.4)),
      
      // Purple/Lavender bubbles
      _Bubble(0.2, 0.1, 18, AppColors.lavender.withOpacity(0.6)),
      _Bubble(0.65, 0.08, 24, AppColors.lavenderDark.withOpacity(0.5)),
      
      // Coral accents
      _Bubble(0.05, 0.1, 12, AppColors.coral.withOpacity(0.5)),
      _Bubble(0.95, 0.2, 10, AppColors.coralLight.withOpacity(0.4)),
      
      // Small accent dots
      _Bubble(0.3, 0.04, 6, Colors.white.withOpacity(0.3)),
      _Bubble(0.55, 0.15, 8, Colors.white.withOpacity(0.2)),
    ];

    for (final bubble in bubbles) {
      // Animate position slightly
      final offsetX = math.sin(animationValue * 2 * math.pi + bubble.x * 10) * 6;
      final offsetY = math.cos(animationValue * 2 * math.pi + bubble.y * 10) * 6;
      
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
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
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
