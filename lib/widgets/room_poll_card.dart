import 'package:flutter/material.dart';

import '../models/room_runtime_models.dart';
import '../theme/app_theme.dart';

class RoomPollCard extends StatelessWidget {
  const RoomPollCard({super.key, required this.poll, required this.onVote});

  final RoomPoll poll;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final total = poll.totalVotes;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.themed(context, 0xE6191930),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.hairline(context)),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  poll.ended ? Icons.poll_outlined : Icons.how_to_vote,
                  color: poll.ended ? AppTheme.fg(context, 0.7) : const Color(0xFFB388FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.ended ? 'Poll ended' : 'Room poll',
                    style: TextStyle(
                      color: AppTheme.fg(context, 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$total votes',
                  style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              poll.question,
              style: TextStyle(
                color: AppTheme.fg(context),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...poll.options.map((option) {
              final selected = poll.selectedOptionId == option.id;
              final ratio = total == 0 ? 0.0 : option.voteCount / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap:
                      poll.hasVoted || poll.ended
                          ? null
                          : () => onVote(option.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? const Color(0xFF7E57C2).withValues(alpha: 0.5)
                              : AppTheme.themed(context, 0x1AFFFFFF, 0xFFF1F1FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            selected ? const Color(0xFFB388FF) : AppTheme.hairline(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.text,
                            style: TextStyle(
                              color: AppTheme.fg(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (poll.hasVoted || poll.ended)
                          Text(
                            '${(ratio * 100).round()}% (${option.voteCount})',
                            style: TextStyle(
                              color: AppTheme.fg(context, 0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

Future<void> showCreateRoomPollSheet(
  BuildContext context, {
  required void Function(String question, List<String> options) onCreate,
}) async {
  final question = TextEditingController();
  final first = TextEditingController();
  final second = TextEditingController();
  final third = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.themed(context, 0xFF17172A, 0xFFF8F7FE),
    builder:
        (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create Room Poll',
                style: TextStyle(
                  color: AppTheme.fg(sheetContext),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: question,
                style: TextStyle(color: AppTheme.fg(sheetContext)),
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: first,
                style: TextStyle(color: AppTheme.fg(sheetContext)),
                decoration: const InputDecoration(labelText: 'Option 1'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: second,
                style: TextStyle(color: AppTheme.fg(sheetContext)),
                decoration: const InputDecoration(labelText: 'Option 2'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: third,
                style: TextStyle(color: AppTheme.fg(sheetContext)),
                decoration: const InputDecoration(
                  labelText: 'Option 3 (optional)',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  final options =
                      [
                        first.text.trim(),
                        second.text.trim(),
                        third.text.trim(),
                      ].where((value) => value.isNotEmpty).toList();
                  if (question.text.trim().isEmpty || options.length < 2) {
                    return;
                  }
                  Navigator.pop(sheetContext);
                  onCreate(question.text.trim(), options);
                },
                child: const Text('Start Poll'),
              ),
            ],
          ),
        ),
  );
  question.dispose();
  first.dispose();
  second.dispose();
  third.dispose();
}
