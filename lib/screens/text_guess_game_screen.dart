// lib/screens/text_guess_game_screen.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';
import '../services/mapbox_service.dart';
import '../services/google_geocoding_service.dart';
import '../services/db_service.dart';
import '../models/challenge.dart';
import '../models/game_mode.dart';
import '../models/high_score.dart';
import '../widgets/victory_animation.dart';
import '../widgets/defeat_animation.dart';

/// Écran de jeu pour le mode Dis où tu es
/// Le joueur doit taper le nom du lieu au lieu de cliquer sur la carte
class TextGuessGameScreen extends StatefulWidget {
  final GameConfiguration config;

  const TextGuessGameScreen({Key? key, required this.config}) : super(key: key);

  @override
  State<TextGuessGameScreen> createState() => _TextGuessGameScreenState();
}

class _TextGuessGameScreenState extends State<TextGuessGameScreen> {
  // Contrôleur de la carte Mapbox
  MapboxMap? _mapboxMap;

  // Gestionnaire des marqueurs (annotations)
  PointAnnotationManager? _annotationManager;
  CircleAnnotationManager? _circleAnnotationManager;

  // Défi actuel (lieu à deviner)
  Challenge? _currentChallenge;

  // Position de la réponse géocodée à partir du texte
  Point? _guessLocation;

  // Informations détaillées du geocoding (pour mode EASY)
  String _guessedCountry = '';

  // État du jeu
  bool _hasGuessed = false;
  int _currentScore = 0;
  int _roundNumber = 1;
  final int _maxRounds = 5;

  // Contrôleur du champ de saisie
  final TextEditingController _guessController = TextEditingController();

  // Références aux annotations
  PointAnnotation? _guessAnnotation;
  PointAnnotation? _correctAnnotation;
  CircleAnnotation? _targetCircleAnnotation;
  CircleAnnotation? _guessCircleAnnotation;
  CircleAnnotation? _correctCircleAnnotation;

  // État du géocodage
  bool _isGeocoding = false;

  // === Timer fields ===
  Timer? _roundTimer;
  int _remainingSeconds = 0;
  bool get _timerEnabled => widget.config.timerEnabled;
  int get _timerDuration => widget.config.timerDuration;

  @override
  void initState() {
    super.initState();
    _loadNewChallenge();
  }

  @override
  void dispose() {
    _guessController.dispose();
    _cancelTimer();
    super.dispose();
  }

  /// Charge un nouveau défi (lieu aléatoire)
  void _loadNewChallenge() async {
    // Générer un challenge depuis la base de données
    final challenge = await Challenge.random(
      onlyCapitals: widget.config.difficulty == Difficulty.medium,
    );

    setState(() {
      _currentChallenge = challenge;
      _guessLocation = null;
      _hasGuessed = false;
      _guessController.clear();
      _guessAnnotation = null;
      _correctAnnotation = null;
      _isGeocoding = false;
    });

    // Supprime tous les marqueurs au début d'un nouveau challenge
    _annotationManager?.deleteAll();

    // Timer handling: cancel previous and start if enabled
    _cancelTimer();
    if (_timerEnabled) {
      _startTimer();
    }

    // Ajouter le marqueur seulement si l'annotationManager est déjà initialisé
    if (_annotationManager != null) {
      await _addChallengeMarker();
    }
  }

  // === Timer helpers ===
  void _startTimer() {
    _cancelTimer();
    setState(() {
      _remainingSeconds = _timerDuration;
    });

    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        _onTimerExpired();
      }
    });
  }

  void _cancelTimer() {
    _roundTimer?.cancel();
    _roundTimer = null;
  }

  void _onTimerExpired() {
    _cancelTimer();
    if (!mounted) return;

    if (!_hasGuessed) {
      setState(() {
        _hasGuessed = true;
      });

      // Montrer la bonne réponse
      _addCorrectAnswerMarker();

      // Afficher un dialogue indiquant que le temps est écoulé
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Temps écoulé !'),
          content: const Text('Vous n\'avez pas répondu à temps. 0 point pour ce round.'),
          actions: [
            TextButton(onPressed: _nextRound, child: const Text('Round suivant')),
          ],
        ),
      );
    }
  }

  /// Ajoute un marqueur rouge à l'endroit à deviner
  /// Cela permet de voir où se trouve le lieu même en dézoomant
  Future<void> _addChallengeMarker() async {
    if (_annotationManager == null || _currentChallenge == null) return;

    final challengePoint = Point(
      coordinates: Position(
        _currentChallenge!.longitude,
        _currentChallenge!.latitude,
      ),
    );

    // Utiliser un CircleAnnotation au lieu de PointAnnotation pour éviter le problème d'image manquante
    await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: challengePoint,
        iconSize: 1.5,
        iconColor: Colors.red.toARGB32(),
      ),
    );

    // Ajouter un cercle cible au bon endroit (révélation de la réponse)
    _targetCircleAnnotation = await _circleAnnotationManager!.create(
      CircleAnnotationOptions(
        geometry: challengePoint,
        circleRadius: 10.0,
        circleColor: Colors.red.withOpacity(0.3).toARGB32(),
        circleStrokeColor: Colors.red.toARGB32(),
        circleStrokeWidth: 2.0,
      ),
    );
  }

  /// Callback appelé quand la carte est créée
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();

    // Ajouter le marqueur du challenge maintenant que l'annotationManager est prêt
    if (_currentChallenge != null) {
      await _addChallengeMarker();
    }

    _centerMapOnChallenge();
  }

  /// Centre la caméra sur le lieu du défi
  void _centerMapOnChallenge() {
    if (_mapboxMap != null && _currentChallenge != null) {
      _mapboxMap!.setCamera(CameraOptions(
        center: Point(
          coordinates: Position(
            _currentChallenge!.longitude,
            _currentChallenge!.latitude,
          ),
        ),
        zoom: 12.0,
      ));
    }
  }

  /// Retourne l'URI du style de carte selon la configuration
  String _getMapStyleUri() {
    if (widget.config.mapStyle == null) {
      return 'mapbox://styles/jeremyretille/cmghmue0j002h01r15n8z3xpu';
    }

    switch (widget.config.mapStyle!) {
      case MapStyle.classic:
        return 'mapbox://styles/jeremyretille/cmghmue0j002h01r15n8z3xpu';
      case MapStyle.blackAndWhite:
        return 'mapbox://styles/jeremyretille/cmh0bd4rj000a01qt2aw15qe0';
      case MapStyle.noBorders:
        return 'mapbox://styles/jeremyretille/cmh0b1xx5009y01sa770d3e41';
      case MapStyle.satellite:
        return 'mapbox://styles/mapbox/satellite-v9';
    }
  }

  /// Géocode la réponse textuelle de l'utilisateur
  Future<void> _geocodeGuess() async {
    final query = _guessController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom de lieu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeocoding = true;
    });

    try {
      // Utiliser geocodeAddressDetailed pour obtenir le pays
      final result = await GoogleGeocodingService.geocodeAddressDetailed(query);

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isGeocoding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lieu non trouvé. Essayez un autre nom.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _guessLocation = result.point;
        _guessedCountry = result.country;
        _isGeocoding = false;
      });

      // Ajouter un marqueur bleu pour la réponse
      _addGuessMarker(result.point);

      // Afficher une confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lieu trouvé : "$query"'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeocoding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Ajoute un marqueur bleu à l'endroit géocodé (le guess de l'utilisateur)
  void _addGuessMarker(Point point) async {
    if (_annotationManager == null) return;

    // Supprimer l'ancien marqueur de guess s'il existe
    if (_guessAnnotation != null) {
      _annotationManager!.delete(_guessAnnotation!);
    }

    // Créer le nouveau marqueur bleu (sans iconImage)
    _guessAnnotation = await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: point,
        iconSize: 1.5,
        iconColor: Colors.blue.toARGB32(),
      ),
    );

    // NE PAS déplacer la caméra pour ne pas révéler la position du guess
    // La caméra se déplacera seulement après validation pour montrer les deux marqueurs
  }

  /// Valide le guess de l'utilisateur et affiche le résultat
  void _submitGuess() async {
    // Vérifier qu'un lieu a été géocodé
    if (_guessLocation == null || _currentChallenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord rechercher un lieu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int score = 0;
    double distance = 0;

    // Mode EASY : Seul le pays compte
    if (widget.config.difficulty == Difficulty.easy) {
      // Vérifier si le pays est correct
      final correctCountry = _currentChallenge!.correctCountry.toLowerCase();
      final guessedCountry = _guessedCountry.toLowerCase();

      if (correctCountry == guessedCountry) {
        // Bon pays = 1000 points
        score = 1000;
        distance = 0;
      } else {
        // Mauvais pays : calculer la distance entre les capitales pour donner des points partiels
        distance = MapboxService.calculateDistance(
          _currentChallenge!.latitude,
          _currentChallenge!.longitude,
          _guessLocation!.coordinates.lat.toDouble(),
          _guessLocation!.coordinates.lng.toDouble(),
        );

        // Score basé sur la distance : pays proche = plus de points
        // Distance < 1000 km = 500 pts
        // Distance < 3000 km = 300 pts
        // Distance < 5000 km = 150 pts
        // Distance < 10000 km = 50 pts
        // Distance > 10000 km = 0 pts
        if (distance < 1000) {
          score = 500;
        } else if (distance < 3000) {
          score = 300;
        } else if (distance < 5000) {
          score = 150;
        } else if (distance < 10000) {
          score = 50;
        } else {
          score = 0;
        }
      }
    } else {
      // Modes MEDIUM et HARD : système de points normal basé sur la distance
      distance = MapboxService.calculateDistance(
        _currentChallenge!.latitude,
        _currentChallenge!.longitude,
        _guessLocation!.coordinates.lat.toDouble(),
        _guessLocation!.coordinates.lng.toDouble(),
      );
      score = MapboxService.calculateScore(distance);
    }

    setState(() {
      _hasGuessed = true;
      _currentScore += score;
    });

    // Annuler le timer pour éviter double actions
    _cancelTimer();

    // Afficher le marqueur vert (bonne réponse)
    _addCorrectAnswerMarker();

    // Afficher le dialogue de résultat
    _showResultDialog(distance, score);
  }

  /// Ajoute un marqueur vert au bon emplacement (révélation de la réponse)
  void _addCorrectAnswerMarker() async {
    if (_annotationManager == null || _currentChallenge == null) return;

    final correctPoint = Point(
      coordinates: Position(
        _currentChallenge!.longitude,
        _currentChallenge!.latitude,
      ),
    );

    _correctAnnotation = await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: correctPoint,
        iconSize: 1.5,
        iconColor: Colors.green.toARGB32(),
      ),
    );

    // Ajouter un cercle vert au bon endroit (révélation de la réponse)
    _correctCircleAnnotation = await _circleAnnotationManager!.create(
      CircleAnnotationOptions(
        geometry: correctPoint,
        circleRadius: 10.0,
        circleColor: Colors.green.withOpacity(0.3).toARGB32(),
        circleStrokeColor: Colors.green.toARGB32(),
        circleStrokeWidth: 2.0,
      ),
    );
  }

  void _showResultDialog(double distance, int score) {
    // Vérifier si c'est le mode EASY et si le pays est correct
    final isEasyMode = widget.config.difficulty == Difficulty.easy;
    final isCountryCorrect = isEasyMode &&
        _currentChallenge!.correctCountry.toLowerCase() == _guessedCountry.toLowerCase();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Round $_roundNumber/$_maxRounds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône de résultat
            Icon(
              isCountryCorrect || score >= 500 ? Icons.check_circle : Icons.cancel,
              size: 64,
              color: isCountryCorrect || score >= 500 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),

            // Réponse du joueur
            Text(
              'Votre réponse :',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              isEasyMode
                ? _guessedCountry // En mode facile, afficher le pays géocodé
                : _guessController.text.trim(), // En mode normal, afficher la saisie
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Réponse attendue (selon le mode)
            Text(
              'Réponse attendue :',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              isEasyMode
                ? _currentChallenge!.correctCountry // En mode facile, afficher le pays correct
                : '${_currentChallenge!.correctCity}', // En mode normal, afficher la ville correcte
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Distance
            if (distance > 0) ...[
              Text(
                'Distance :',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${distance.toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],

            // Score
            Text(
              'Score : $score points',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: score >= 500 ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _nextRound,
            child: Text(
              _roundNumber < _maxRounds ? 'Round suivant' : 'Voir le score final',
            ),
          ),
        ],
      ),
    );
  }

  void _nextRound() {
    Navigator.of(context).pop();

    if (_roundNumber < _maxRounds) {
      setState(() {
        _roundNumber++;
      });
      _loadNewChallenge();
      _centerMapOnChallenge();
    } else {
      _showFinalScore();
    }
  }

  void _showFinalScore() async {
    // Sauvegarder le score dans la base de données
    await _saveHighScore();

    if (!mounted) return;

    final isVictory = _currentScore >= 3500;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: isVictory
            ? VictoryAnimation(
                child: _buildEndGameDialog(isVictory: true),
              )
            : DefeatAnimation(
                child: _buildEndGameDialog(isVictory: false),
              ),
      ),
    );
  }

  Widget _buildEndGameDialog({required bool isVictory}) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isVictory ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            color: isVictory ? Colors.amber : Colors.grey,
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(isVictory ? 'Victoire !' : 'Partie terminée'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVictory ? Icons.emoji_events : Icons.trending_down,
            size: 64,
            color: isVictory ? Colors.amber : Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            isVictory ? 'Félicitations !' : 'Continuez à vous entraîner !',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isVictory ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Score total: $_currentScore',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            'Moyenne: ${(_currentScore / _maxRounds).toStringAsFixed(0)} pts/round',
          ),
          const SizedBox(height: 10),
          const Text(
            '✅ Score enregistré !',
            style: TextStyle(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isVictory) ...[
            const SizedBox(height: 12),
            Text(
              '🎉 Plus de 3500 points !',
              style: TextStyle(
                fontSize: 14,
                color: Colors.amber.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          child: const Text('Retour au menu'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            setState(() {
              _roundNumber = 1;
              _currentScore = 0;
            });
            _loadNewChallenge();
            _centerMapOnChallenge();
          },
          child: const Text('Rejouer'),
        ),
      ],
    );
  }

  /// Sauvegarde le score actuel dans la base de données
  Future<void> _saveHighScore() async {
    try {
      // Créer l'objet HighScore avec toutes les informations de la partie
      final highScore = HighScore(
        score: _currentScore,
        gameMode: 'text_guess',
        difficulty: _getDifficultyString(widget.config.difficulty),
        mapStyle: _getMapStyleString(widget.config.mapStyle),
        hasTimer: widget.config.timerEnabled,
        timeLeft: widget.config.timerEnabled ? _remainingSeconds : null,
        playedAt: DateTime.now(),
      );

      // Sauvegarder dans la base de données
      await DatabaseService.instance.saveHighScore(highScore);

      print('✅ Score sauvegardé: $_currentScore points');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du score: $e');
      // Ne pas bloquer l'utilisateur en cas d'erreur
    }
  }

  /// Convertit l'enum Difficulty en String pour la base de données
  String _getDifficultyString(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 'easy';
      case Difficulty.medium:
        return 'medium';
      case Difficulty.hard:
        return 'hard';
    }
  }

  /// Convertit l'enum MapStyle en String pour la base de données
  String _getMapStyleString(MapStyle? mapStyle) {
    if (mapStyle == null) return 'classic';

    switch (mapStyle) {
      case MapStyle.classic:
        return 'classic';
      case MapStyle.blackAndWhite:
        return 'blackAndWhite';
      case MapStyle.noBorders:
        return 'noBorders';
      case MapStyle.satellite:
        return 'satellite';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dis où tu es $_roundNumber/$_maxRounds'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Score: $_currentScore',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _currentChallenge == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Carte (prend la majorité de l'écran)
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      MapWidget(
                        key: ValueKey(_currentChallenge),
                        styleUri: _getMapStyleUri(),
                        onMapCreated: _onMapCreated,
                      ),
                      // Bouton pour revenir à l'origine (centrer sur le point cible)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          onPressed: _centerMapOnChallenge,
                          child: const Icon(Icons.my_location),
                        ),
                      ),
                      if (_timerEnabled && !_hasGuessed)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Card(
                            color: Colors.black54,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text('$_remainingSeconds s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Zone de saisie en bas
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_hasGuessed) ...[
                        const Text(
                          'Où pensez-vous être ?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _guessController,
                                decoration: InputDecoration(
                                  hintText: 'Ex: Paris, France',
                                  labelText: 'Nom du lieu',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _guessController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            setState(() {
                                              _guessController.clear();
                                              _guessLocation = null;
                                            });
                                            if (_guessAnnotation != null) {
                                              _annotationManager?.delete(_guessAnnotation!);
                                              _guessAnnotation = null;
                                            }
                                          },
                                        )
                                      : null,
                                ),
                                enabled: !_isGeocoding && !_hasGuessed,
                                onSubmitted: (_) => _geocodeGuess(),
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isGeocoding ? null : _geocodeGuess,
                              icon: _isGeocoding
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.location_searching),
                              label: const Text('Chercher'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_guessLocation != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lieu trouvé ! Vérifiez sur la carte et validez.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _guessLocation != null ? _submitGuess : null,
                            icon: const Icon(Icons.check, size: 24),
                            label: const Text(
                              'Valider ma réponse',
                              style: TextStyle(fontSize: 18),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                            ),
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

