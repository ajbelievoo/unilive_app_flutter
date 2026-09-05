import 'package:flutter/material.dart';

/// Family Rules Screen — full rules explaining what a Family is, how to
/// create/join one, level & Firepower point mechanics, tasks and group chat.
/// Ported to match the native app's "Family Rules" page.
class FamilyRulesScreen extends StatelessWidget {
  const FamilyRulesScreen({super.key});

  static const List<_LevelRow> _levels = [
    _LevelRow('Lv.1', '2,500,000'),
    _LevelRow('Lv.2', '12,500,000'),
    _LevelRow('Lv.3', '25,000,000'),
    _LevelRow('Lv.4', '50,000,000'),
    _LevelRow('Lv.5', '150,000,000'),
    _LevelRow('Lv.6', '250,000,000'),
    _LevelRow('Lv.7', '400,000,000'),
    _LevelRow('Lv.8', '500,000,000'),
    _LevelRow('Lv.9', '2,500,000,000'),
    _LevelRow('Lv.10', '5,000,000,000'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        title: const Text(
          'Family Rules',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('1.What is a Family?'),
            const SizedBox(height: 10),
            _body('A Family is an organization that any user can create or join freely.'),
            const SizedBox(height: 24),

            _title('2.How to create a Family?'),
            const SizedBox(height: 10),
            _body(
              'On the Family list button, you can select "Create Family". If you are '
              'already a member of another Family, you must first leave your current '
              'Family before you can create a new one. A Family Leader who has already '
              'created a Family can only join another Family after transferring the '
              'Family Leader role or leaving their own Family.',
            ),
            const SizedBox(height: 24),

            _title('3.How to join a Family?'),
            const SizedBox(height: 10),
            _body(
              'Select the Family you want to join and click the "Apply to Join" button. '
              'If the Family requires the Family Leader\'s approval to join, after '
              'clicking the button the Family Leader will receive an application '
              'message. The Family Leader can "Reject" or "Approve the application" '
              'within 24 hours.',
            ),
            const SizedBox(height: 12),
            _bullet('If the Family Leader rejects your application within 24 hours, you can apply again to the same Family or to other Families.'),
            const SizedBox(height: 10),
            _bullet('If the Family Leader does not respond to your application within 24 hours, you can reapply or apply to other Families.'),
            const SizedBox(height: 10),
            _bullet('After leaving a Family, you can only apply to join that Family again after 24 hours.'),
            const SizedBox(height: 10),
            _bullet('You can submit a maximum of 20 Family applications within 24 hours.'),
            const SizedBox(height: 24),

            _title('4.Description of Family Level (Family Power) benefits'),
            const SizedBox(height: 10),
            _body(
              'Family members can increase the Family level by accumulating Firepower '
              'Points, thereby obtaining generous privilege rewards. Different levels '
              'have different member caps; the higher the level, the higher the member '
              'cap. Current Family benefits are as follows:',
            ),
            const SizedBox(height: 12),
            _bullet('Family Badge: After joining a Family, you automatically receive the Family Badge corresponding to its level.'),
            const SizedBox(height: 10),
            _bullet('Firepower Points for Family Level (Family Power) = Firepower Points contributed by Family members (including historical members).'),
            const SizedBox(height: 16),
            _levelTable(),
            const SizedBox(height: 24),

            _title('5.How to complete Family Tasks?'),
            const SizedBox(height: 10),
            _bullet('Family Tasks are one of the main sources of Family Firepower Points.'),
            const SizedBox(height: 10),
            _bullet('Family members can obtain corresponding Firepower Points by completing gift-sending and receiving tasks.'),
            const SizedBox(height: 24),

            _title('6.How to use the Family Group Chat function?'),
            const SizedBox(height: 10),
            _bullet('After creating or joining a Family, you will see the Family group chat entry.'),
            const SizedBox(height: 10),
            _bullet('Each Family will have one group chat, and all members of that Family can chat in it. Only members who have joined the Family can join the Family group chat.'),
            const SizedBox(height: 24),

            _title('7.Explanation of Firepower Points and Family Firepower Points'),
            const SizedBox(height: 10),
            _bullet(
              'Firepower Points are a numerical representation of Family activity. '
              'Family members can earn Firepower Points by sending gifts. (Sending '
              'regular gifts counts as 100% Firepower Points; sending Lucky Gifts and '
              'X Lucky Gifts counts as 10% Firepower Points.)',
            ),
            const SizedBox(height: 10),
            _bullet(
              'Family Firepower Points are the sum of all Firepower Points generated '
              'by all Family members during the statistical period; this includes '
              'contributions from historical members in this Family and contributions '
              'from current members in this Family. Family Firepower Points are not '
              'transferred when a member changes Families. If a member rejoins the '
              'same Family, the historical Firepower Points will be inherited.',
            ),
            const SizedBox(height: 10),
            _bullet(
              'The Family Member Contribution Ranking is based on Firepower Points '
              'earned from completing Family Tasks. Family Contribution Ranking '
              'Firepower Points = Firepower Points from member gift-sending tasks ± '
              'Firepower Points from new members joining/leaving the Family.',
            ),
            const SizedBox(height: 10),
            _bullet(
              'For example, in the weekly Family ranking data, when user Mike in '
              'Family A left the Family, he contributed 1000 Firepower Points this '
              'week. After leaving Family A, Mike joined Family B and contributed 10 '
              'Firepower Points. At that time, when calculating Family A\'s weekly '
              'ranking Firepower Points, Mike\'s contribution value is 1000 Firepower '
              'Points, but because he left Family A, his information is not displayed '
              'on the weekly ranking. For Family B, Mike\'s contribution value in the '
              'weekly ranking calculation is 10 Firepower Points, and he will be '
              'displayed in Family B\'s ranking according to his contribution rank.',
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: CircleAvatar(radius: 2.5, backgroundColor: Colors.white70),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Level', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(flex: 4, child: Text('Firepower needed', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(flex: 2, child: Text('Medal', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
          ),
          for (final row in _levels)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(row.level, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Expanded(flex: 4, child: Text(row.required, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  const Expanded(flex: 2, child: Icon(Icons.shield, color: Color(0xFFFFD700), size: 22)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelRow {
  final String level;
  final String required;
  const _LevelRow(this.level, this.required);
}
