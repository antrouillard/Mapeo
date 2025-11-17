// lib/widgets/end_game_dialog.dart
import 'package:flutter/material.dart';
import 'victory_animation.dart';
import 'defeat_animation.dart';

/// Affiche le dialog de fin de partie avec animation selon le score
void showEndGameDialog({
  required BuildContext context,
  required int score,
  required int maxRounds,
  required VoidCallback onPlayAgain,
  required VoidCallback onReturnToMenu,
  int victoryThreshold = 3500,
}) {
  final isVictory = score >= victoryThreshold;

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => Material(
      type: MaterialType.transparency,
      child: isVictory
          ? VictoryAnimation(
              child: _buildDialogContent(
                context: context,
                score: score,
                maxRounds: maxRounds,
                isVictory: true,
                onPlayAgain: onPlayAgain,
                onReturnToMenu: onReturnToMenu,
              ),
            )
          : DefeatAnimation(
              child: _buildDialogContent(
                context: context,
                score: score,
                maxRounds: maxRounds,
                isVictory: false,
                onPlayAgain: onPlayAgain,
                onReturnToMenu: onReturnToMenu,
              ),
            ),
    ),
  );
}

Widget _buildDialogContent({
  required BuildContext context,
  required int score,
  required int maxRounds,
  required bool isVictory,
  required VoidCallback onPlayAgain,
  required VoidCallback onReturnToMenu,
}) {
  return AlertDialog(
    title: Row(
      children: [
        Icon(
          isVictory ? Icons.emoji_events : Icons.sentiment_dissatisfied,
          color: isVictory ? Colors.amber : Colors.grey,
          size: 32,
        ),
        const SizedBox(width: 12),
        Text(isVictory ? 'Victoire !' : 'Partie terminée'),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isVictory ? Icons.emoji_events : Icons.trending_down,
          size: 64,
          color: isVictory ? Colors.amber : Colors.grey,
        ),
        const SizedBox(height: 20),
        Text(
          isVictory ? 'Félicitations !' : 'Continuez à vous entraîner !',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isVictory ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Score total: $score',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          'Moyenne: ${(score / maxRounds).toStringAsFixed(0)} pts/round',
        ),
        const SizedBox(height: 10),
        const Text(
          '✅ Score enregistré !',
          style: TextStyle(
            fontSize: 14,
            color: Colors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isVictory) ...[
          const SizedBox(height: 12),
          Text(
            '🎉 Plus de 3500 points !',
            style: TextStyle(
              fontSize: 14,
              color: Colors.amber.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onReturnToMenu();
        },
        child: const Text('Retour au menu'),
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          onPlayAgain();
        },
        child: const Text('Rejouer'),
      ),
    ],
  );
}

