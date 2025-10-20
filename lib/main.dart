// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/game_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/google_geocoding_service.dart';
import 'screens/mode_selection_screen.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapeo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Écran d'accueil avec le menu principal
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Contrôleur pour le champ de texte du géocodage
  final TextEditingController _geocodeController = TextEditingController();

  // État pour afficher/masquer la barre de géocodage
  bool _showGeocodeBar = false;

  // Message de résultat du géocodage
  String _geocodeResult = '';

  @override
  void dispose() {
    _geocodeController.dispose();
    super.dispose();
  }

  /// Appelle l'API Google Geocoding et affiche le résultat
  Future<void> _testGeocode() async {
    final query = _geocodeController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _geocodeResult = '⚠️ Veuillez entrer une adresse';
      });
      return;
    }

    setState(() {
      _geocodeResult = '🔄 Recherche en cours...';
    });

    try {
      final point = await GoogleGeocodingService.geocodeAddress(query);

      if (!mounted) return;

      if (point == null) {
        setState(() {
          _geocodeResult = '❌ Aucun résultat trouvé';
        });
        return;
      }

      setState(() {
        _geocodeResult = '✅ Coordonnées Mapbox:\n'
            'Longitude: ${point.coordinates.lng.toStringAsFixed(6)}\n'
            'Latitude: ${point.coordinates.lat.toStringAsFixed(6)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _geocodeResult = '❌ Erreur: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapeo'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.public,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 40),
            const Text(
              'Bienvenue sur Mapeo',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Devinez où vous êtes dans le monde !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 60),

            // Bouton pour sélectionner le mode de jeu
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ModeSelectionScreen()),
                );
              },
              icon: const Icon(Icons.sports_esports),
              label: const Text('Choisir un mode'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 12),

            // Bouton pour partie rapide (mode par défaut)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              },
              icon: const Icon(Icons.flash_on),
              label: const Text('Partie rapide'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 20),

            // Bouton pour tester le géocodage Google
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showGeocodeBar = !_showGeocodeBar;
                  if (!_showGeocodeBar) {
                    _geocodeController.clear();
                    _geocodeResult = '';
                  }
                });
              },
              icon: Icon(_showGeocodeBar ? Icons.keyboard_arrow_up : Icons.search),
              label: Text(_showGeocodeBar ? 'Masquer le test de géocodage' : 'Tester le géocodage (Google)'),
            ),

            // Barre de saisie pour le géocodage (mode test - servira pour futur mode de jeu)
            if (_showGeocodeBar) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Test de géocodage',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cette barre servira dans un futur mode de jeu où vous devrez deviner le nom du lieu.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _geocodeController,
                          decoration: const InputDecoration(
                            hintText: 'Ex: 10 Downing St, London',
                            labelText: 'Adresse',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          onSubmitted: (_) => _testGeocode(),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _testGeocode,
                          icon: const Icon(Icons.search),
                          label: const Text('Géocoder'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                        if (_geocodeResult.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _geocodeResult.contains('✅')
                                  ? Colors.green.shade50
                                  : _geocodeResult.contains('❌')
                                      ? Colors.red.shade50
                                      : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _geocodeResult,
                              style: const TextStyle(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}