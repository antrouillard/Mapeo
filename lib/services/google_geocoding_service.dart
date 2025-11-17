// lib/services/google_geocoding_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../database/database_helper.dart';

/// Service pour géocoder des adresses avec l'API Google Geocoding
/// Convertit une adresse texte en coordonnées géographiques (longitude, latitude)
class GoogleGeocodingService {
  // Clé API Google Geocoding (doit être définie dans le fichier .env)
  static final String? _apiKey = dotenv.env['GOOGLE_GEOCODING_API_KEY'];

  /// Géocode une adresse et retourne un Point au format Mapbox
  ///
  /// [address] : L'adresse à géocoder (ex: "10 Downing St, London")
  ///
  /// Retourne un [Point] avec les coordonnées (longitude, latitude) au format Mapbox,
  /// ou null si aucun résultat n'est trouvé.
  ///
  /// Cette méthode cherche d'abord dans la base de données locale pour économiser
  /// les requêtes API. Si la ville n'est pas trouvée localement, elle fait une
  /// requête à l'API Google et ajoute le résultat à la base de données.
  ///
  /// Lance une [Exception] si la clé API n'est pas définie ou en cas d'erreur réseau.
  static Future<Point?> geocodeAddress(String address) async {
    // Vérifier que la clé API est configurée
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GOOGLE_GEOCODING_API_KEY non défini dans .env');
    }

    // Essayer de trouver la ville dans la base de données locale d'abord
    final localResult = await _searchInDatabase(address);
    if (localResult != null) {
      print('Ville trouvée dans la base de données locale: $address');
      return localResult;
    }

    print('Ville non trouvée localement, requête API Google Geocoding...');

    // Encoder l'adresse pour l'URL
    final encoded = Uri.encodeQueryComponent(address);

    // Construire l'URL de l'API Google Geocoding
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=${_apiKey!}&language=fr');

    // Effectuer la requête HTTP
    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception('Erreur réseau: ${resp.statusCode}');
    }

    // Parser la réponse JSON
    final Map<String, dynamic> json = jsonDecode(resp.body);

    // Vérifier que la requête a réussi et qu'il y a des résultats
    if (json['status'] != 'OK' || (json['results'] as List).isEmpty) {
      return null;
    }

    // Extraire les informations du premier résultat
    final result = json['results'][0];
    final location = result['geometry']['location'];
    final double lat = (location['lat'] as num).toDouble();
    final double lng = (location['lng'] as num).toDouble();

    // Extraire les composants d'adresse
    final addressComponents = result['address_components'] as List;
    String city = '';
    String country = '';
    String adminName = '';
    String iso2 = '';

    for (var component in addressComponents) {
      final types = component['types'] as List;
      if (types.contains('locality')) {
        city = component['long_name'];
      } else if (types.contains('country')) {
        country = component['long_name'];
        iso2 = component['short_name'];
      } else if (types.contains('administrative_area_level_1')) {
        adminName = component['long_name'];
      }
    }

    // Ajouter la ville à la base de données si elle a un nom et un pays
    if (city.isNotEmpty && country.isNotEmpty) {
      await _addToDatabase(city, country, lat, lng, adminName, iso2);
    }

    // Retourner un Point au format Mapbox (attention: longitude en premier!)
    return Point(coordinates: Position(lng, lat));
  }

  /// Classe pour stocker les résultats détaillés du géocodage
  static Future<GeocodeResult?> geocodeAddressDetailed(String address) async {
    // Vérifier que la clé API est configurée
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GOOGLE_GEOCODING_API_KEY non défini dans .env');
    }

    // Essayer de trouver dans la base de données locale d'abord
    final localResult = await _searchInDatabaseDetailed(address);
    if (localResult != null) {
      print('Ville trouvée dans la base de données locale: $address');
      return localResult;
    }

    print('Ville non trouvée localement, requête API Google Geocoding...');

    // Encoder l'adresse pour l'URL
    final encoded = Uri.encodeQueryComponent(address);

    // Construire l'URL de l'API Google Geocoding
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=${_apiKey!}&language=fr');

    // Effectuer la requête HTTP
    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception('Erreur réseau: ${resp.statusCode}');
    }

    // Parser la réponse JSON
    final Map<String, dynamic> json = jsonDecode(resp.body);

    // Vérifier que la requête a réussi et qu'il y a des résultats
    if (json['status'] != 'OK' || (json['results'] as List).isEmpty) {
      return null;
    }

    // Extraire les informations du premier résultat
    final result = json['results'][0];
    final location = result['geometry']['location'];
    final double lat = (location['lat'] as num).toDouble();
    final double lng = (location['lng'] as num).toDouble();

    // Extraire les composants d'adresse
    final addressComponents = result['address_components'] as List;
    String city = '';
    String country = '';
    String adminName = '';
    String iso2 = '';

    for (var component in addressComponents) {
      final types = component['types'] as List;
      if (types.contains('locality')) {
        city = component['long_name'];
      } else if (types.contains('country')) {
        country = component['long_name'];
        iso2 = component['short_name'];
      } else if (types.contains('administrative_area_level_1')) {
        adminName = component['long_name'];
      }
    }

    // Ajouter la ville à la base de données si elle a un nom et un pays
    if (city.isNotEmpty && country.isNotEmpty) {
      await _addToDatabase(city, country, lat, lng, adminName, iso2);
    }

    // Retourner le résultat détaillé
    return GeocodeResult(
      point: Point(coordinates: Position(lng, lat)),
      city: city,
      country: country,
      adminName: adminName,
      iso2: iso2,
    );
  }

  /// Cherche une ville dans la base de données locale et retourne les détails
  static Future<GeocodeResult?> _searchInDatabaseDetailed(String address) async {
    // Parser l'adresse pour extraire ville et pays
    final parts = address.split(',').map((s) => s.trim()).toList();

    if (parts.isEmpty) return null;

    final city = parts[0];
    String country = parts.length > 1 ? parts.last : '';

    // Si on a une ville et un pays, chercher dans la base
    if (city.isNotEmpty) {
      final db = DatabaseHelper.instance;

      // Chercher avec ville et pays si disponible
      if (country.isNotEmpty) {
        final location = await db.findLocation(city, country);
        if (location != null) {
          return GeocodeResult(
            point: Point(
              coordinates: Position(
                location['longitude'] as double,
                location['latitude'] as double,
              ),
            ),
            city: location['city'] as String,
            country: location['country'] as String,
            adminName: location['admin_name'] as String? ?? '',
            iso2: location['iso2'] as String? ?? '',
          );
        }
      }

      // Sinon, chercher juste par ville (prendre le premier résultat)
      final dbInstance = await db.database;
      final results = await dbInstance.query(
        'Locations',
        where: 'LOWER(city) = ?',
        whereArgs: [city.toLowerCase()],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final location = results.first;
        return GeocodeResult(
          point: Point(
            coordinates: Position(
              location['longitude'] as double,
              location['latitude'] as double,
            ),
          ),
          city: location['city'] as String,
          country: location['country'] as String,
          adminName: location['admin_name'] as String? ?? '',
          iso2: location['iso2'] as String? ?? '',
        );
      }
    }

    return null;
  }

  /// Cherche une ville dans la base de données locale
  /// Retourne un Point si trouvé, null sinon
  static Future<Point?> _searchInDatabase(String address) async {
    // Parser l'adresse pour extraire ville et pays
    // Format attendu: "City, Country" ou "City"
    final parts = address.split(',').map((s) => s.trim()).toList();

    if (parts.isEmpty) return null;

    final city = parts[0];
    String country = parts.length > 1 ? parts.last : '';

    // Si on a une ville et un pays, chercher dans la base
    if (city.isNotEmpty) {
      final db = DatabaseHelper.instance;

      // Chercher avec ville et pays si disponible
      if (country.isNotEmpty) {
        final location = await db.findLocation(city, country);
        if (location != null) {
          return Point(
            coordinates: Position(
              location['longitude'] as double,
              location['latitude'] as double,
            ),
          );
        }
      }

      // Sinon, chercher juste par ville (prendre le premier résultat)
      final dbInstance = await db.database;
      final results = await dbInstance.query(
        'Locations',
        where: 'LOWER(city) = ?',
        whereArgs: [city.toLowerCase()],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final location = results.first;
        return Point(
          coordinates: Position(
            location['longitude'] as double,
            location['latitude'] as double,
          ),
        );
      }
    }

    return null;
  }

  /// Ajoute une nouvelle ville à la base de données
  static Future<void> _addToDatabase(
    String city,
    String country,
    double lat,
    double lng,
    String adminName,
    String iso2,
  ) async {
    final db = DatabaseHelper.instance;

    // Vérifier si la ville existe déjà
    final exists = await db.locationExists(city, country);
    if (!exists) {
      await db.insertLocation({
        'city': city,
        'country': country,
        'latitude': lat,
        'longitude': lng,
        'admin_name': adminName,
        'iso2': iso2,
        'capital': '', // Non déterminé via geocoding
        'population': null,
        'iso3': '',
      });
    }
  }

  /// Géocodage inversé : obtient le nom du pays à partir de coordonnées GPS
  ///
  /// [lat] : Latitude
  /// [lng] : Longitude
  ///
  /// Retourne le nom du pays, ou null si non trouvé
  static Future<String?> reverseGeocode(double lat, double lng) async {
    // Vérifier que la clé API est configurée
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GOOGLE_GEOCODING_API_KEY non défini dans .env');
    }

    // Construire l'URL de l'API Google Geocoding pour le géocodage inversé
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${_apiKey!}&language=fr'
    );

    try {
      // Effectuer la requête HTTP
      final resp = await http.get(url);
      if (resp.statusCode != 200) {
        throw Exception('Erreur réseau: ${resp.statusCode}');
      }

      // Parser la réponse JSON
      final Map<String, dynamic> json = jsonDecode(resp.body);

      // Vérifier que la requête a réussi et qu'il y a des résultats
      if (json['status'] != 'OK' || (json['results'] as List).isEmpty) {
        return null;
      }

      // Parcourir les résultats pour trouver le pays
      for (var result in json['results']) {
        final addressComponents = result['address_components'] as List;

        for (var component in addressComponents) {
          final types = component['types'] as List;
          if (types.contains('country')) {
            return component['long_name'] as String;
          }
        }
      }

      return null;
    } catch (e) {
      print('Erreur lors du géocodage inversé: $e');
      return null;
    }
  }
}

/// Classe pour stocker les résultats détaillés du géocodage
class GeocodeResult {
  final Point point;
  final String city;
  final String country;
  final String adminName;
  final String iso2;

  GeocodeResult({
    required this.point,
    required this.city,
    required this.country,
    required this.adminName,
    required this.iso2,
  });
}
