// lib/services/weather_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service pour récupérer les données météo avec l'API OpenWeatherMap
class WeatherService {
  // Clé API OpenWeatherMap (gratuite, 1000 appels/jour)
  static final String? _apiKey = dotenv.env['OPENWEATHERMAP_API_KEY'];
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Récupère les données météo actuelles pour des coordonnées
  ///
  /// [lat] : Latitude
  /// [lon] : Longitude
  ///
  /// Retourne un Map avec les données météo ou null si erreur
  static Future<Map<String, dynamic>?> getWeather(double lat, double lon) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      print('⚠️ OPENWEATHERMAP_API_KEY non défini dans .env');
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=fr'
      );

      print('🌤️ Récupération météo pour: $lat, $lon');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weather = WeatherData.fromJson(data);

        print('✅ Météo récupérée: ${weather.temperature}°C, ${weather.description}');

        // Retourner un Map avec les informations formatées
        return {
          'temperature': weather.temperature,
          'feelsLike': weather.feelsLike,
          'description': weather.description,
          'main': weather.main,
          'humidity': weather.humidity,
          'windSpeed': weather.windSpeed,
          'emoji': getWeatherEmoji(weather.main),
          'hint': generateClimateHint(weather),
        };
      } else if (response.statusCode == 401) {
        print('❌ Erreur API météo 401: Clé API invalide ou non activée');
        print('   Veuillez vérifier votre clé OPENWEATHERMAP_API_KEY dans le fichier .env');
        print('   Note: Les nouvelles clés OpenWeatherMap peuvent prendre jusqu\'à 2 heures pour être activées');
        return _getMockWeatherData(); // Retourner des données de test
      } else {
        print('❌ Erreur API météo: ${response.statusCode}');
        print('   Réponse: ${response.body}');
        return _getMockWeatherData(); // Retourner des données de test
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération de la météo: $e');
      return _getMockWeatherData(); // Retourner des données de test
    }
  }

  /// Génère une description textuelle du climat/météo pour le jeu
  static String generateClimateHint(WeatherData weather) {
    final temp = weather.temperature.round();
    final feelsLike = weather.feelsLike.round();
    final description = weather.description;
    final humidity = weather.humidity;
    final windSpeed = weather.windSpeed.round();

    // Créer une description concise
    final hints = <String>[];

    // Température
    if (temp < 0) {
      hints.add('❄️ Il fait $temp°C (très froid)');
    } else if (temp < 10) {
      hints.add('🥶 Il fait $temp°C (froid)');
    } else if (temp < 20) {
      hints.add('😊 Il fait $temp°C (doux)');
    } else if (temp < 30) {
      hints.add('☀️ Il fait $temp°C (chaud)');
    } else {
      hints.add('🔥 Il fait $temp°C (très chaud)');
    }

    // Météo actuelle
    hints.add('🌤️ $description');

    // Humidité si significative
    if (humidity > 80) {
      hints.add('💧 Très humide ($humidity%)');
    } else if (humidity < 30) {
      hints.add('🏜️ Très sec ($humidity%)');
    }

    // Vent si fort
    if (windSpeed > 30) {
      hints.add('💨 Vent fort ($windSpeed km/h)');
    }

    return hints.join('\n');
  }

  /// Génère des emojis météo pour l'affichage
  static String getWeatherEmoji(String weatherMain) {
    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
      case 'drizzle':
        return '🌧️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  /// Génère des données météo de test en cas d'erreur API
  static Map<String, dynamic> _getMockWeatherData() {
    print('⚠️ Utilisation de données météo de test (API non disponible)');

    // Générer des données aléatoires réalistes
    final temps = ['Clear', 'Clouds', 'Rain', 'Snow'];
    final descriptions = [
      'ciel dégagé',
      'quelques nuages',
      'pluie modérée',
      'nuageux'
    ];
    final randomIndex = DateTime.now().millisecond % temps.length;

    final mockWeather = WeatherData(
      temperature: 15.0 + (DateTime.now().millisecond % 20),
      feelsLike: 14.0 + (DateTime.now().millisecond % 20),
      humidity: 50 + (DateTime.now().millisecond % 40),
      windSpeed: 10.0 + (DateTime.now().millisecond % 20),
      description: descriptions[randomIndex],
      main: temps[randomIndex],
      icon: '01d',
      pressure: 1013,
    );

    return {
      'temperature': mockWeather.temperature,
      'feelsLike': mockWeather.feelsLike,
      'description': mockWeather.description,
      'main': mockWeather.main,
      'humidity': mockWeather.humidity,
      'windSpeed': mockWeather.windSpeed,
      'emoji': getWeatherEmoji(mockWeather.main),
      'hint': generateClimateHint(mockWeather),
    };
  }
}

/// Classe pour stocker les données météo
class WeatherData {
  final double temperature;      // Température en °C
  final double feelsLike;        // Ressenti en °C
  final int humidity;            // Humidité en %
  final double windSpeed;        // Vitesse du vent en m/s
  final String description;      // Description (ex: "nuageux")
  final String main;             // Catégorie principale (ex: "Clouds")
  final String icon;             // Code icône
  final int pressure;            // Pression atmosphérique

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.main,
    required this.icon,
    required this.pressure,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'];
    final weather = json['weather'][0];
    final wind = json['wind'];

    return WeatherData(
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num).toDouble() * 3.6, // Conversion m/s vers km/h
      description: weather['description'] as String,
      main: weather['main'] as String,
      icon: weather['icon'] as String,
      pressure: main['pressure'] as int,
    );
  }

  @override
  String toString() {
    return '${temperature.round()}°C, $description';
  }
}
