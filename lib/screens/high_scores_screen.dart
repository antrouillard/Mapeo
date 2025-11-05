// lib/screens/high_scores_screen.dart
import 'package:flutter/material.dart';
import '../models/high_score.dart';
import '../services/db_service.dart';

/// Écran d'affichage des meilleurs scores
class HighScoresScreen extends StatefulWidget {
  const HighScoresScreen({Key? key}) : super(key: key);

  @override
  State<HighScoresScreen> createState() => _HighScoresScreenState();
}

class _HighScoresScreenState extends State<HighScoresScreen> {
  List<HighScore> _highScores = [];
  bool _isLoading = true;

  // Filtres
  String? _selectedGameMode;
  String? _selectedDifficulty;
  String? _selectedMapStyle;
  bool? _selectedTimerMode;

  @override
  void initState() {
    super.initState();
    _loadHighScores();
  }

  /// Charge les high scores depuis la base de données
  Future<void> _loadHighScores() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final scores = await DatabaseService.instance.getHighScoresByConfig(
        gameMode: _selectedGameMode,
        difficulty: _selectedDifficulty,
        mapStyle: _selectedMapStyle,
        hasTimer: _selectedTimerMode,
        limit: 50, // Limiter à 50 meilleurs scores
      );

      setState(() {
        _highScores = scores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des scores: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Réinitialise tous les filtres
  void _resetFilters() {
    setState(() {
      _selectedGameMode = null;
      _selectedDifficulty = null;
      _selectedMapStyle = null;
      _selectedTimerMode = null;
    });
    _loadHighScores();
  }

  /// Affiche une boîte de dialogue pour sélectionner les filtres
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrer les scores'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mode de jeu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildGameModeFilter(),
              const SizedBox(height: 16),
              const Text(
                'Difficulté',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildDifficultyFilter(),
              const SizedBox(height: 16),
              const Text(
                'Style de carte',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildMapStyleFilter(),
              const SizedBox(height: 16),
              const Text(
                'Mode timer',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildTimerModeFilter(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetFilters();
            },
            child: const Text('Réinitialiser'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadHighScores();
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  Widget _buildGameModeFilter() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('Tous'),
          selected: _selectedGameMode == null,
          onSelected: (selected) {
            setState(() {
              _selectedGameMode = null;
            });
          },
        ),
        FilterChip(
          label: const Text('Text Guess'),
          selected: _selectedGameMode == 'text_guess',
          onSelected: (selected) {
            setState(() {
              _selectedGameMode = selected ? 'text_guess' : null;
            });
          },
        ),
        FilterChip(
          label: const Text('Map Guess'),
          selected: _selectedGameMode == 'map_guess',
          onSelected: (selected) {
            setState(() {
              _selectedGameMode = selected ? 'map_guess' : null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDifficultyFilter() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('Tous'),
          selected: _selectedDifficulty == null,
          onSelected: (selected) {
            setState(() {
              _selectedDifficulty = null;
            });
          },
        ),
        FilterChip(
          label: const Text('Facile'),
          selected: _selectedDifficulty == 'easy',
          onSelected: (selected) {
            setState(() {
              _selectedDifficulty = selected ? 'easy' : null;
            });
          },
        ),
        FilterChip(
          label: const Text('Moyen'),
          selected: _selectedDifficulty == 'medium',
          onSelected: (selected) {
            setState(() {
              _selectedDifficulty = selected ? 'medium' : null;
            });
          },
        ),
        FilterChip(
          label: const Text('Difficile'),
          selected: _selectedDifficulty == 'hard',
          onSelected: (selected) {
            setState(() {
              _selectedDifficulty = selected ? 'hard' : null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMapStyleFilter() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('Tous'),
          selected: _selectedMapStyle == null,
          onSelected: (selected) {
            setState(() {
              _selectedMapStyle = null;
            });
          },
        ),
        FilterChip(
          label: const Text('Classic'),
          selected: _selectedMapStyle == 'classic',
          onSelected: (selected) {
            setState(() {
              _selectedMapStyle = selected ? 'classic' : null;
            });
          },
        ),
        FilterChip(
          label: const Text('N&B'),
          selected: _selectedMapStyle == 'blackAndWhite',
          onSelected: (selected) {
            setState(() {
              _selectedMapStyle = selected ? 'blackAndWhite' : null;
            });
          },
        ),
        FilterChip(
          label: const Text('Sans frontières'),
          selected: _selectedMapStyle == 'noBorders',
          onSelected: (selected) {
            setState(() {
              _selectedMapStyle = selected ? 'noBorders' : null;
            });
          },
        ),
        FilterChip(
          label: const Text('Satellite'),
          selected: _selectedMapStyle == 'satellite',
          onSelected: (selected) {
            setState(() {
              _selectedMapStyle = selected ? 'satellite' : null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTimerModeFilter() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('Tous'),
          selected: _selectedTimerMode == null,
          onSelected: (selected) {
            setState(() {
              _selectedTimerMode = null;
            });
          },
        ),
        FilterChip(
          label: const Text('Avec timer'),
          selected: _selectedTimerMode == true,
          onSelected: (selected) {
            setState(() {
              _selectedTimerMode = selected ? true : null;
            });
          },
        ),
        FilterChip(
          label: const Text('Sans timer'),
          selected: _selectedTimerMode == false,
          onSelected: (selected) {
            setState(() {
              _selectedTimerMode = selected ? false : null;
            });
          },
        ),
      ],
    );
  }

  /// Retourne un texte lisible pour le mode de jeu
  String _getGameModeText(String gameMode) {
    switch (gameMode) {
      case 'text_guess':
        return 'Text Guess';
      case 'map_guess':
        return 'Map Guess';
      default:
        return gameMode;
    }
  }

  /// Retourne un texte lisible pour la difficulté
  String _getDifficultyText(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Facile';
      case 'medium':
        return 'Moyen';
      case 'hard':
        return 'Difficile';
      default:
        return difficulty;
    }
  }

  /// Retourne un texte lisible pour le style de carte
  String _getMapStyleText(String mapStyle) {
    switch (mapStyle) {
      case 'classic':
        return 'Classic';
      case 'blackAndWhite':
        return 'Noir & Blanc';
      case 'noBorders':
        return 'Sans frontières';
      case 'satellite':
        return 'Satellite';
      default:
        return mapStyle;
    }
  }

  /// Retourne une icône selon la position dans le classement
  Widget _getRankIcon(int index) {
    if (index == 0) {
      return const Icon(Icons.emoji_events, color: Colors.amber, size: 28);
    } else if (index == 1) {
      return const Icon(Icons.emoji_events, color: Colors.grey, size: 24);
    } else if (index == 2) {
      return const Icon(Icons.emoji_events, color: Colors.brown, size: 22);
    } else {
      return Text(
        '${index + 1}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      );
    }
  }

  /// Retourne une couleur selon la position dans le classement
  Color _getRankColor(int index) {
    if (index == 0) {
      return Colors.amber.shade50;
    } else if (index == 1) {
      return Colors.grey.shade100;
    } else if (index == 2) {
      return Colors.brown.shade50;
    } else {
      return Colors.white;
    }
  }

  /// Formate la date de la partie
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Aujourd'hui à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays == 1) {
      return "Hier à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('High Scores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtrer',
          ),
          if (_selectedGameMode != null ||
              _selectedDifficulty != null ||
              _selectedMapStyle != null ||
              _selectedTimerMode != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _resetFilters,
              tooltip: 'Réinitialiser les filtres',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _highScores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun score enregistré',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Jouez une partie pour voir vos scores ici !',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // En-tête avec statistiques
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${_highScores.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const Text(
                                'Parties',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${_highScores.isNotEmpty ? _highScores.first.score : 0}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                              const Text(
                                'Meilleur',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                _highScores.isNotEmpty
                                    ? '${(_highScores.map((s) => s.score).reduce((a, b) => a + b) / _highScores.length).toStringAsFixed(0)}'
                                    : '0',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'Moyenne',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Liste des scores
                    Expanded(
                      child: ListView.builder(
                        itemCount: _highScores.length,
                        itemBuilder: (context, index) {
                          final score = _highScores[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            color: _getRankColor(index),
                            elevation: index < 3 ? 4 : 1,
                            child: ListTile(
                              leading: SizedBox(
                                width: 40,
                                child: Center(child: _getRankIcon(index)),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    '${score.score} pts',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (score.hasTimer)
                                    const Icon(
                                      Icons.timer,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_getGameModeText(score.gameMode)} • '
                                    '${_getDifficultyText(score.difficulty)} • '
                                    '${_getMapStyleText(score.mapStyle)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(score.playedAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: score.hasTimer && score.timeLeft != null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.access_time, size: 16),
                                        Text(
                                          '${score.timeLeft}s',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
