// lib/models/game_mode.dart

/// Type de guess (comment le joueur devine)
enum GuessType {
  map,      // Le joueur clique sur la carte
  text,     // Le joueur tape le nom du lieu
}

/// Mode visuel de la carte pour le guess textuel
enum MapStyle {
  classic,        // Carte classique sans labels (style par défaut)
  blackAndWhite,  // Carte en noir et blanc
  noBorders,      // Carte sans frontières
  satellite,      // Vue satellite
}

/// Indice disponible pour le guess sur map
enum MapHint {
  classic,         // Mode classique sans indice
  weatherClimate,  // Affiche météo/climat
  capitalFlag,     // Affiche capitale/drapeau
  coordinates,     // Affiche coordonnées (HARDCORE)
}

/// Niveau de difficulté (ce qu'on doit deviner)
enum Difficulty {
  easy,     // Seulement le pays
  medium,   // Seulement la capitale
  hard,     // Seulement la région
}

/// Configuration complète d'une partie
class GameConfiguration {
  // Type de guess principal
  final GuessType guessType;

  // Pour guess sur map : quel indice ?
  final MapHint? mapHint;

  // Pour guess textuel : quel style de carte ?
  final MapStyle? mapStyle;

  // Difficulté / ce qu'on doit deviner
  final Difficulty difficulty;

  // Mode timer activé ?
  final bool timerEnabled;

  // Durée du timer en secondes (si activé)
  final int timerDuration;

  const GameConfiguration({
    required this.guessType,
    this.mapHint,
    this.mapStyle,
    this.difficulty = Difficulty.easy,
    this.timerEnabled = false,
    this.timerDuration = 60,
  });

  /// Retourne une description lisible de la configuration
  String get description {
    String desc = guessType == GuessType.map
        ? 'Trouve sur la Carte'
        : 'Dis où tu es';

    if (guessType == GuessType.map && mapHint != null) {
      switch (mapHint!) {
        case MapHint.classic:
          desc += ' (Classique)';
          break;
        case MapHint.weatherClimate:
          desc += ' + Météo/Climat';
          break;
        case MapHint.capitalFlag:
          desc += ' + Capitale/Drapeau';
          break;
        case MapHint.coordinates:
          desc += ' + Coordonnées (HARDCORE)';
          break;
      }
    }

    if (guessType == GuessType.text && mapStyle != null) {
      switch (mapStyle!) {
        case MapStyle.classic:
          desc += ' (Classique)';
          break;
        case MapStyle.blackAndWhite:
          desc += ' (Noir & Blanc)';
          break;
        case MapStyle.noBorders:
          desc += ' (Sans frontières)';
          break;
        case MapStyle.satellite:
          desc += ' (Satellite)';
          break;
      }
    }

    switch (difficulty) {
      case Difficulty.easy:
        desc += ' - Pays';
        break;
      case Difficulty.medium:
        desc += ' - Capitale';
        break;
      case Difficulty.hard:
        desc += ' - Région';
        break;
    }

    if (timerEnabled) {
      desc += ' ⏱️ ${timerDuration}s';
    }

    return desc;
  }

  GameConfiguration copyWith({
    GuessType? guessType,
    MapHint? mapHint,
    MapStyle? mapStyle,
    Difficulty? difficulty,
    bool? timerEnabled,
    int? timerDuration,
  }) {
    return GameConfiguration(
      guessType: guessType ?? this.guessType,
      mapHint: mapHint ?? this.mapHint,
      mapStyle: mapStyle ?? this.mapStyle,
      difficulty: difficulty ?? this.difficulty,
      timerEnabled: timerEnabled ?? this.timerEnabled,
      timerDuration: timerDuration ?? this.timerDuration,
    );
  }
}
