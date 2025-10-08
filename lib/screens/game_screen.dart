// lib/screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/mapbox_service.dart';
import '../models/challenge.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  MapboxMap? _mapboxMap;
  Challenge? _currentChallenge;
  Point? _guessLocation;
  bool _hasGuessed = false;
  int _currentScore = 0;
  int _roundNumber = 1;
  final int _maxRounds = 5;

  @override
  void initState() {
    super.initState();
    _loadNewChallenge();
  }

  void _loadNewChallenge() {
    setState(() {
      _currentChallenge = MapboxService.generateRandomLocation();
      _guessLocation = null;
      _hasGuessed = false;
    });
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _centerMapOnChallenge();
  }

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

  void _onMapTap(Point point) {
    if (_hasGuessed) return;

    setState(() {
      _guessLocation = point;
    });

    // Ajouter un marqueur sur la carte
    _addMarker(point);
  }

  void _addMarker(Point point) async {
    if (_mapboxMap == null) return;

    final pointAnnotationManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();

    pointAnnotationManager.create(
      PointAnnotationOptions(
        geometry: point,
        iconImage: "default_marker",
        iconSize: 1.5,
      ),
    );
  }

  void _submitGuess() {
    if (_guessLocation == null || _currentChallenge == null) return;

    final distance = MapboxService.calculateDistance(
      _currentChallenge!.latitude,
      _currentChallenge!.longitude,
      _guessLocation!.coordinates.lat.toDouble(),
      _guessLocation!.coordinates.lng.toDouble(),
    );

    final score = MapboxService.calculateScore(distance);

    setState(() {
      _hasGuessed = true;
      _currentScore += score;
    });

    // Afficher le résultat
    _showResultDialog(distance, score);
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
        title: Text('Round $_roundNumber/$_maxRounds'),
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
          : Stack(
              children: [
                MapWidget(
                  key: ValueKey(_currentChallenge),
                  styleUri: MapboxStyles.MAPBOX_STREETS, // Utilisez votre style personnalisé ici
                  onMapCreated: _onMapCreated,
                  onTapListener: _onMapTap,
                ),
                if (!_hasGuessed && _guessLocation != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: _submitGuess,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Valider ma réponse',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}