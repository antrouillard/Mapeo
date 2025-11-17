// lib/screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';
import '../services/mapbox_service.dart';
import '../services/db_service.dart';
import '../services/google_geocoding_service.dart';
import '../services/weather_service.dart';
import '../database/database_helper.dart';
import '../models/challenge.dart';
import '../models/game_mode.dart';
import '../models/high_score.dart';
import '../widgets/victory_animation.dart';
import '../widgets/defeat_animation.dart';

/// Écran de jeu pour le mode Guess sur Map
/// Le joueur voit le nom de la ville/pays et doit cliquer sur la carte
class GameScreen extends StatefulWidget {
  final GameConfiguration? config;

  const GameScreen({Key? key, this.config}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Contrôleur de la carte Mapbox
  MapboxMap? _mapboxMap;

  // Gestionnaire des marqueurs (annotations)
  PointAnnotationManager? _annotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  PolygonAnnotationManager? _polygonAnnotationManager;

  // Défi actuel (lieu à deviner)
  Challenge? _currentChallenge;

  // Position du guess de l'utilisateur
  Point? _guessLocation;

  // État du jeu
  bool _hasGuessed = false;
  int _currentScore = 0;
  int _roundNumber = 1;
  final int _maxRounds = 5;

  // Stockage du score et de la distance du round actuel
  double? _currentRoundDistance;
  int? _currentRoundScore;
  bool _guessedCorrectCountry = false; // Pour savoir si le pays est correct en mode facile

  // Références aux annotations
  CircleAnnotation? _guessAnnotation;
  CircleAnnotation? _correctAnnotation;
  PolygonAnnotation? _countryBorderAnnotation;

  // Timer
  Timer? _roundTimer;
  int _remainingSeconds = 0;
  bool get _timerEnabled => widget.config?.timerEnabled ?? false;
  int get _timerDuration => widget.config?.timerDuration ?? 60;

  // Données météo
  Map<String, dynamic>? _weatherData;

  // URL du drapeau pour le mode Capitale/Drapeau
  String? _flagUrl;

  @override
  void initState() {
    super.initState();
    _loadNewChallenge();
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  /// Charge un nouveau défi depuis la base de données
  void _loadNewChallenge() async {
    final difficulty = widget.config?.difficulty ?? Difficulty.easy;
    final mapHint = widget.config?.mapHint ?? MapHint.classic;

    Challenge? challenge;

    // Mode Capitale/Drapeau : forcer la difficulté facile et charger une capitale
    if (mapHint == MapHint.capitalFlag) {
      challenge = await Challenge.random(onlyCapitals: true);
    }
    // Mode facile : n'importe quelle ville (on demandera seulement le pays)
    else if (difficulty == Difficulty.easy) {
      challenge = await Challenge.random(onlyCapitals: false);
    }
    // Mode moyen : uniquement les capitales
    else if (difficulty == Difficulty.medium) {
      challenge = await Challenge.random(onlyCapitals: true);
    }
    // Mode difficile : villes normales (pas forcément des capitales)
    else {
      challenge = await Challenge.random(onlyCapitals: false);
    }

    setState(() {
      _currentChallenge = challenge;
      _guessLocation = null;
      _hasGuessed = false;
      _guessAnnotation = null;
      _correctAnnotation = null;
      _currentRoundDistance = null;
      _currentRoundScore = null;
      _guessedCorrectCountry = false;
      _flagUrl = null; // Réinitialiser le drapeau
    });

    // Supprime tous les marqueurs
    _circleAnnotationManager?.deleteAll();
    _polygonAnnotationManager?.deleteAll();

    // Démarrer la caméra sur une vue globale
    _resetCameraToWorld();

    // Timer
    _cancelTimer();
    if (_timerEnabled) {
      _startTimer();
    }

    // Charger les données météo pour le défi actuel
    _loadWeatherData();

    // Charger le drapeau en mode Capitale/Drapeau
    if (mapHint == MapHint.capitalFlag && challenge != null) {
      _loadFlagForChallenge();
    }
  }

  /// Charge le drapeau du pays pour le défi actuel
  Future<void> _loadFlagForChallenge() async {
    if (_currentChallenge == null) return;

    final iso2Code = await _getCountryISO2Code(_currentChallenge!.correctCountry);

    if (iso2Code != null && mounted) {
      setState(() {
        _flagUrl = 'https://flagcdn.com/w320/${iso2Code.toLowerCase()}.png';
      });
    }
  }

  /// Positionne la caméra sur une vue du monde
  void _resetCameraToWorld() {
    if (_mapboxMap != null) {
      _mapboxMap!.setCamera(CameraOptions(
        center: Point(coordinates: Position(0, 20)), // Centre sur le monde
        zoom: 1.5, // Vue globale
      ));
    }
  }

  // === Timer ===
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

      _addCorrectAnswerMarker();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Temps écoulé !'),
          content: const Text('Vous n\'avez pas répondu à temps. 0 point pour ce round.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer d'abord la popup du timer
                _nextRound(); // Puis passer au round suivant
              },
              child: const Text('Round suivant'),
            ),
          ],
        ),
      );
    }
  }

  /// Callback quand la carte est créée
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();
    _polygonAnnotationManager = await mapboxMap.annotations.createPolygonAnnotationManager();

    // Masquer les labels selon la difficulté
    await _configureLabelVisibility();

    _resetCameraToWorld();
  }

  /// Configure la visibilité des labels selon la difficulté
  Future<void> _configureLabelVisibility() async {
    if (_mapboxMap == null) return;

    final difficulty = widget.config?.difficulty ?? Difficulty.easy;

    // Mode facile et moyen : masquer tous les labels (pays, villes, capitales)
    if (difficulty == Difficulty.easy || difficulty == Difficulty.medium) {
      try {
        // Masquer les labels de pays
        await _mapboxMap!.style.setStyleLayerProperty(
          'country-label',
          'visibility',
          'none',
        );

        // Masquer les labels de villes
        await _mapboxMap!.style.setStyleLayerProperty(
          'settlement-label',
          'visibility',
          'none',
        );

        // Masquer les labels de subdivision (états, régions)
        await _mapboxMap!.style.setStyleLayerProperty(
          'settlement-subdivision-label',
          'visibility',
          'none',
        );

        // Masquer les autres labels de texte
        await _mapboxMap!.style.setStyleLayerProperty(
          'state-label',
          'visibility',
          'none',
        );
      } catch (e) {
        print('Erreur lors de la configuration des labels: $e');
        // Ignorer les erreurs si certaines couches n'existent pas
      }
    }
    // Mode difficile : labels visibles (comportement par défaut)
  }

  /// Callback quand l'utilisateur clique sur la carte
  void _onMapTap(MapContentGestureContext context) {
    if (_hasGuessed) return;

    _mapboxMap?.coordinateForPixel(context.touchPosition).then((point) {
      setState(() {
        _guessLocation = point;
      });
      _addGuessMarker(point);
    });
  }

  /// Ajoute un marqueur bleu pour le guess de l'utilisateur
  void _addGuessMarker(Point point) async {
    if (_circleAnnotationManager == null) return;

    // Supprimer l'ancien marqueur de guess s'il existe
    if (_guessAnnotation != null) {
      _circleAnnotationManager!.delete(_guessAnnotation!);
    }

    // Créer un cercle bleu visible
    final annotation = await _circleAnnotationManager!.create(
      CircleAnnotationOptions(
        geometry: point,
        circleRadius: 12.0,
        circleColor: Colors.blue.value,
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.value,
      ),
    );

    _guessAnnotation = annotation as CircleAnnotation;
  }

  /// Valide le guess
  void _submitGuess() async {
    if (_guessLocation == null || _currentChallenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez placer un marqueur sur la carte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final difficulty = widget.config?.difficulty ?? Difficulty.easy;

    double distance = MapboxService.calculateDistance(
      _currentChallenge!.latitude,
      _currentChallenge!.longitude,
      _guessLocation!.coordinates.lat.toDouble(),
      _guessLocation!.coordinates.lng.toDouble(),
    );

    int score = 0;

    // Mode FACILE : vérifier si le guess est dans le bon pays
    if (difficulty == Difficulty.easy) {
      // Utiliser le service de géocodage inversé pour obtenir le pays du guess
      final guessedCountry = await _getCountryFromCoordinates(
        _guessLocation!.coordinates.lat.toDouble(),
        _guessLocation!.coordinates.lng.toDouble(),
      );

      if (guessedCountry != null &&
          guessedCountry.toLowerCase() == _currentChallenge!.correctCountry.toLowerCase()) {
        // Bon pays = 1000 points
        score = 1000;
        setState(() {
          _guessedCorrectCountry = true;
        });
      } else {
        // Mauvais pays : points basés sur la distance
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
    }
    // Mode MOYEN et DIFFICILE : système de points normal basé sur la distance
    else {
      score = MapboxService.calculateScore(distance);
    }

    setState(() {
      _hasGuessed = true;
      _currentScore += score;
      _currentRoundDistance = distance;
      _currentRoundScore = score;
    });

    _cancelTimer();
    _addCorrectAnswerMarker();
  }

  /// Obtient le nom du pays à partir de coordonnées en utilisant le géocodage inversé
  Future<String?> _getCountryFromCoordinates(double lat, double lng) async {
    try {
      final result = await GoogleGeocodingService.reverseGeocode(lat, lng);
      return result;
    } catch (e) {
      print('Erreur lors du géocodage inversé: $e');
      return null;
    }
  }

  /// Ajoute un marqueur vert pour la bonne réponse
  void _addCorrectAnswerMarker() async {
    if (_circleAnnotationManager == null || _currentChallenge == null) return;

    final correctPoint = Point(
      coordinates: Position(
        _currentChallenge!.longitude,
        _currentChallenge!.latitude,
      ),
    );

    // Mode facile : si le pays est correct, on ne montre que la zone verte du pays
    // Sinon on montre aussi le point exact de la ville
    final difficulty = widget.config?.difficulty ?? Difficulty.easy;

    if (difficulty != Difficulty.easy || !_guessedCorrectCountry) {
      // Créer un cercle vert visible pour la bonne réponse
      final annotation = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: correctPoint,
          circleRadius: 12.0,
          circleColor: Colors.green.value,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );

      _correctAnnotation = annotation as CircleAnnotation;
    }

    // Zoomer pour montrer les deux marqueurs
    if (_guessLocation != null) {
      _mapboxMap!.setCamera(CameraOptions(
        center: correctPoint,
        zoom: difficulty == Difficulty.easy && _guessedCorrectCountry ? 3.0 : 4.0,
      ));
    }

    // Mode facile : essayer de dessiner la frontière du pays
    if (difficulty == Difficulty.easy) {
      await _highlightCountryBorder();
    }
  }

  /// Tente de mettre en évidence le pays cible en mode facile
  Future<void> _highlightCountryBorder() async {
    if (_mapboxMap == null || _currentChallenge == null) return;

    try {
      // Pour mettre en évidence un pays, on pourrait utiliser plusieurs approches :
      // 1. API REST Countries avec données GeoJSON (nécessite téléchargement)
      // 2. Natural Earth data (fichiers locaux volumineux)
      // 3. Mapbox Tilequery API (limité)
      //
      // Pour l'instant, on utilise les couches Mapbox intégrées pour mettre en surbrillance
      // En attendant une solution plus robuste, on affiche un message dans la console

      print('🌍 Pays cible : ${_currentChallenge!.correctCountry}');
      print('🎯 Coordonnées : ${_currentChallenge!.latitude}, ${_currentChallenge!.longitude}');

      // TODO: Implémenter la surbrillance des frontières du pays
      // Cela nécessiterait l'ajout d'une source de données GeoJSON des pays

    } catch (e) {
      print('Erreur lors de la surbrillance du pays: $e');
    }
  }

  void _nextRound() {
    if (_roundNumber < _maxRounds) {
      setState(() {
        _roundNumber++;
        _currentRoundDistance = null;
        _currentRoundScore = null;
      });
      _loadNewChallenge();
    } else {
      _showFinalScore();
    }
  }

  void _showFinalScore() async {
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
          },
          child: const Text('Rejouer'),
        ),
      ],
    );
  }

  /// Sauvegarde le score dans la base de données
  Future<void> _saveHighScore() async {
    try {
      final highScore = HighScore(
        score: _currentScore,
        gameMode: 'map_guess',
        difficulty: _getDifficultyString(widget.config?.difficulty ?? Difficulty.easy),
        mapStyle: 'standard', // Style standard avec toutes les informations
        hasTimer: widget.config?.timerEnabled ?? false,
        timeLeft: (widget.config?.timerEnabled ?? false) ? _remainingSeconds : null,
        playedAt: DateTime.now(),
      );

      await DatabaseService.instance.saveHighScore(highScore);
      print('✅ Score sauvegardé: $_currentScore points');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du score: $e');
    }
  }

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

  /// Charge les données météo pour le défi actuel
  void _loadWeatherData() async {
    if (_currentChallenge == null) return;

    try {
      final weather = await WeatherService.getWeather(
        _currentChallenge!.latitude,
        _currentChallenge!.longitude,
      );

      setState(() {
        _weatherData = weather;
      });
    } catch (e) {
      print('Erreur lors du chargement des données météo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(' Trouve sur la Carte $_roundNumber/$_maxRounds', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.0445)),
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
                // Bandeau d'information en haut
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _hasGuessed
                          ? (_currentRoundScore != null && _currentRoundScore! >= 500
                              ? [Colors.green.shade700, Colors.green.shade500]
                              : [Colors.orange.shade700, Colors.orange.shade500])
                          : [Colors.blue.shade700, Colors.blue.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: !_hasGuessed
                      ? _buildChallengeDisplay()
                      : Column(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_currentRoundScore ?? 0} points',
                              style: const TextStyle(
                                fontSize: 56,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (!_guessedCorrectCountry) ...[
                              Text(
                                'Distance : ${_currentRoundDistance?.toStringAsFixed(0) ?? '0'} km',
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Votre guess',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Bonne réponse',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),

                // Carte Mapbox (prend tout l'espace disponible)
                Expanded(
                  child: MapWidget(
                    key: ValueKey(_currentChallenge),
                    styleUri: _getMapStyle(), // Style de carte selon la difficulté
                    onMapCreated: _onMapCreated,
                    onTapListener: _onMapTap,
                  ),
                ),

                // Bouton de validation en bas
                if (!_hasGuessed)
                  Container(
                    width: double.infinity,
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
                        if (_guessLocation != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Marqueur placé ! Validez votre réponse.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
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
                              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cliquez sur la carte pour placer votre marqueur',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_hasGuessed)
                  Container(
                    width: double.infinity,
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
                    child: ElevatedButton.icon(
                      onPressed: _nextRound,
                      icon: const Icon(Icons.arrow_forward, size: 24),
                      label: const Text(
                        'Round suivant',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildChallengeDisplay() {
    final difficulty = widget.config?.difficulty ?? Difficulty.easy;
    final mapHint = widget.config?.mapHint ?? MapHint.classic;

    String title = '';
    String subtitle = '';

    // Mode Capitale/Drapeau : afficher la capitale et le drapeau
    if (mapHint == MapHint.capitalFlag) {
      title = 'Quel est ce pays ?';
      subtitle = _currentChallenge!.correctCity;
    }
    // Mode Coordonnées : afficher uniquement les coordonnées GPS
    else if (mapHint == MapHint.coordinates) {
      if (difficulty == Difficulty.easy) {
        title = 'Quel pays se trouve à ces coordonnées ?';
      } else if (difficulty == Difficulty.medium) {
        title = 'Quelle capitale se trouve à ces coordonnées ?';
      } else if (difficulty == Difficulty.hard) {
        title = 'Quelle ville se trouve à ces coordonnées ?';
      }

      // Afficher les coordonnées GPS avec précision
      final lat = _currentChallenge!.latitude;
      final lng = _currentChallenge!.longitude;
      final latDir = lat >= 0 ? 'N' : 'S';
      final lngDir = lng >= 0 ? 'E' : 'O';

      subtitle = '${lat.abs().toStringAsFixed(4)}° $latDir, ${lng.abs().toStringAsFixed(4)}° $lngDir';
    }
    // Mode Météo/Climat : afficher les informations météo au lieu du nom
    else if (mapHint == MapHint.weatherClimate) {
      if (difficulty == Difficulty.easy) {
        title = 'Dans quel pays fait-il cette météo ?';
      } else if (difficulty == Difficulty.medium) {
        title = 'Dans quelle capitale fait-il cette météo ?';
      } else if (difficulty == Difficulty.hard) {
        title = 'Dans quelle ville fait-il cette météo ?';
      }

      // Afficher les données météo si disponibles
      if (_weatherData != null) {
        final temp = (_weatherData!['temperature'] as double).round();
        final emoji = _weatherData!['emoji'] as String;
        final description = _weatherData!['description'] as String;
        subtitle = '$emoji $temp°C - $description';
      } else {
        subtitle = '🔄 Chargement météo...';
      }
    }
    // Mode classique : afficher le nom du lieu
    else {
      if (difficulty == Difficulty.easy) {
        title = 'Où est ce pays ?';
        subtitle = _currentChallenge!.correctCountry;
      } else if (difficulty == Difficulty.medium) {
        title = 'Où est cette capitale ?';
        subtitle = _currentChallenge!.correctCity;
      } else if (difficulty == Difficulty.hard) {
        title = 'Où se trouve cette ville ?';
        subtitle = _currentChallenge!.correctCity;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Afficher le drapeau en mode Capitale/Drapeau
        if (mapHint == MapHint.capitalFlag) ...[
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _flagUrl != null
                    ? Image.network(
                        _flagUrl!,
                        width: 120,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 90,
                            color: Colors.grey,
                            child: const Icon(Icons.flag, color: Colors.white, size: 48),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 120,
                            height: 90,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 120,
                        height: 90,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Afficher une icône GPS en mode Coordonnées
        if (mapHint == MapHint.coordinates) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.gps_fixed,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        Center(
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: mapHint == MapHint.coordinates ? 28 : 32,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: mapHint == MapHint.coordinates ? 'monospace' : null,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Afficher les détails météo supplémentaires en mode météo/climat
        if (mapHint == MapHint.weatherClimate && _weatherData != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💧 Humidité: ${_weatherData!['humidity']}%',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '💨 Vent: ${(_weatherData!['windSpeed'] as double).round()} km/h',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🌡️ Ressenti: ${(_weatherData!['feelsLike'] as double).round()}°C',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        if (_timerEnabled) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _remainingSeconds <= 10
                  ? Colors.red.shade400
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$_remainingSeconds s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Récupère le code ISO2 d'un pays depuis la base de données
  Future<String?> _getCountryISO2Code(String countryName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'Locations',
        columns: ['iso2'],
        where: 'LOWER(country) = ?',
        whereArgs: [countryName.toLowerCase()],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return results.first['iso2'] as String?;
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération du code ISO2: $e');
      return null;
    }
  }

  /// Retourne le style de carte approprié selon la difficulté
  String _getMapStyle() {
    final difficulty = widget.config?.difficulty ?? Difficulty.easy;

    // Mode facile et moyen : style sans labels (classic du text guess)
    if (difficulty == Difficulty.easy || difficulty == Difficulty.medium) {
      return 'mapbox://styles/jeremyretille/cmghmue0j002h01r15n8z3xpu';
    }

    // Mode difficile : carte standard avec toutes les informations
    return MapboxStyles.STANDARD;
  }
}
