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
  PointAnnotationManager? _annotationManager;
  Challenge? _currentChallenge;
  Point? _guessLocation;
  bool _hasGuessed = false;
  int _currentScore = 0;
  int _roundNumber = 1;
  final int _maxRounds = 5;
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNewChallenge();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _loadNewChallenge() {
    setState(() {
      _currentChallenge = MapboxService.generateRandomLocation();
      _guessLocation = null;
      _hasGuessed = false;
      _cityController.clear();
      _countryController.clear();
    });

    _annotationManager?.deleteAll();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
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


  void _onMapTap(MapContentGestureContext context) {
    if (_hasGuessed) return;

    _mapboxMap?.coordinateForPixel(context.touchPosition).then((point) {
      setState(() {
        _guessLocation = point;
      });
      _addGuessMarker(point);
    });
  }

  void _addGuessMarker(Point point) async {
    if (_annotationManager == null) return;

    await _annotationManager!.deleteAll();

    _annotationManager!.create(
      PointAnnotationOptions(
        geometry: point,
        iconImage: "default_marker",
        iconSize: 1.5,
        iconColor: Colors.red.value,
      ),
    );
  }

  void _submitGuess() {
    if (_guessLocation == null || _currentChallenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez placer un marqueur sur la carte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

    _addCorrectAnswerMarker();

    // Afficher le résultat
    _showResultDialog(distance, score);
  }

  void _addCorrectAnswerMarker() async {
    if (_annotationManager == null || _currentChallenge == null) return;

    final correctPoint = Point(
      coordinates: Position(
        _currentChallenge!.longitude,
        _currentChallenge!.latitude,
      ),
    );

    _annotationManager!.create(
      PointAnnotationOptions(
        geometry: correctPoint,
        iconImage: "default_marker",
        iconSize: 1.5,
        iconColor: Colors.green.value,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.red,
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
                  styleUri: 'mapbox://styles/jeremyretille/cmghmue0j002h01r15n8z3xpu',
                  onMapCreated: _onMapCreated,
                  onTapListener: _onMapTap,
                ),
                if (!_hasGuessed)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Où pensez-vous être ?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Cliquez sur la carte pour placer un marqueur',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (_guessLocation != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.red, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Marqueur placé',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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