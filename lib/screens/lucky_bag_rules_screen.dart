/// Lucky Bag Rules screen.
///
/// Explains the rules for sending and claiming lucky bags.
library lucky_bag_rules_screen;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LuckyBagRulesScreen extends StatelessWidget {
  const LuckyBagRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final text = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Lucky Bag Rules',
          style: TextStyle(color: text, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: isDark ? AppTheme.surfaceLight : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rule(context, '1. Send Lucky Bag by diamonds, and other users can get random diamonds by opening your Lucky Bag.'),
                _rule(context, '2. When you send a Lucky Bag, all users will receive the Lucky Bag broadcast and room message, you will get more attention and traffic.'),
                _rule(context, '3. Unclaimed diamonds will be returned to your wallet when the Lucky Bag expires.'),
                _rule(context, '4. Only one Lucky Bag can be sent in a room at the same time.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rule(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, height: 1.5, color: textColor),
      ),
    );
  }
}
