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
}