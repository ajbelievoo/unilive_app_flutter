import 'dart:math';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class GameListSheet extends StatelessWidget {
  const GameListSheet({super.key, required this.onSelect});

  final void Function(String gameType) onSelect;

  static const _games = [
    {'type': 'casino', 'label': 'Casino', 'icon': Icons.casino, 'color': Colors.red},
    {'type': 'teenPatti', 'label': 'Teen Patti', 'icon': Icons.style, 'color': Colors.orange},
    {'type': 'luckyWheel', 'label': 'Lucky Wheel', 'icon': Icons.refresh, 'color': Colors.green},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ..._games.map((g) => ListTile(
                leading: Icon(g['icon'] as IconData, color: g['color'] as Color),
                title: Text(g['label'] as String),
                onTap: () {
                  onSelect(g['type'] as String);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class CasinoGameSheet extends StatefulWidget {
  const CasinoGameSheet({super.key, required this.onResult});

  final void Function(int winnings) onResult;

  @override
  State<CasinoGameSheet> createState() => _CasinoGameSheetState();
}

class _CasinoGameSheetState extends State<CasinoGameSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _random = Random();
  int _dice1 = 1;
  int _dice2 = 1;
  bool _rolling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _rollDice() {
    if (_rolling) return;
    _rolling = true;
    _controller.forward(from: 0);
    _controller.addListener(() {
      setState(() {
        _dice1 = _random.nextInt(6) + 1;
        _dice2 = _random.nextInt(6) + 1;
      });
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _rolling = false;
        final sum = _dice1 + _dice2;
        final winnings = sum > 7 ? sum * 10 : 0;
        widget.onResult(winnings);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Casino Dice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _diceWidget(_dice1),
              const SizedBox(width: 16),
              _diceWidget(_dice2),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rolling ? null : _rollDice,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(_rolling ? 'Rolling...' : 'Roll Dice'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _diceWidget(int value) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text('$value', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class TeenPattiGameSheet extends StatefulWidget {
  const TeenPattiGameSheet({super.key, required this.onResult});

  final void Function(int winnings) onResult;

  @override
  State<TeenPattiGameSheet> createState() => _TeenPattiGameSheetState();
}

class _TeenPattiGameSheetState extends State<TeenPattiGameSheet> {
  final _random = Random();
  final _suits = ['♠', '♥', '♦', '♣'];
  final _ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  List<String> _cards = [];
  bool _dealt = false;

  void _deal() {
    setState(() {
      _cards = List.generate(3, (_) {
        final suit = _suits[_random.nextInt(4)];
        final rank = _ranks[_random.nextInt(13)];
        return '$rank$suit';
      });
      _dealt = true;
    });
    final winnings = _random.nextInt(100) + 10;
    Future.delayed(const Duration(seconds: 2), () => widget.onResult(winnings));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Teen Patti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (_dealt)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _cards.map(_cardWidget).toList(),
            )
          else
            const Text('Tap deal to start', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _dealt ? null : _deal,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Deal Cards'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cardWidget(String card) {
    final isRed = card.contains('♥') || card.contains('♦');
    return Container(
      width: 60,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(card, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isRed ? Colors.red : Colors.black)),
      ),
    );
  }
}
