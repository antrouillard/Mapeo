// lib/widgets/victory_animation.dart
import 'package:flutter/material.dart';
import 'dart:math';

/// Widget d'animation de victoire avec confettis et 2 logos qui révèlent la popup
class VictoryAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onAnimationComplete;

  const VictoryAnimation({
    Key? key,
    required this.child,
    this.onAnimationComplete,
  }) : super(key: key);

  @override
  State<VictoryAnimation> createState() => _VictoryAnimationState();
}

class _VictoryAnimationState extends State<VictoryAnimation>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _logoController;
  late AnimationController _separationController;
  late AnimationController _contentController;

  final List<Confetti> _confettiList = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Contrôleur pour les confettis (animation continue)
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        setState(() {
          for (var confetti in _confettiList) {
            confetti.update();
          }
        });
      });

    // Contrôleur pour l'apparition des logos
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Contrôleur pour la séparation des logos
    _separationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Contrôleur pour l'apparition du contenu
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Générer les confettis
    _generateConfetti();

    // Démarrer l'animation
    _startAnimation();
  }

  void _generateConfetti() {
    // Créer environ 50 confettis depuis les bords
    for (int i = 0; i < 50; i++) {
      _confettiList.add(Confetti(random: _random));
    }
  }

  void _startAnimation() async {
    // Démarrer les confettis immédiatement
    _confettiController.forward();

    // Attendre 200ms puis faire apparaître les logos
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();

    // Attendre que les logos soient complètement visibles puis les séparer
    await Future.delayed(const Duration(milliseconds: 900));
    _separationController.forward();

    // Attendre que la séparation soit terminée puis afficher le contenu
    await Future.delayed(const Duration(milliseconds: 700));
    _contentController.forward();

    // Quand le contenu est affiché, appeler le callback
    _contentController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _logoController.dispose();
    _separationController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Animation de scale et fade pour les logos
    final logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    final logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    final separationOffset = Tween<double>(begin: 0.0, end: size.width * 0.25).animate(
      CurvedAnimation(parent: _separationController, curve: Curves.easeInOut),
    );

    // Animation du carré blanc (placeholder de la popup)
    final placeholderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _separationController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeIn),
      ),
    );

    final placeholderScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _separationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Animation du contenu (popup avec informations)
    final contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );

    return Stack(
      children: [
        // Les confettis en arrière-plan
        CustomPaint(
          size: size,
          painter: ConfettiPainter(confettiList: _confettiList),
        ),

        // Animation des 2 logos qui se séparent horizontalement
        AnimatedBuilder(
          animation: Listenable.merge([_logoController, _separationController]),
          builder: (context, child) {
            return Stack(
              children: [
                // Logo de gauche
                Positioned(
                  top: size.height / 2 - 50,
                  left: size.width / 2 - 50 - separationOffset.value,
                  child: Transform.scale(
                    scale: logoScale.value,
                    child: Opacity(
                      opacity: logoOpacity.value,
                      child: const Icon(
                        Icons.public,
                        size: 100,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),

                // Logo de droite
                Positioned(
                  top: size.height / 2 - 50,
                  left: size.width / 2 - 50 + separationOffset.value,
                  child: Transform.scale(
                    scale: logoScale.value,
                    child: Opacity(
                      opacity: logoOpacity.value,
                      child: const Icon(
                        Icons.public,
                        size: 100,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // Carré blanc (placeholder de la popup) qui apparaît entre les logos
        AnimatedBuilder(
          animation: _separationController,
          builder: (context, child) {
            return Center(
              child: Transform.scale(
                scale: placeholderScale.value,
                child: Opacity(
                  opacity: placeholderOpacity.value,
                  child: Container(
                    width: 280,
                    height: 360,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dialogTheme.backgroundColor ??
                             Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Le contenu (dialog avec informations) apparaît par-dessus le carré blanc
        AnimatedBuilder(
          animation: _contentController,
          builder: (context, child) {
            return Opacity(
              opacity: contentOpacity.value,
              child: Center(child: widget.child),
            );
          },
        ),
      ],
    );
  }
}

/// Classe représentant un confetti individuel
class Confetti {
  late double x;
  late double y;
  late double speedX;
  late double speedY;
  late double rotation;
  late double rotationSpeed;
  late Color color;
  late double size;

  Confetti({required Random random}) {
    // Position initiale aléatoire depuis les bords
    final fromSide = random.nextInt(4); // 0: haut, 1: droite, 2: bas, 3: gauche

    switch (fromSide) {
      case 0: // Haut
        x = random.nextDouble();
        y = -0.1;
        speedY = 0.01 + random.nextDouble() * 0.02;
        speedX = (random.nextDouble() - 0.5) * 0.01;
        break;
      case 1: // Droite
        x = 1.1;
        y = random.nextDouble();
        speedX = -0.01 - random.nextDouble() * 0.02;
        speedY = (random.nextDouble() - 0.5) * 0.01;
        break;
      case 2: // Bas
        x = random.nextDouble();
        y = 1.1;
        speedY = -0.01 - random.nextDouble() * 0.02;
        speedX = (random.nextDouble() - 0.5) * 0.01;
        break;
      default: // Gauche
        x = -0.1;
        y = random.nextDouble();
        speedX = 0.01 + random.nextDouble() * 0.02;
        speedY = (random.nextDouble() - 0.5) * 0.01;
    }

    rotation = random.nextDouble() * 2 * pi;
    rotationSpeed = (random.nextDouble() - 0.5) * 0.2;

    // Couleurs festives
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.amber,
    ];
    color = colors[random.nextInt(colors.length)];
    size = 6 + random.nextDouble() * 6;
  }

  void update() {
    x += speedX;
    y += speedY;
    rotation += rotationSpeed;

    // Ajouter une légère gravité
    speedY += 0.0003;
  }
}

/// Painter pour dessiner les confettis
class ConfettiPainter extends CustomPainter {
  final List<Confetti> confettiList;

  ConfettiPainter({required this.confettiList});

  @override
  void paint(Canvas canvas, Size size) {
    for (var confetti in confettiList) {
      final paint = Paint()
        ..color = confetti.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(confetti.x * size.width, confetti.y * size.height);
      canvas.rotate(confetti.rotation);

      // Dessiner un rectangle pour le confetti
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: confetti.size,
          height: confetti.size * 0.6,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
