// lib/screens/mode_selection_screen.dart
import 'package:flutter/material.dart';
import '../models/game_mode.dart';
import 'game_screen.dart';
import 'text_guess_game_screen.dart';

/// Écran de sélection du mode de jeu
class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  // Configuration actuelle
  GuessType _selectedGuessType = GuessType.map;
  MapHint? _selectedMapHint;
  MapStyle? _selectedMapStyle;
  Difficulty _selectedDifficulty = Difficulty.easy;
  bool _timerEnabled = false;
  double _timerDuration = 60.0; // En secondes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélection du mode'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titre principal
            const Text(
              'Choisis ton mode de jeu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Personnalise ton expérience de jeu',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // === SECTION 1: Type de Guess ===
            _buildSectionTitle('1. Type de Guess', Icons.touch_app),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGuessTypeCard(
                    type: GuessType.map,
                    title: 'Guess sur Map',
                    description: 'Clique sur la carte',
                    icon: Icons.map,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGuessTypeCard(
                    type: GuessType.text,
                    title: 'Guess Textuel',
                    description: 'Tape le nom du lieu',
                    icon: Icons.text_fields,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // === SECTION 2: Mode spécifique ===
            if (_selectedGuessType == GuessType.map) ...[
              _buildSectionTitle('2. Indices disponibles', Icons.info_outline),
              const SizedBox(height: 16),
              _buildMapHintsGrid(),
            ] else ...[
              _buildSectionTitle('2. Style de carte', Icons.palette),
              const SizedBox(height: 16),
              _buildMapStylesGrid(),
            ],
            const SizedBox(height: 32),

            // === SECTION 3: Modificateurs ===
            _buildSectionTitle('3. Modificateurs', Icons.tune),
            const SizedBox(height: 16),

            // Difficulté
            const Text(
              'Difficulté (ce que tu dois deviner)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildDifficultyCards(),
            const SizedBox(height: 24),

            // Mode Timer
            _buildTimerCard(),
            const SizedBox(height: 32),

            // === Résumé et bouton de démarrage ===
            _buildConfigSummary(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text(
                'Commencer la partie',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Construction du titre de section
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Carte pour sélectionner le type de guess
  Widget _buildGuessTypeCard({
    required GuessType type,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedGuessType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGuessType = type;
          // Réinitialiser les sélections spécifiques
          if (type == GuessType.map) {
            _selectedMapStyle = null;
          } else {
            _selectedMapHint = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? color : Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Icon(Icons.check_circle, color: color, size: 24),
            ],
          ],
        ),
      ),
    );
  }

  /// Grille des indices pour le guess sur map
  Widget _buildMapHintsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                title: 'Classique',
                icon: Icons.location_on,
                color: Colors.blue,
                isSelected: _selectedMapHint == MapHint.classic,
                onTap: () {
                  setState(() {
                    _selectedMapHint = _selectedMapHint == MapHint.classic
                        ? null
                        : MapHint.classic;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeCard(
                title: 'Météo/Climat',
                icon: Icons.wb_sunny,
                color: Colors.orange,
                isSelected: _selectedMapHint == MapHint.weatherClimate,
                onTap: () {
                  setState(() {
                    _selectedMapHint = _selectedMapHint == MapHint.weatherClimate
                        ? null
                        : MapHint.weatherClimate;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                title: 'Capitale/Drapeau',
                icon: Icons.flag,
                color: Colors.purple,
                isSelected: _selectedMapHint == MapHint.capitalFlag,
                onTap: () {
                  setState(() {
                    _selectedMapHint = _selectedMapHint == MapHint.capitalFlag
                        ? null
                        : MapHint.capitalFlag;
                    // Mode Capitale/Drapeau : forcer la difficulté sur Facile
                    if (_selectedMapHint == MapHint.capitalFlag) {
                      _selectedDifficulty = Difficulty.easy;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeCard(
                title: 'Coordonnées',
                subtitle: 'HARDCORE',
                icon: Icons.gps_fixed,
                color: Colors.red,
                isSelected: _selectedMapHint == MapHint.coordinates,
                onTap: () {
                  setState(() {
                    _selectedMapHint = _selectedMapHint == MapHint.coordinates
                        ? null
                        : MapHint.coordinates;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Grille des styles de carte pour le guess textuel
  Widget _buildMapStylesGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                title: 'Classique',
                icon: Icons.map,
                color: Colors.blue,
                isSelected: _selectedMapStyle == MapStyle.classic,
                onTap: () {
                  setState(() {
                    _selectedMapStyle = _selectedMapStyle == MapStyle.classic
                        ? null
                        : MapStyle.classic;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeCard(
                title: 'Noir & Blanc',
                icon: Icons.filter_b_and_w,
                color: Colors.grey[800]!,
                isSelected: _selectedMapStyle == MapStyle.blackAndWhite,
                onTap: () {
                  setState(() {
                    _selectedMapStyle = _selectedMapStyle == MapStyle.blackAndWhite
                        ? null
                        : MapStyle.blackAndWhite;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                title: 'Sans Frontières',
                icon: Icons.border_clear,
                color: Colors.teal,
                isSelected: _selectedMapStyle == MapStyle.noBorders,
                onTap: () {
                  setState(() {
                    _selectedMapStyle = _selectedMapStyle == MapStyle.noBorders
                        ? null
                        : MapStyle.noBorders;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeCard(
                title: 'Satellite',
                icon: Icons.satellite_alt,
                color: Colors.indigo,
                isSelected: _selectedMapStyle == MapStyle.satellite,
                onTap: () {
                  setState(() {
                    _selectedMapStyle = _selectedMapStyle == MapStyle.satellite
                        ? null
                        : MapStyle.satellite;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Carte générique pour un mode/option
  Widget _buildModeCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? color : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (isSelected) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle, color: color, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  /// Cartes de difficulté
  Widget _buildDifficultyCards() {
    return Row(
      children: [
        Expanded(
          child: _buildDifficultyCard(
            difficulty: Difficulty.easy,
            title: 'FACILE',
            subtitle: 'Deviner le pays',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDifficultyCard(
            difficulty: Difficulty.medium,
            title: 'MOYEN',
            subtitle: 'Deviner la capitale',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDifficultyCard(
            difficulty: Difficulty.hard,
            title: 'DIFFICILE',
            subtitle: 'Deviner la région',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  /// Carte de difficulté individuelle
  Widget _buildDifficultyCard({
    required Difficulty difficulty,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedDifficulty == difficulty;
    // Désactiver les difficultés autres que Facile en mode Capitale/Drapeau
    final isDisabled = _selectedMapHint == MapHint.capitalFlag && difficulty != Difficulty.easy;

    return GestureDetector(
      onTap: isDisabled ? null : () {
        setState(() {
          _selectedDifficulty = difficulty;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey[200]
              : (isSelected ? color.withOpacity(0.15) : Colors.white),
          border: Border.all(
            color: isDisabled
                ? Colors.grey[300]!
                : (isSelected ? color : Colors.grey[300]!),
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDisabled
                    ? Colors.grey[400]
                    : (isSelected ? color : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDisabled ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected && !isDisabled) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle, color: color, size: 18),
            ],
            if (isDisabled) ...[
              const SizedBox(height: 6),
              Icon(Icons.lock, color: Colors.grey[400], size: 18),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte pour le mode timer avec slider
  Widget _buildTimerCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _timerEnabled ? Colors.blue : Colors.grey[300]!,
          width: _timerEnabled ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.timer,
                  color: _timerEnabled ? Colors.blue : Colors.grey[600],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Timer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _timerEnabled ? Colors.blue : Colors.black87,
                        ),
                      ),
                      Text(
                        'Limite de temps par round',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _timerEnabled,
                  onChanged: (value) {
                    setState(() {
                      _timerEnabled = value;
                    });
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
            if (_timerEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Durée: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${_timerDuration.toInt()} secondes',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _timerDuration,
                min: 15,
                max: 180,
                divisions: 11, // 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180
                label: '${_timerDuration.toInt()}s',
                onChanged: (value) {
                  setState(() {
                    _timerDuration = value;
                  });
                },
                activeColor: Colors.blue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Résumé de la configuration actuelle
  Widget _buildConfigSummary() {
    final config = GameConfiguration(
      guessType: _selectedGuessType,
      mapHint: _selectedMapHint,
      mapStyle: _selectedMapStyle,
      difficulty: _selectedDifficulty,
      timerEnabled: _timerEnabled,
      timerDuration: _timerDuration.toInt(),
    );

    return Card(
      elevation: 3,
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.summarize, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Résumé de ta configuration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              config.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Démarre la partie avec la configuration actuelle
  void _startGame() {
    final config = GameConfiguration(
      guessType: _selectedGuessType,
      mapHint: _selectedMapHint,
      mapStyle: _selectedMapStyle,
      difficulty: _selectedDifficulty,
      timerEnabled: _timerEnabled,
      timerDuration: _timerDuration.toInt(),
    );

    // Rediriger vers le bon écran selon le type de guess
    Widget gameScreen;

    if (config.guessType == GuessType.text) {
      // Mode Guess Textuel
      gameScreen = TextGuessGameScreen(config: config);
    } else {
      // Mode Guess sur Map (pour l'instant utilise l'écran existant)
      gameScreen = GameScreen(config: config);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    );
  }
}
