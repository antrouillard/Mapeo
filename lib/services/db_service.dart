// lib/services/db_service.dart
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/high_score.dart';

/// Service pour gérer les sessions de jeu et les statistiques
/// Utilise DatabaseHelper pour la base de données principale
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();

  DatabaseService._init();

  /// Récupère la base de données via DatabaseHelper
  Future<Database> get database async {
    return await DatabaseHelper.instance.database;
  }

  /// Crée les tables pour les sessions de jeu si elles n'existent pas
  Future<void> _ensureGameTablesExist() async {
    final db = await database;

    // Vérifier si la table game_sessions existe
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='game_sessions'",
    );

    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE game_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_time TEXT NOT NULL,
          end_time TEXT,
          total_score INTEGER DEFAULT 0,
          game_mode TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE rounds (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          round_number INTEGER NOT NULL,
          correct_lat REAL NOT NULL,
          correct_lng REAL NOT NULL,
          guess_lat REAL,
          guess_lng REAL,
          distance_km REAL,
          score INTEGER DEFAULT 0,
          correct_country TEXT,
          correct_city TEXT,
          FOREIGN KEY (session_id) REFERENCES game_sessions (id)
        )
      ''');
    }
  }

  /// Crée une nouvelle session de jeu
  Future<int> createGameSession(String gameMode) async {
    await _ensureGameTablesExist();
    final db = await database;

    return await db.insert(
      'game_sessions',
      {
        'start_time': DateTime.now().toIso8601String(),
        'game_mode': gameMode,
        'total_score': 0,
      },
    );
  }

  /// Enregistre un round de jeu
  Future<void> saveRound({
    required int sessionId,
    required int roundNumber,
    required double correctLat,
    required double correctLng,
    double? guessLat,
    double? guessLng,
    double? distanceKm,
    int score = 0,
    String? correctCountry,
    String? correctCity,
  }) async {
    await _ensureGameTablesExist();
    final db = await database;

    await db.insert(
      'rounds',
      {
        'session_id': sessionId,
        'round_number': roundNumber,
        'correct_lat': correctLat,
        'correct_lng': correctLng,
        'guess_lat': guessLat,
        'guess_lng': guessLng,
        'distance_km': distanceKm,
        'score': score,
        'correct_country': correctCountry,
        'correct_city': correctCity,
      },
    );
  }

  /// Met à jour le score total d'une session
  Future<void> updateSessionScore(int sessionId, int totalScore) async {
    await _ensureGameTablesExist();
    final db = await database;

    await db.update(
      'game_sessions',
      {'total_score': totalScore},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Termine une session de jeu
  Future<void> endGameSession(int sessionId) async {
    await _ensureGameTablesExist();
    final db = await database;

    await db.update(
      'game_sessions',
      {'end_time': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Récupère l'historique des sessions de jeu
  Future<List<Map<String, dynamic>>> getGameSessions({int limit = 10}) async {
    await _ensureGameTablesExist();
    final db = await database;

    return await db.query(
      'game_sessions',
      orderBy: 'start_time DESC',
      limit: limit,
    );
  }

  /// Récupère les rounds d'une session
  Future<List<Map<String, dynamic>>> getSessionRounds(int sessionId) async {
    await _ensureGameTablesExist();
    final db = await database;

    return await db.query(
      'rounds',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'round_number ASC',
    );
  }

  /// Sauvegarde un nouveau high score dans la base de données
  Future<int> saveHighScore(HighScore highScore) async {
    final db = await database;
    final id = await db.insert(
      'high_scores',
      highScore.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Score enregistré: ${highScore.score} points (ID: $id)');
    return id;
  }

  /// Récupère tous les high scores triés par score décroissant
  Future<List<HighScore>> getAllHighScores({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'high_scores',
      orderBy: 'score DESC, played_at DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return HighScore.fromMap(maps[i]);
    });
  }

  /// Récupère les high scores filtrés par configuration
  Future<List<HighScore>> getHighScoresByConfig({
    String? gameMode,
    String? difficulty,
    String? mapStyle,
    bool? hasTimer,
    int? limit,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (gameMode != null) {
      whereClause += 'game_mode = ?';
      whereArgs.add(gameMode);
    }

    if (difficulty != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'difficulty = ?';
      whereArgs.add(difficulty);
    }

    if (mapStyle != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'map_style = ?';
      whereArgs.add(mapStyle);
    }

    if (hasTimer != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'has_timer = ?';
      whereArgs.add(hasTimer ? 1 : 0);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'high_scores',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'score DESC, played_at DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return HighScore.fromMap(maps[i]);
    });
  }

  /// Récupère le meilleur score pour une configuration donnée
  Future<HighScore?> getBestScore({
    required String gameMode,
    required String difficulty,
    required String mapStyle,
    required bool hasTimer,
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'high_scores',
      where: 'game_mode = ? AND difficulty = ? AND map_style = ? AND has_timer = ?',
      whereArgs: [gameMode, difficulty, mapStyle, hasTimer ? 1 : 0],
      orderBy: 'score DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return HighScore.fromMap(maps.first);
  }

  /// Récupère le nombre total de parties jouées
  Future<int> getTotalGamesPlayed() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM high_scores');
    return result.first['count'] as int;
  }

  /// Supprime tous les scores (utile pour réinitialiser)
  Future<void> clearAllScores() async {
    final db = await database;
    await db.delete('high_scores');
    print('Tous les scores ont été supprimés');
  }

  /// Supprime un score spécifique par ID
  Future<void> deleteScore(int id) async {
    final db = await database;
    await db.delete(
      'high_scores',
      where: 'id = ?',
      whereArgs: [id],
    );
    print('Score $id supprimé');
  }
}