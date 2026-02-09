import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A meditative orbital audio visualizer with glowing orb and particle effects
class OrbitalVisualizer extends StatefulWidget {
  final bool isActive;
  final List<double> frequencyBands;
  final double size;
  
  const OrbitalVisualizer({
    super.key,
    this.isActive = false,
    this.frequencyBands = const [],
    this.size = 250,
  });

  @override
  State<OrbitalVisualizer> createState() => _OrbitalVisualizerState();
}

class _OrbitalVisualizerState extends State<OrbitalVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  
  // Smoothed frequency values for fluid animation
  List<double> _smoothedBands = List.filled(20, 0.1);
  
  @override
  void initState() {
    super.initState();
    
    // Slow, meditative rotation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    // Gentle pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    // Particle drift animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(OrbitalVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smooth interpolation of frequency bands
    if (widget.frequencyBands.isNotEmpty) {
      for (int i = 0; i < _smoothedBands.length && i < widget.frequencyBands.length; i++) {
        _smoothedBands[i] = _smoothedBands[i] * 0.7 + widget.frequencyBands[i] * 0.3;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationController,
          _pulseController,
          _particleController,
        ]),
        builder: (context, child) {
          final avgLevel = _smoothedBands.reduce((a, b) => a + b) / _smoothedBands.length;
          final normalizedLevel = (avgLevel * 2).clamp(0.0, 1.0);
          
          return CustomPaint(
            painter: _OrbitalPainter(
              rotationAngle: _rotationController.value * 2 * math.pi,
              pulseValue: _pulseController.value,
              particleProgress: _particleController.value,
              audioLevel: normalizedLevel,
              frequencyBands: _smoothedBands,
              isActive: widget.isActive,
            ),
            size: Size(widget.size, widget.size),
          );
        },
      ),
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  final double rotationAngle;
  final double pulseValue;
  final double particleProgress;
  final double audioLevel;
  final List<double> frequencyBands;
  final bool isActive;
  
  _OrbitalPainter({
    required this.rotationAngle,
    required this.pulseValue,
    required this.particleProgress,
    required this.audioLevel,
    required this.frequencyBands,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    // Background glow
    _drawBackgroundGlow(canvas, center, maxRadius);
    
    // Outer particles
    _drawParticles(canvas, center, maxRadius);
    
    // Orbital rings
    _drawOrbitalRings(canvas, center, maxRadius);
    
    // Frequency wave ring
    _drawFrequencyRing(canvas, center, maxRadius * 0.6);
    
    // Inner glowing orb
    _drawCentralOrb(canvas, center, maxRadius * 0.25);
    
    // Core bright spot
    _drawCoreSpot(canvas, center, maxRadius * 0.1);
  }
  
  void _drawBackgroundGlow(Canvas canvas, Offset center, double maxRadius) {
    final glowIntensity = 0.1 + (audioLevel * 0.15) + (pulseValue * 0.05);
    
    final gradient = RadialGradient(
      colors: [
        const Color(0xFF00FFFF).withOpacity(glowIntensity),
        const Color(0xFF00FFFF).withOpacity(glowIntensity * 0.5),
        const Color(0xFF00FFFF).withOpacity(0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: maxRadius),
      );
    
    canvas.drawCircle(center, maxRadius, paint);
  }
  
  void _drawParticles(Canvas canvas, Offset center, double maxRadius) {
    final random = math.Random(42); // Fixed seed for consistent particles
    final particleCount = 30;
    
    for (int i = 0; i < particleCount; i++) {
      final baseAngle = (i / particleCount) * 2 * math.pi;
      final angle = baseAngle + rotationAngle * (0.3 + random.nextDouble() * 0.4);
      
      // Distance varies with particle progress
      final baseDistance = 0.7 + random.nextDouble() * 0.25;
      final distanceWobble = math.sin(particleProgress * 2 * math.pi + i) * 0.05;
      final distance = (baseDistance + distanceWobble) * maxRadius;
      
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      // Particle size based on audio
      final baseSize = 1.0 + random.nextDouble() * 2.0;
      final audioBoost = audioLevel * 2.0;
      final particleSize = baseSize + audioBoost;
      
      // Particle opacity
      final opacity = (0.3 + random.nextDouble() * 0.5 + audioLevel * 0.3).clamp(0.0, 1.0);
      
      final paint = Paint()
        ..color = const Color(0xFF00FFFF).withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }
  
  void _drawOrbitalRings(Canvas canvas, Offset center, double maxRadius) {
    // Draw 3 orbital rings at different angles
    final ringRadii = [maxRadius * 0.75, maxRadius * 0.55, maxRadius * 0.85];
    final ringTilts = [0.2, -0.15, 0.1];
    final ringRotations = [rotationAngle, -rotationAngle * 0.7, rotationAngle * 0.5];
    
    for (int r = 0; r < ringRadii.length; r++) {
      final radius = ringRadii[r];
      final tilt = ringTilts[r];
      final rotation = ringRotations[r];
      
      final ringOpacity = (0.2 + audioLevel * 0.3).clamp(0.0, 0.6);
      
      final paint = Paint()
        ..color = const Color(0xFF00FFFF).withOpacity(ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + audioLevel * 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
      // Draw elliptical ring (3D effect)
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * 2 * (0.3 + tilt.abs()),
      );
      
      canvas.drawOval(rect, paint);
      canvas.restore();
    }
  }
  
  void _drawFrequencyRing(Canvas canvas, Offset center, double radius) {
    if (frequencyBands.isEmpty) return;
    
    final path = Path();
    final bandCount = frequencyBands.length;
    
    for (int i = 0; i <= bandCount; i++) {
      final index = i % bandCount;
      final angle = (i / bandCount) * 2 * math.pi - math.pi / 2;
      
      // Frequency affects radius
      final freqValue = frequencyBands[index];
      final dynamicRadius = radius + (freqValue * radius * 0.4);
      
      final x = center.dx + math.cos(angle + rotationAngle * 0.2) * dynamicRadius;
      final y = center.dy + math.sin(angle + rotationAngle * 0.2) * dynamicRadius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    // Glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFF00FFFF).withOpacity(0.3 + audioLevel * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 + audioLevel * 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawPath(path, glowPaint);
    
    // Core line
    final linePaint = Paint()
      ..color = const Color(0xFF00FFFF).withOpacity(0.6 + audioLevel * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawPath(path, linePaint);
  }
  
  void _drawCentralOrb(Canvas canvas, Offset center, double radius) {
    // Pulsing size
    final pulseRadius = radius * (0.9 + pulseValue * 0.2 + audioLevel * 0.3);
    
    // Outer glow
    final outerGlow = RadialGradient(
      colors: [
        const Color(0xFF00FFFF).withOpacity(0.4 + audioLevel * 0.3),
        const Color(0xFF00FFFF).withOpacity(0.1),
        const Color(0xFF00FFFF).withOpacity(0),
      ],
      stops: const [0.3, 0.7, 1.0],
    );
    
    final glowPaint = Paint()
      ..shader = outerGlow.createShader(
        Rect.fromCircle(center: center, radius: pulseRadius * 2),
      );
    
    canvas.drawCircle(center, pulseRadius * 2, glowPaint);
    
    // Main orb gradient
    final orbGradient = RadialGradient(
      colors: [
        const Color(0xFF004D4D),
        const Color(0xFF006666).withOpacity(0.8),
        const Color(0xFF00FFFF).withOpacity(0.4),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    
    final orbPaint = Paint()
      ..shader = orbGradient.createShader(
        Rect.fromCircle(center: center, radius: pulseRadius),
      );
    
    canvas.drawCircle(center, pulseRadius, orbPaint);
    
    // Edge highlight
    final edgePaint = Paint()
      ..color = const Color(0xFF00FFFF).withOpacity(0.5 + audioLevel * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(center, pulseRadius, edgePaint);
  }
  
  void _drawCoreSpot(Canvas canvas, Offset center, double radius) {
    final coreRadius = radius * (0.8 + audioLevel * 0.4);
    
    final coreGradient = RadialGradient(
      colors: [
        Colors.white.withOpacity(0.9),
        const Color(0xFF00FFFF).withOpacity(0.6),
        const Color(0xFF00FFFF).withOpacity(0),
      ],
      stops: const [0.0, 0.4, 1.0],
    );
    
    final paint = Paint()
      ..shader = coreGradient.createShader(
        Rect.fromCircle(center: center, radius: coreRadius),
      );
    
    canvas.drawCircle(center, coreRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
           oldDelegate.pulseValue != pulseValue ||
           oldDelegate.particleProgress != particleProgress ||
           oldDelegate.audioLevel != audioLevel;
  }
}
