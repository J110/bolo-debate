import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A sophisticated meditative audio visualizer with multiple layered effects
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
  late AnimationController _waveController;
  late AnimationController _secondaryRotation;
  
  // Smoothed frequency values for fluid animation
  List<double> _smoothedBands = List.filled(20, 0.1);
  
  @override
  void initState() {
    super.initState();
    
    // Primary slow rotation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    
    // Gentle pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    
    // Particle drift animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
    
    // Wave expansion animation
    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    // Secondary counter-rotation
    _secondaryRotation = AnimationController(
      duration: const Duration(seconds: 45),
      vsync: this,
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    _secondaryRotation.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(OrbitalVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.frequencyBands.isNotEmpty) {
      for (int i = 0; i < _smoothedBands.length && i < widget.frequencyBands.length; i++) {
        _smoothedBands[i] = _smoothedBands[i] * 0.6 + widget.frequencyBands[i] * 0.4;
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
          _waveController,
          _secondaryRotation,
        ]),
        builder: (context, child) {
          final avgLevel = _smoothedBands.reduce((a, b) => a + b) / _smoothedBands.length;
          final normalizedLevel = (avgLevel * 2.5).clamp(0.0, 1.0);
          
          return CustomPaint(
            painter: _CosmicVisualizerPainter(
              rotationAngle: _rotationController.value * 2 * math.pi,
              secondaryAngle: _secondaryRotation.value * 2 * math.pi,
              pulseValue: _pulseController.value,
              particleProgress: _particleController.value,
              waveProgress: _waveController.value,
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

class _CosmicVisualizerPainter extends CustomPainter {
  final double rotationAngle;
  final double secondaryAngle;
  final double pulseValue;
  final double particleProgress;
  final double waveProgress;
  final double audioLevel;
  final List<double> frequencyBands;
  final bool isActive;
  
  // Color palette - cosmic theme
  static const Color primaryCyan = Color(0xFF00FFFF);
  static const Color deepPurple = Color(0xFF8B5CF6);
  static const Color magenta = Color(0xFFFF006E);
  static const Color electricBlue = Color(0xFF0066FF);
  static const Color teal = Color(0xFF14B8A6);
  
  _CosmicVisualizerPainter({
    required this.rotationAngle,
    required this.secondaryAngle,
    required this.pulseValue,
    required this.particleProgress,
    required this.waveProgress,
    required this.audioLevel,
    required this.frequencyBands,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    // Layer 1: Deep space nebula background
    _drawNebulaBackground(canvas, center, maxRadius);
    
    // Layer 2: Outer aurora waves
    _drawAuroraWaves(canvas, center, maxRadius);
    
    // Layer 3: Distant star field (tiny particles)
    _drawStarField(canvas, center, maxRadius);
    
    // Layer 4: Energy ripples expanding outward
    _drawEnergyRipples(canvas, center, maxRadius);
    
    // Layer 5: Outer particle cloud
    _drawParticleCloud(canvas, center, maxRadius, 0.85, 0.95, 50);
    
    // Layer 6: Sacred geometry rings
    _drawSacredGeometry(canvas, center, maxRadius);
    
    // Layer 7: Multiple orbital rings with varying properties
    _drawOrbitalSystem(canvas, center, maxRadius);
    
    // Layer 8: Inner particle layer
    _drawParticleCloud(canvas, center, maxRadius, 0.5, 0.7, 30);
    
    // Layer 9: Frequency-reactive plasma field
    _drawPlasmaField(canvas, center, maxRadius * 0.55);
    
    // Layer 10: Inner energy tendrils
    _drawEnergyTendrils(canvas, center, maxRadius * 0.45);
    
    // Layer 11: Central orb with multiple layers
    _drawCentralOrbSystem(canvas, center, maxRadius * 0.3);
    
    // Layer 12: Inner glow halo
    _drawInnerHalo(canvas, center, maxRadius * 0.2);
    
    // Layer 13: Core with highlight
    _drawCore(canvas, center, maxRadius * 0.12);
    
    // Layer 14: Lens flare accents
    _drawLensFlares(canvas, center, maxRadius);
  }
  
  void _drawNebulaBackground(Canvas canvas, Offset center, double maxRadius) {
    final baseIntensity = 0.08 + (audioLevel * 0.12) + (pulseValue * 0.04);
    
    // Multi-color nebula gradient
    final gradient = RadialGradient(
      colors: [
        deepPurple.withOpacity(baseIntensity * 0.8),
        magenta.withOpacity(baseIntensity * 0.4),
        primaryCyan.withOpacity(baseIntensity * 0.6),
        electricBlue.withOpacity(baseIntensity * 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      center: Alignment(
        math.sin(rotationAngle * 0.5) * 0.3,
        math.cos(rotationAngle * 0.5) * 0.3,
      ),
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: maxRadius),
      );
    
    canvas.drawCircle(center, maxRadius, paint);
  }
  
  void _drawAuroraWaves(Canvas canvas, Offset center, double maxRadius) {
    final random = math.Random(123);
    
    for (int wave = 0; wave < 3; wave++) {
      final path = Path();
      final waveOffset = wave * 0.3;
      final baseRadius = maxRadius * (0.7 + wave * 0.1);
      
      for (int i = 0; i <= 60; i++) {
        final angle = (i / 60) * 2 * math.pi;
        final noiseValue = math.sin(angle * 4 + rotationAngle + waveOffset) * 0.1 +
                          math.sin(angle * 7 - particleProgress * 2 * math.pi) * 0.05;
        final audioInfluence = audioLevel * math.sin(angle * 3 + rotationAngle * 2) * 0.15;
        
        final r = baseRadius * (1 + noiseValue + audioInfluence);
        final x = center.dx + math.cos(angle) * r;
        final y = center.dy + math.sin(angle) * r;
        
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      
      final colors = [primaryCyan, deepPurple, magenta];
      final opacity = (0.08 + audioLevel * 0.12 - wave * 0.02).clamp(0.0, 0.25);
      
      final paint = Paint()
        ..color = colors[wave % 3].withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + audioLevel * 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      
      canvas.drawPath(path, paint);
    }
  }
  
  void _drawStarField(Canvas canvas, Offset center, double maxRadius) {
    final random = math.Random(999);
    
    for (int i = 0; i < 80; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = 0.3 + random.nextDouble() * 0.7;
      final twinkle = math.sin(particleProgress * 2 * math.pi * (1 + random.nextDouble()) + i) * 0.5 + 0.5;
      
      final x = center.dx + math.cos(angle + rotationAngle * 0.1) * distance * maxRadius;
      final y = center.dy + math.sin(angle + rotationAngle * 0.1) * distance * maxRadius;
      
      final starSize = (0.5 + random.nextDouble() * 1.5) * (0.7 + twinkle * 0.3 + audioLevel * 0.5);
      final opacity = (0.3 + twinkle * 0.5 + audioLevel * 0.2).clamp(0.0, 1.0);
      
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, starSize);
      
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }
  
  void _drawEnergyRipples(Canvas canvas, Offset center, double maxRadius) {
    for (int i = 0; i < 4; i++) {
      final ripplePhase = (waveProgress + i * 0.25) % 1.0;
      final rippleRadius = maxRadius * (0.2 + ripplePhase * 0.7);
      final opacity = (1 - ripplePhase) * (0.15 + audioLevel * 0.2);
      
      final paint = Paint()
        ..color = primaryCyan.withOpacity(opacity.clamp(0.0, 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + audioLevel * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(center, rippleRadius, paint);
    }
  }
  
  void _drawParticleCloud(Canvas canvas, Offset center, double maxRadius, 
                          double minDist, double maxDist, int count) {
    final random = math.Random(42 + (minDist * 100).toInt());
    
    for (int i = 0; i < count; i++) {
      final baseAngle = (i / count) * 2 * math.pi;
      final angleOffset = rotationAngle * (0.2 + random.nextDouble() * 0.3) * (random.nextBool() ? 1 : -1);
      final angle = baseAngle + angleOffset;
      
      final baseDistance = minDist + random.nextDouble() * (maxDist - minDist);
      final breathe = math.sin(particleProgress * 2 * math.pi + i * 0.5) * 0.03;
      final distance = (baseDistance + breathe + audioLevel * 0.05) * maxRadius;
      
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      // Vary particle size based on position and audio
      final baseSize = 1.0 + random.nextDouble() * 2.5;
      final audioBoost = audioLevel * 2.5;
      final pulseEffect = pulseValue * 0.5;
      final particleSize = baseSize + audioBoost + pulseEffect;
      
      // Color variation
      final colorPhase = (i / count + rotationAngle / (2 * math.pi)) % 1.0;
      Color particleColor;
      if (colorPhase < 0.33) {
        particleColor = Color.lerp(primaryCyan, deepPurple, colorPhase * 3)!;
      } else if (colorPhase < 0.66) {
        particleColor = Color.lerp(deepPurple, magenta, (colorPhase - 0.33) * 3)!;
      } else {
        particleColor = Color.lerp(magenta, primaryCyan, (colorPhase - 0.66) * 3)!;
      }
      
      final opacity = (0.4 + random.nextDouble() * 0.4 + audioLevel * 0.3).clamp(0.0, 1.0);
      
      final paint = Paint()
        ..color = particleColor.withOpacity(opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particleSize * 0.8);
      
      canvas.drawCircle(Offset(x, y), particleSize, paint);
      
      // Add a brighter core to larger particles
      if (particleSize > 2.5) {
        final corePaint = Paint()
          ..color = Colors.white.withOpacity(opacity * 0.6);
        canvas.drawCircle(Offset(x, y), particleSize * 0.3, corePaint);
      }
    }
  }
  
  void _drawSacredGeometry(Canvas canvas, Offset center, double maxRadius) {
    // Draw multiple geometric shapes
    final shapes = [
      {'sides': 6, 'radius': 0.65, 'rotation': rotationAngle * 0.3},
      {'sides': 3, 'radius': 0.55, 'rotation': -rotationAngle * 0.4 + math.pi / 6},
      {'sides': 3, 'radius': 0.55, 'rotation': -rotationAngle * 0.4 + math.pi},
    ];
    
    for (final shape in shapes) {
      final sides = shape['sides'] as int;
      final radius = (shape['radius'] as double) * maxRadius;
      final rotation = shape['rotation'] as double;
      
      final path = Path();
      
      for (int i = 0; i <= sides; i++) {
        final angle = (i / sides) * 2 * math.pi + rotation;
        final x = center.dx + math.cos(angle) * radius;
        final y = center.dy + math.sin(angle) * radius;
        
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      final opacity = (0.1 + audioLevel * 0.15).clamp(0.0, 0.3);
      
      // Glow effect
      final glowPaint = Paint()
        ..color = deepPurple.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + audioLevel * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawPath(path, glowPaint);
      
      // Core line
      final linePaint = Paint()
        ..color = primaryCyan.withOpacity(opacity * 1.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      
      canvas.drawPath(path, linePaint);
    }
  }
  
  void _drawOrbitalSystem(Canvas canvas, Offset center, double maxRadius) {
    final orbits = [
      {'radius': 0.8, 'tilt': 0.25, 'speed': 1.0, 'color': primaryCyan, 'nodes': 8},
      {'radius': 0.65, 'tilt': -0.2, 'speed': -0.7, 'color': deepPurple, 'nodes': 6},
      {'radius': 0.5, 'tilt': 0.15, 'speed': 0.5, 'color': magenta, 'nodes': 4},
      {'radius': 0.9, 'tilt': -0.1, 'speed': 0.3, 'color': teal, 'nodes': 12},
    ];
    
    for (final orbit in orbits) {
      final radius = (orbit['radius'] as double) * maxRadius;
      final tilt = orbit['tilt'] as double;
      final speed = orbit['speed'] as double;
      final color = orbit['color'] as Color;
      final nodeCount = orbit['nodes'] as int;
      final rotation = rotationAngle * speed;
      
      final ringOpacity = (0.15 + audioLevel * 0.25).clamp(0.0, 0.5);
      
      // Draw the orbital ring
      final ringPaint = Paint()
        ..color = color.withOpacity(ringOpacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + audioLevel * 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * 2 * (0.3 + tilt.abs()),
      );
      
      canvas.drawOval(rect, ringPaint);
      
      // Draw orbital nodes
      for (int i = 0; i < nodeCount; i++) {
        final nodeAngle = (i / nodeCount) * 2 * math.pi;
        final nodeX = math.cos(nodeAngle) * radius;
        final nodeY = math.sin(nodeAngle) * radius * (0.3 + tilt.abs());
        
        final nodePulse = math.sin(particleProgress * 2 * math.pi + i) * 0.3 + 0.7;
        final nodeSize = (2 + audioLevel * 3) * nodePulse;
        
        final nodePaint = Paint()
          ..color = color.withOpacity(ringOpacity * 1.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, nodeSize);
        
        canvas.drawCircle(Offset(nodeX, nodeY), nodeSize, nodePaint);
        
        // Bright core
        final coreNodePaint = Paint()
          ..color = Colors.white.withOpacity(ringOpacity);
        canvas.drawCircle(Offset(nodeX, nodeY), nodeSize * 0.4, coreNodePaint);
      }
      
      canvas.restore();
    }
  }
  
  void _drawPlasmaField(Canvas canvas, Offset center, double radius) {
    if (frequencyBands.isEmpty) return;
    
    final bandCount = frequencyBands.length;
    
    // Draw multiple frequency-reactive layers
    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final layerOffset = layer * 0.1;
      final layerRadius = radius * (1 - layer * 0.15);
      
      for (int i = 0; i <= bandCount * 2; i++) {
        final index = (i ~/ 2) % bandCount;
        final angle = (i / (bandCount * 2)) * 2 * math.pi - math.pi / 2;
        
        final freqValue = frequencyBands[index];
        final dynamicRadius = layerRadius + (freqValue * layerRadius * 0.5);
        final wobble = math.sin(angle * 8 + rotationAngle * 2 + layerOffset) * 3;
        
        final x = center.dx + math.cos(angle + secondaryAngle * 0.1) * (dynamicRadius + wobble);
        final y = center.dy + math.sin(angle + secondaryAngle * 0.1) * (dynamicRadius + wobble);
        
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          // Use quadratic bezier for smoother curves
          final prevAngle = ((i - 1) / (bandCount * 2)) * 2 * math.pi - math.pi / 2;
          final midAngle = (angle + prevAngle) / 2;
          final controlRadius = dynamicRadius * 1.05;
          final cx = center.dx + math.cos(midAngle + secondaryAngle * 0.1) * controlRadius;
          final cy = center.dy + math.sin(midAngle + secondaryAngle * 0.1) * controlRadius;
          path.quadraticBezierTo(cx, cy, x, y);
        }
      }
      path.close();
      
      final colors = [primaryCyan, deepPurple, magenta];
      final color = colors[layer % 3];
      
      // Outer glow
      final glowPaint = Paint()
        ..color = color.withOpacity(0.2 + audioLevel * 0.3 - layer * 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 + audioLevel * 6 - layer * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
      canvas.drawPath(path, glowPaint);
      
      // Inner line
      final linePaint = Paint()
        ..color = color.withOpacity(0.5 + audioLevel * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 - layer * 0.3;
      
      canvas.drawPath(path, linePaint);
    }
  }
  
  void _drawEnergyTendrils(Canvas canvas, Offset center, double maxRadius) {
    final tendrilCount = 12;
    
    for (int i = 0; i < tendrilCount; i++) {
      final baseAngle = (i / tendrilCount) * 2 * math.pi;
      final angle = baseAngle + rotationAngle * 0.5;
      
      final path = Path();
      path.moveTo(center.dx, center.dy);
      
      final controlDist = maxRadius * (0.3 + audioLevel * 0.2);
      final endDist = maxRadius * (0.6 + audioLevel * 0.3 + math.sin(particleProgress * 2 * math.pi + i) * 0.1);
      
      final cp1x = center.dx + math.cos(angle + 0.3) * controlDist;
      final cp1y = center.dy + math.sin(angle + 0.3) * controlDist;
      final cp2x = center.dx + math.cos(angle - 0.2) * (endDist * 0.7);
      final cp2y = center.dy + math.sin(angle - 0.2) * (endDist * 0.7);
      final endX = center.dx + math.cos(angle) * endDist;
      final endY = center.dy + math.sin(angle) * endDist;
      
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, endX, endY);
      
      final colorPhase = (i / tendrilCount + pulseValue * 0.5) % 1.0;
      Color tendrilColor;
      if (colorPhase < 0.5) {
        tendrilColor = Color.lerp(primaryCyan, deepPurple, colorPhase * 2)!;
      } else {
        tendrilColor = Color.lerp(deepPurple, primaryCyan, (colorPhase - 0.5) * 2)!;
      }
      
      final opacity = (0.15 + audioLevel * 0.25).clamp(0.0, 0.5);
      
      final paint = Paint()
        ..color = tendrilColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + audioLevel * 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      
      canvas.drawPath(path, paint);
    }
  }
  
  void _drawCentralOrbSystem(Canvas canvas, Offset center, double radius) {
    final pulseRadius = radius * (0.85 + pulseValue * 0.15 + audioLevel * 0.2);
    
    // Outer atmosphere
    for (int i = 3; i >= 0; i--) {
      final atmosphereRadius = pulseRadius * (1.5 + i * 0.3);
      final atmosphereOpacity = (0.08 - i * 0.015 + audioLevel * 0.05).clamp(0.0, 0.15);
      
      final colors = [primaryCyan, deepPurple, magenta, teal];
      final atmosphereGradient = RadialGradient(
        colors: [
          colors[i % 4].withOpacity(atmosphereOpacity),
          colors[(i + 1) % 4].withOpacity(atmosphereOpacity * 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      
      final paint = Paint()
        ..shader = atmosphereGradient.createShader(
          Rect.fromCircle(center: center, radius: atmosphereRadius),
        );
      
      canvas.drawCircle(center, atmosphereRadius, paint);
    }
    
    // Main orb gradient with multiple colors
    final orbGradient = RadialGradient(
      colors: [
        const Color(0xFF1A1A2E),
        Color.lerp(deepPurple, primaryCyan, pulseValue)!.withOpacity(0.8),
        primaryCyan.withOpacity(0.6),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    
    final orbPaint = Paint()
      ..shader = orbGradient.createShader(
        Rect.fromCircle(center: center, radius: pulseRadius),
      );
    
    canvas.drawCircle(center, pulseRadius, orbPaint);
    
    // Edge highlight ring
    final edgePaint = Paint()
      ..color = primaryCyan.withOpacity(0.5 + audioLevel * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + audioLevel * 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    canvas.drawCircle(center, pulseRadius, edgePaint);
    
    // Secondary edge highlight
    final secondEdgePaint = Paint()
      ..color = deepPurple.withOpacity(0.3 + audioLevel * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(center, pulseRadius * 1.1, secondEdgePaint);
  }
  
  void _drawInnerHalo(Canvas canvas, Offset center, double radius) {
    final haloRadius = radius * (1 + pulseValue * 0.3 + audioLevel * 0.4);
    
    // Multiple halo rings
    for (int i = 0; i < 3; i++) {
      final ringRadius = haloRadius * (1 + i * 0.15);
      final opacity = (0.3 - i * 0.08 + audioLevel * 0.2).clamp(0.0, 0.5);
      
      final gradient = RadialGradient(
        colors: [
          Colors.white.withOpacity(opacity),
          primaryCyan.withOpacity(opacity * 0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      );
      
      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: ringRadius),
        );
      
      canvas.drawCircle(center, ringRadius, paint);
    }
  }
  
  void _drawCore(Canvas canvas, Offset center, double radius) {
    final coreRadius = radius * (0.8 + audioLevel * 0.4 + pulseValue * 0.2);
    
    // Core glow
    final coreGlow = RadialGradient(
      colors: [
        Colors.white,
        Colors.white.withOpacity(0.9),
        primaryCyan.withOpacity(0.7),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );
    
    final glowPaint = Paint()
      ..shader = coreGlow.createShader(
        Rect.fromCircle(center: center, radius: coreRadius * 2),
      );
    
    canvas.drawCircle(center, coreRadius * 2, glowPaint);
    
    // Bright core
    final corePaint = Paint()
      ..color = Colors.white
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, coreRadius * 0.5);
    
    canvas.drawCircle(center, coreRadius, corePaint);
    
    // Sharp center point
    final centerPaint = Paint()
      ..color = Colors.white;
    canvas.drawCircle(center, coreRadius * 0.4, centerPaint);
  }
  
  void _drawLensFlares(Canvas canvas, Offset center, double maxRadius) {
    final flareIntensity = 0.1 + audioLevel * 0.2;
    
    // Small accent flares at specific positions
    final flarePositions = [
      Offset(center.dx + maxRadius * 0.3, center.dy - maxRadius * 0.4),
      Offset(center.dx - maxRadius * 0.35, center.dy + maxRadius * 0.3),
      Offset(center.dx + maxRadius * 0.4, center.dy + maxRadius * 0.35),
    ];
    
    for (int i = 0; i < flarePositions.length; i++) {
      final pos = flarePositions[i];
      final twinkle = math.sin(particleProgress * 2 * math.pi * 2 + i * 2) * 0.5 + 0.5;
      final size = 3 + twinkle * 4 + audioLevel * 3;
      
      final flarePaint = Paint()
        ..color = Colors.white.withOpacity(flareIntensity * twinkle)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size);
      
      canvas.drawCircle(pos, size, flarePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicVisualizerPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
           oldDelegate.secondaryAngle != secondaryAngle ||
           oldDelegate.pulseValue != pulseValue ||
           oldDelegate.particleProgress != particleProgress ||
           oldDelegate.waveProgress != waveProgress ||
           oldDelegate.audioLevel != audioLevel;
  }
}
