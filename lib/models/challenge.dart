import '../database/database_helper.dart';

class Challenge {
  final double latitude;
  final double longitude;
  final String correctCountry;
  final String correctCity;

  Challenge({
    required this.latitude,
    required this.longitude,
    required this.correctCountry,
    required this.correctCity,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'correctCountry': correctCountry,
      'correctCity': correctCity,
    };
  }

  /// Génère un challenge aléatoire depuis la base de données
  /// [onlyCapitals] : si true, sélectionne uniquement des capitales
  static Future<Challenge?> random({bool onlyCapitals = false}) async {
    final location = await DatabaseHelper.instance.getRandomLocation(
      onlyCapitals: onlyCapitals
    );

    if (location == null) return null;

    return Challenge(
      latitude: location['latitude'] as double,
      longitude: location['longitude'] as double,
      correctCountry: location['country'] as String,
      correctCity: location['city'] as String,
    );
  }
}