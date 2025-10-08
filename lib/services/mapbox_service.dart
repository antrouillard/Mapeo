// lib/services/mapbox_service.dart
import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/challenge.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapboxService {
  static  String ACCESS_TOKEN = dotenv.env["MAPBOX_ACCESS_TOKEN"] ?? "";

  // Génère un lieu aléatoire pour le jeu
  static Challenge generateRandomLocation() {
    final random = Random();
    MapboxOptions.setAccessToken(ACCESS_TOKEN);

    // Quelques lieux intéressants pour commencer
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

    return locations[random.nextInt(locations.length)];
  }

  // Calcule la distance entre deux points (formule de Haversine)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            pow(sin(dLon / 2), 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // Calcule le score basé sur la distance
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