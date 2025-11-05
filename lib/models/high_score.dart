class HighScore {
  final int? id;
  final int score;
  final String gameMode; // 'text_guess', 'map_guess', etc.
  final String difficulty; // 'easy', 'medium', 'hard'
  final String mapStyle; // 'classic', 'satellite', 'modern'
  final bool hasTimer;
  final int? timeLeft; // temps restant en secondes si timer activé
  final DateTime playedAt;

  HighScore({
    this.id,
    required this.score,
    required this.gameMode,
    required this.difficulty,
    required this.mapStyle,
    required this.hasTimer,
    this.timeLeft,
    required this.playedAt,
  });

  // Convertir en Map pour la base de données
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'score': score,
      'game_mode': gameMode,
      'difficulty': difficulty,
      'map_style': mapStyle,
      'has_timer': hasTimer ? 1 : 0,
      'time_left': timeLeft,
      'played_at': playedAt.millisecondsSinceEpoch,
    };
  }

  // Créer un HighScore depuis un Map de la base de données
  factory HighScore.fromMap(Map<String, dynamic> map) {
    return HighScore(
      id: map['id'],
      score: map['score'],
      gameMode: map['game_mode'],
      difficulty: map['difficulty'],
      mapStyle: map['map_style'],
      hasTimer: map['has_timer'] == 1,
      timeLeft: map['time_left'],
      playedAt: DateTime.fromMillisecondsSinceEpoch(map['played_at']),
    );
  }

  @override
  String toString() {
    return 'HighScore{id: $id, score: $score, gameMode: $gameMode, difficulty: $difficulty, mapStyle: $mapStyle, hasTimer: $hasTimer, timeLeft: $timeLeft, playedAt: $playedAt}';
  }
}

