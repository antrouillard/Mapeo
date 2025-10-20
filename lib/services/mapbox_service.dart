// lib/services/mapbox_service.dart
import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/challenge.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service pour gérer les fonctionnalités Mapbox et la logique du jeu
class MapboxService {
  // Token d'accès Mapbox (défini dans le fichier .env)
  static  String ACCESS_TOKEN = dotenv.env["MAPBOX_ACCESS_TOKEN"] ?? "";

  /// Génère un défi aléatoire (lieu à deviner)
  ///
  /// Pour l'instant, tire aléatoirement parmi une liste fixe de lieux célèbres.
  /// TODO: Améliorer avec un vrai tirage aléatoire mondial + reverse geocoding
  /// pour obtenir automatiquement le nom de la ville et du pays.
  static Challenge generateRandomLocation() {
    final random = Random();
    MapboxOptions.setAccessToken(ACCESS_TOKEN);

    // Liste de lieux célèbres pour les défis
    // Format: latitude, longitude, pays, ville
    final List<Challenge> locations = [
      Challenge(
        latitude: 48.8584,
        longitude: 2.2945,
        correctCountry: 'France',
        correctCity: 'Paris',
      ),
      Challenge(
        latitude: 40.7128,
        longitude: -74.0060,
        correctCountry: 'USA',
        correctCity: 'New York',
      ),
      Challenge(
        latitude: 35.6762,
        longitude: 139.6503,
        correctCountry: 'Japan',
        correctCity: 'Tokyo',
      ),
      Challenge(
        latitude: 51.5074,
        longitude: -0.1278,
        correctCountry: 'UK',
        correctCity: 'London',
      ),
      Challenge(
        latitude: -33.8688,
        longitude: 151.2093,
        correctCountry: 'Australia',
        correctCity: 'Sydney',
      ),
    ];

    // Retourner un lieu aléatoire de la liste
    return locations[random.nextInt(locations.length)];
  }

  /// Calcule la distance entre deux points géographiques
  ///
  /// Utilise la formule de Haversine pour calculer la distance
  /// sur une sphère entre deux coordonnées GPS.
  ///
  /// Paramètres:
  /// - [lat1], [lon1] : Coordonnées du premier point
  /// - [lat2], [lon2] : Coordonnées du second point
  ///
  /// Retourne la distance en kilomètres.
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Rayon de la Terre en kilomètres
    const double earthRadius = 6371; // km

    // Convertir les différences de latitude et longitude en radians
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    // Formule de Haversine
    // a = sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlon/2)
    double a = pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            pow(sin(dLon / 2), 2);

    // c = 2 * atan2(√a, √(1-a))
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // Distance = rayon * c
    return earthRadius * c;
  }

  /// Convertit des degrés en radians
  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// Calcule le score en fonction de la distance entre le guess et la bonne réponse
  ///
  /// Plus le joueur est proche, plus le score est élevé.
  /// Score maximum: 1000 points (< 1 km)
  /// Score minimum: 50 points (> 5000 km)
  ///
  /// [distanceKm] : Distance en kilomètres
  ///
  /// Retourne le score (entre 50 et 1000 points).
  static int calculateScore(double distanceKm) {
    if (distanceKm < 1) return 1000;
    if (distanceKm < 10) return 900;
    if (distanceKm < 50) return 800;
    if (distanceKm < 100) return 700;
    if (distanceKm < 250) return 600;
    if (distanceKm < 500) return 500;
    if (distanceKm < 1000) return 400;
    if (distanceKm < 2000) return 300;
    if (distanceKm < 3000) return 200;
    if (distanceKm < 5000) return 100;
    return 50;
  }
}