// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('geoguesser.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}