// lib/services/google_geocoding_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  /// Lance une [Exception] si la clé API n'est pas définie ou en cas d'erreur réseau.
  static Future<Point?> geocodeAddress(String address) async {
    // Vérifier que la clé API est configurée
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GOOGLE_GEOCODING_API_KEY non défini dans .env');
    }

    // Encoder l'adresse pour l'URL
    final encoded = Uri.encodeQueryComponent(address);

    // Construire l'URL de l'API Google Geocoding
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=$encoded&key=${_apiKey!}');

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

    // Extraire les coordonnées du premier résultat
    final location = json['results'][0]['geometry']['location'];
    final double lat = (location['lat'] as num).toDouble();
    final double lng = (location['lng'] as num).toDouble();

    // Retourner un Point au format Mapbox (attention: longitude en premier!)
    return Point(coordinates: Position(lng, lat));
  }
}
