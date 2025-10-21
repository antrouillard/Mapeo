import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Helper pour gérer la base de données SQLite
class DatabaseHelper {

  static  String ACCESS_TOKEN = dotenv.env["MAPBOX_ACCESS_TOKEN"] ?? "";
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Récupère l'instance de la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mapeo_locations.db');
    return _database!;
  }

  /// Initialise la base de données
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        // Vérifier si la base est vide et importer le CSV si nécessaire
        final count = await db.rawQuery('SELECT COUNT(*) as count FROM Locations');
        final rowCount = count.first['count'] as int;
        if (rowCount == 0) {
          await _importCSV(db);
        }
      },
    );
  }

  /// Crée la table Locations
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        city TEXT NOT NULL,
        country TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        capital TEXT,
        population INTEGER,
        admin_name TEXT,
        iso2 TEXT,
        iso3 TEXT
      )
    ''');

    // Index pour améliorer les performances de recherche
    await db.execute('CREATE INDEX idx_city_country ON Locations(city, country)');
    await db.execute('CREATE INDEX idx_capital ON Locations(capital)');
  }

  /// Importe les données du CSV dans la base de données
  Future<void> _importCSV(Database db) async {
    try {
      print('Importation du CSV en cours...');
      final csvData = await rootBundle.loadString('lib/worldcities.csv');
      final lines = const LineSplitter().convert(csvData);

      if (lines.isEmpty) return;

      // Ignorer la première ligne (en-têtes)
      var batch = db.batch();
      int imported = 0;

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;

        // Parser la ligne CSV (gérer les guillemets)
        final values = _parseCSVLine(line);
        if (values.length < 11) continue;

        try {
          // Structure exacte du CSV: "city","city_ascii","lat","lng","country","iso2","iso3","admin_name","capital","population","id"
          final city = values[0];  // city
          // values[1] est city_ascii (non utilisé)
          final lat = double.tryParse(values[2]);  // lat
          final lng = double.tryParse(values[3]);  // lng
          final country = values[4];  // country
          final iso2 = values[5];  // iso2
          final iso3 = values[6];  // iso3
          final adminName = values[7];  // admin_name
          final capital = values[8];  // capital
          final population = int.tryParse(values[9].replaceAll('"', ''));  // population (peut contenir des guillemets)
          // values[10] est id (non utilisé)

          if (city.isNotEmpty && lat != null && lng != null && country.isNotEmpty) {
            batch.insert('Locations', {
              'city': city,
              'country': country,
              'latitude': lat,
              'longitude': lng,
              'capital': capital,
              'population': population,
              'admin_name': adminName,
              'iso2': iso2,
              'iso3': iso3,
            });
            imported++;
          }
        } catch (e) {
          print('Erreur ligne $i: $e');
        }

        // Exécuter par batch de 500 pour éviter les problèmes de mémoire
        if (imported % 500 == 0 && imported > 0) {
          await batch.commit(noResult: true);
          batch = db.batch(); // Créer un nouveau batch
          print('$imported villes importées...');
        }
      }

      // Commit final
      if (imported % 500 != 0) {
        await batch.commit(noResult: true);
      }
      print('Import terminé: $imported villes importées');
    } catch (e) {
      print('Erreur lors de l\'importation du CSV: $e');
    }
  }

  /// Parse une ligne CSV en gérant les guillemets et virgules
  List<String> _parseCSVLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }

    result.add(current.toString().trim());
    return result;
  }

  /// Insère une nouvelle ville dans la base de données
  Future<void> insertLocation(Map<String, dynamic> location) async {
    final db = await instance.database;
    await db.insert(
      'Locations',
      location,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    print('Ville ajoutée à la base de données: ${location['city']}, ${location['country']}');
  }

  /// Vérifie si une ville existe dans la base de données
  Future<bool> locationExists(String city, String country) async {
    final db = await instance.database;
    final result = await db.query(
      'Locations',
      where: 'LOWER(city) = ? AND LOWER(country) = ?',
      whereArgs: [city.toLowerCase(), country.toLowerCase()],
    );
    return result.isNotEmpty;
  }

  /// Recherche une ville dans la base de données
  Future<Map<String, dynamic>?> findLocation(String city, String country) async {
    final db = await instance.database;
    final result = await db.query(
      'Locations',
      where: 'LOWER(city) = ? AND LOWER(country) = ?',
      whereArgs: [city.toLowerCase(), country.toLowerCase()],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Récupère une ville aléatoire (avec option pour uniquement les capitales)
  Future<Map<String, dynamic>?> getRandomLocation({bool onlyCapitals = false}) async {
    final db = await instance.database;

    String whereClause = '';
    if (onlyCapitals) {
      whereClause = "WHERE capital = 'primary'";
    }

    final result = await db.rawQuery(
      'SELECT * FROM Locations $whereClause ORDER BY RANDOM() LIMIT 1'
    );

    return result.isNotEmpty ? result.first : null;
  }

  /// Récupère le nombre total de villes dans la base
  Future<int> getLocationCount({bool onlyCapitals = false}) async {
    final db = await instance.database;

    String whereClause = '';
    if (onlyCapitals) {
      whereClause = "WHERE capital = 'primary' OR capital = 'admin' OR capital = 'minor'";
    }

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM Locations $whereClause');
    return result.first['count'] as int;
  }

  /// Ferme la base de données
  Future close() async {
    final db = await instance.database;
    db.close();
  }

  /// Retourne le chemin complet de la base de données
  /// Utile pour déboguer et accéder à la base avec un outil externe
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'mapeo_locations.db');
  }

  /// Affiche le chemin de la base de données dans la console
  Future<void> printDatabasePath() async {
    final path = await getDatabasePath();
    print('===========================================');
    print('Chemin de la base de données SQLite :');
    print(path);
    print('===========================================');
  }
}
