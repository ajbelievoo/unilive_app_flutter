/// Ludo game stub screen.
///
/// Opens a lightweight in-app Ludo board. Full online multiplayer requires a
/// separate Ludo backend.
library ludo_game_screen;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LudoGameScreen extends StatelessWidget {
  const LudoGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.surface : AppTheme.lightSurface,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.surface : AppTheme.lightSurface,
        title: Text('Ludo', style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.casino, size: 80, color: AppTheme.primary),
            const SizedBox(height: 20),
            Text(
              'Ludo Game',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Coming soon!',
              style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
