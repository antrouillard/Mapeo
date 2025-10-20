// lib/screens/text_guess_game_screen.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/mapbox_service.dart';
import '../services/google_geocoding_service.dart';
import '../models/challenge.dart';
import '../models/game_mode.dart';

/// Écran de jeu pour le mode Guess Textuel
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

  // Défi actuel (lieu à deviner)
  Challenge? _currentChallenge;

  // Position de la réponse géocodée à partir du texte
  Point? _guessLocation;

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

  // État du géocodage
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _loadNewChallenge();
  }

  @override
  void dispose() {
    _guessController.dispose();
    super.dispose();
  }

  /// Charge un nouveau défi (lieu aléatoire)
  void _loadNewChallenge() {
    setState(() {
      _currentChallenge = MapboxService.generateRandomLocation();
      _guessLocation = null;
      _hasGuessed = false;
      _guessController.clear();
      _guessAnnotation = null;
      _correctAnnotation = null;
      _isGeocoding = false;
    });

    // Supprime tous les marqueurs au début d'un nouveau challenge
    _annotationManager?.deleteAll();
  }

  /// Callback appelé quand la carte est créée
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
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
        // TODO: Créer un style noir et blanc sur Mapbox Studio
        return 'mapbox://styles/mapbox/light-v11';
      case MapStyle.noBorders:
        // TODO: Créer un style sans frontières sur Mapbox Studio
        return 'mapbox://styles/jeremyretille/cmghmue0j002h01r15n8z3xpu';
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
      // Appeler l'API Google Geocoding
      final point = await GoogleGeocodingService.geocodeAddress(query);

      if (!mounted) return;

      if (point == null) {
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
        _guessLocation = point;
        _isGeocoding = false;
      });

      // Ajouter un marqueur bleu pour la réponse
      _addGuessMarker(point);

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

    // Créer le nouveau marqueur bleu
    _guessAnnotation = await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: point,
        iconImage: "default_marker",
        iconSize: 1.5,
        iconColor: Colors.blue.toARGB32(),
      ),
    );

    // NE PAS déplacer la caméra pour ne pas révéler la position du guess
    // La caméra se déplacera seulement après validation pour montrer les deux marqueurs
  }

  /// Valide le guess de l'utilisateur et affiche le résultat
  void _submitGuess() {
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

    // Calculer la distance entre le guess et la bonne réponse
    final distance = MapboxService.calculateDistance(
      _currentChallenge!.latitude,
      _currentChallenge!.longitude,
      _guessLocation!.coordinates.lat.toDouble(),
      _guessLocation!.coordinates.lng.toDouble(),
    );

    // Calculer le score en fonction de la distance
    final score = MapboxService.calculateScore(distance);

    setState(() {
      _hasGuessed = true;
      _currentScore += score;
    });

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
        iconImage: "default_marker",
        iconSize: 1.5,
        iconColor: Colors.green.toARGB32(),
      ),
    );
  }

  void _showResultDialog(double distance, int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Round $_roundNumber/$_maxRounds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vous étiez à ${distance.toStringAsFixed(1)} km !',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Score: $score points'),
            const SizedBox(height: 10),
            Text(
              'Réponse: ${_currentChallenge!.correctCity}, '
              '${_currentChallenge!.correctCountry}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),
            Text(
              'Votre réponse: "${_guessController.text}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Votre réponse'),
                const SizedBox(width: 20),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Réponse correcte'),
              ],
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

  void _showFinalScore() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Partie terminée !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 20),
            Text(
              'Score total: $_currentScore',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Moyenne: ${(_currentScore / _maxRounds).toStringAsFixed(0)} pts/round',
            ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapeo Textuel - Round $_roundNumber/$_maxRounds'),
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
                  child: MapWidget(
                    key: ValueKey(_currentChallenge),
                    styleUri: _getMapStyleUri(),
                    onMapCreated: _onMapCreated,
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

