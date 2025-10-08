# mapeo

Flutter project with MapBox usage

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## TODO: 

lib/
├── main.dart
├── models/
│   ├── game_session.dart          # Session de jeu en cours
│   ├── (DONE) challenge.dart      # Données d'un défi
│   └── user_score.dart            # Historique des scores
├── services/
│   ├── (DONE)mapbox_service.dart  # Gestion MapBox
│   ├── location_api_service.dart  # API externe (géocodage)
│   └── (DONE) db_service.dart     # SQLite/Hive pour persistance DONE
├── screens/
│   ├── home_screen.dart           # Menu principal
│   ├── (DONE) game_screen.dart    # Écran de jeu principal
│   ├── result_screen.dart         # Résultats avec animation
│   └── history_screen.dart        # Historique des parties
├── widgets/
│   ├── map_widget.dart            # Widget carte personnalisé
│   ├── guess_input.dart           # Input pour deviner
│   └── score_animation.dart       # Animation du score
└── utils/
├── constants.dart             # Clés API, constantes
└── score_calculator.dart      # Calcul de distance/points
