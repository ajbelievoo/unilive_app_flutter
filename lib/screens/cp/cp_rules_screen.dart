/// CP/Friend Rules screen — shows the detailed rules text from the
/// reference screenshots for both CP and Friend systems.
library cp_friend_rules;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class CPRulesScreen extends StatelessWidget {
  const CPRulesScreen({super.key, this.isFriend = false});
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final rules = isFriend ? _friendRules : _cpRules;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text('${isFriend ? 'Friend' : 'CP'} Rules',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: isFriend ? AppTheme.primaryGradient : AppTheme.pinkGradient,
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, bottom: 14),
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.asset(
                      'assets/cp_friend/heart_tow.png',
                      width: 60,
                      height: 38,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _RuleSection(rule: rules[i]),
              childCount: rules.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleData {
  final String title;
  final List<String> points;
  _RuleData({required this.title, required this.points});
}

final List<_RuleData> _cpRules = [
  _RuleData(title: 'How to become CP?', points: [
    'Click the "Invite" button on Profile Page or from "Me - CP/Friend", select the friend you want to bind and send the invitation.',
    'When invite CP needs to spend certain amount of diamonds to complete the process.',
  ]),
  _RuleData(title: 'How to improve CP level?', points: [
    'Sending gifts, 1 diamond = 1 Exp',
    'On mic together in the same room, every 5 minutes = 120 Exp (maximum 12000 Exp per day)',
  ]),
  _RuleData(title: 'How to unbind CP?', points: [
    'On the CP page, click the "Unbind" button and follow the prompts to complete the unbinding.',
    'After unbinding, the CP Exp and accumulated days will be cleared and cannot be restored. Please think twice before unbinding a relationship.',
    'When unbind CP needs to spend certain amount of diamonds to complete the process.',
  ]),
  _RuleData(title: 'How to get Relationship Privileges?', points: [
    'By upgrading the CP level, you can get more privileges and benefits.',
  ]),
];

final List<_RuleData> _friendRules = [
  _RuleData(title: 'How to become Friends?', points: [
    'Click the "Invite" button on Profile Page or from "Me - CP/Friend", select the friend you want to bind and send the invitation.',
    'You need to spend 600000 diamonds to become a friend with others.',
  ]),
  _RuleData(title: 'How to improve Friend level?', points: [
    'Sending gifts, 1 diamond = 1 intimacy point',
    'On mic together in the same room, every 5 minutes = 120 Exp (maximum 12000 Exp per day)',
  ]),
  _RuleData(title: 'How to remove Friends?', points: [
    'On the Friend page, click the "Remove" button and follow the prompts to complete the removal.',
    'After removal, the Friend Exp and accumulated days will be cleared and cannot be restored.',
    'When remove Friend needs to spend certain amount of diamonds to complete the process.',
  ]),
  _RuleData(title: 'How to get Friend Privileges?', points: [
    'By upgrading the Friend level, you can get more privileges and benefits.',
  ]),
];

class _RuleSection extends StatelessWidget {
  const _RuleSection({required this.rule});
  final _RuleData rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  gradient: AppTheme.pinkGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.question_mark, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(rule.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rule.points.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.pinkGradient,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
