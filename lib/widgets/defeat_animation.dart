// lib/widgets/defeat_animation.dart
import 'package:flutter/material.dart';
import 'dart:math';

/// Widget d'animation de défaite avec effet de pluie et logo qui tombe
class DefeatAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onAnimationComplete;

  const DefeatAnimation({
    Key? key,
    required this.child,
    this.onAnimationComplete,
  }) : super(key: key);

  @override
  State<DefeatAnimation> createState() => _DefeatAnimationState();
}

class _DefeatAnimationState extends State<DefeatAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rainController;
  late AnimationController _logoController;
  late AnimationController _fadeController;

  final List<RainDrop> _rainDrops = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Contrôleur pour la pluie (animation continue)
    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        setState(() {
          for (var drop in _rainDrops) {
            drop.update();
          }
        });
      });

    // Contrôleur pour la chute du logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Contrôleur pour le fade du contenu
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Générer les gouttes de pluie
    _generateRain();

    // Démarrer l'animation
    _startAnimation();
  }

  void _generateRain() {
    // Créer environ 40 gouttes de pluie (plus nombreuses)
    for (int i = 0; i < 40; i++) {
      _rainDrops.add(RainDrop(random: _random));
    }
  }

  void _startAnimation() async {
    // Démarrer la pluie immédiatement
    _rainController.forward();

    // Attendre 100ms puis faire tomber le logo
    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();

    // Attendre que le logo soit tombé puis faire apparaître le contenu
    await Future.delayed(const Duration(milliseconds: 1300));
    _fadeController.forward();

    // Appeler le callback
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _rainController.dispose();
    _logoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Animation de chute du logo avec rebond
    final logoFall = Tween<double>(begin: -200.0, end: size.height / 2 - 50).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.bounceOut),
    );

    final logoOpacity = Tween<double>(begin: 0.3, end: 0.5).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    return Stack(
      children: [
        // Fond légèrement assombri
        Container(
          color: Colors.black.withOpacity(0.3),
        ),

        // La pluie en arrière-plan
        CustomPaint(
          size: size,
          painter: RainPainter(rainDrops: _rainDrops),
        ),

        // Logo qui tombe
        AnimatedBuilder(
          animation: _logoController,
          builder: (context, child) {
            return Positioned(
              top: logoFall.value,
              left: size.width / 2 - 50,
              child: Opacity(
                opacity: logoOpacity.value,
                child: const Icon(
                  Icons.public,
                  size: 100,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),

        // Le contenu (dialog) apparaît en fondu
        AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            final contentOpacity = _fadeController.value;
            final contentScale = Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
            );

            return Opacity(
              opacity: contentOpacity,
              child: Transform.scale(
                scale: contentScale.value,
                child: Center(child: widget.child),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Classe représentant une goutte de pluie
class RainDrop {
  late double x;
  late double y;
  late double speed;
  late double length;
  late double opacity;

  RainDrop({required Random random}) {
    x = random.nextDouble();
    y = random.nextDouble() * -0.5; // Commence au-dessus de l'écran
    speed = 0.02 + random.nextDouble() * 0.015; // Vitesse augmentée
    length = 25 + random.nextDouble() * 25; // Longueur augmentée (était 15-30, maintenant 25-50)
    opacity = 0.5 + random.nextDouble() * 0.4; // Opacité augmentée (était 0.3-0.6, maintenant 0.5-0.9)
  }

  void update() {
    y += speed;
    // Réinitialiser en haut quand la goutte sort de l'écran
    if (y > 1.2) {
      y = -0.1;
    }
  }
}

/// Painter pour dessiner la pluie
class RainPainter extends CustomPainter {
  final List<RainDrop> rainDrops;

  RainPainter({required this.rainDrops});

  @override
  void paint(Canvas canvas, Size size) {
    for (var drop in rainDrops) {
      final paint = Paint()
        ..color = Colors.blue.withOpacity(drop.opacity)
        ..strokeWidth = 4 // Épaisseur augmentée (était 2, maintenant 4)
        ..strokeCap = StrokeCap.round;

      final startPoint = Offset(drop.x * size.width, drop.y * size.height);
      final endPoint = Offset(
        drop.x * size.width,
        drop.y * size.height + drop.length,
      );

      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
