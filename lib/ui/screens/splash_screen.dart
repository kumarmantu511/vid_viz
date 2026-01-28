import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vidviz/core/theme.dart';
import 'package:vidviz/ui/screens/project_list.dart';


class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {

  // Ana animasyon controller'ları
  late AnimationController _logoController;
  late AnimationController _bgController;
  late AnimationController _exitController;

  // Animasyonlar
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowIntensity;
  late Animation<double> _bgRotation;
  late Animation<double> _exitFade;

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Logo animasyonu (2 saniye)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Arka plan döngüsü
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Çıkış animasyonu
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Logo scale: 0.5 -> 1.0 -> 0.95 (bounce)
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.05).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_logoController);

    // Logo opacity: 0 -> 1
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    // Glow pulse
    _glowIntensity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Background rotation
    _bgRotation = Tween<double>(begin: 0.0, end: 2 * pi).animate(_bgController);

    // Exit fade
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
    );
  }

  void _startSequence() {
    // Logo animasyonunu başlat
    _logoController.forward();

    // 2.2 saniye sonra çıkış animasyonu
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _isExiting = true);
        _exitController.forward().then((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => ProjectList(),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _bgController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Tema renkleri
    final bgColor = isDark ? darkBackground : background;
    final accentColor = isDark ? darkAccent : accent;
    final secondaryAccent = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0984E3);

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([_logoController, _bgController, _exitController]),
        builder: (context, child) {
          return Opacity(
            opacity: _isExiting ? _exitFade.value : 1.0,
            child: Stack(
              children: [
                // Animated gradient background
                _buildAnimatedBackground(accentColor, secondaryAccent, isDark),

                // Floating particles
                _buildParticles(accentColor),

                // Logo ve içerik
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App Icon with glow
                      _buildLogo(accentColor),

                      const SizedBox(height: 24),

                      // App name
                      _buildAppName(isDark),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedBackground(Color accent, Color secondary, bool isDark) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _bgRotation,
        builder: (context, _) {
          return CustomPaint(
            painter: _GradientBgPainter(
              rotation: _bgRotation.value,
              color1: accent.withOpacity(isDark ? 0.15 : 0.08),
              color2: secondary.withOpacity(isDark ? 0.1 : 0.05),
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticles(Color accent) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _bgController,
          builder: (context, _) {
            return CustomPaint(
              painter: _ParticlePainter(
                time: _bgController.value,
                color: accent,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo(Color accentColor) {
    return Transform.scale(
      scale: _logoScale.value,
      child: Opacity(
        opacity: _logoOpacity.value,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.4 * _glowIntensity.value),
                blurRadius: 40 * _glowIntensity.value,
                spreadRadius: 10 * _glowIntensity.value,
              ),
              BoxShadow(
                color: accentColor.withOpacity(0.2 * _glowIntensity.value),
                blurRadius: 80 * _glowIntensity.value,
                spreadRadius: 20 * _glowIntensity.value,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              '',
              //'assets/app_icon.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppName(bool isDark) {
    return Opacity(
      opacity: _logoOpacity.value,
      child: Text(
        'VIDVIZ',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          letterSpacing: 8,
          color: isDark ? darkTextPrimary : textPrimary,
        ),
      ),
    );
  }
}

// Gradient background painter
class _GradientBgPainter extends CustomPainter {
  final double rotation;
  final Color color1;
  final Color color2;
  final bool isDark;

  _GradientBgPainter({
    required this.rotation,
    required this.color1,
    required this.color2,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.longestSide;

    // Rotating gradient blobs
    for (int i = 0; i < 3; i++) {
      final angle = rotation + (i * pi * 2 / 3);
      final offset = Offset(
        center.dx + cos(angle) * radius * 0.3,
        center.dy + sin(angle) * radius * 0.3,
      );

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            i.isEven ? color1 : color2,
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: offset, radius: radius * 0.6));

      canvas.drawCircle(offset, radius * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_GradientBgPainter old) => old.rotation != rotation;
}

// Floating particles painter
class _ParticlePainter extends CustomPainter {
  final double time;
  final Color color;

  _ParticlePainter({required this.time, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // Sabit seed

    for (int i = 0; i < 20; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.5 + random.nextDouble() * 0.5;
      final particleSize = 2.0 + random.nextDouble() * 3.0;

      // Yukarı doğru hareket
      final y = (baseY - time * speed * size.height) % size.height;
      final x = baseX + sin(time * 2 * pi + i) * 20;

      final opacity = 0.2 + 0.3 * sin(time * 2 * pi + i * 0.5).abs();

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.time != time;
}