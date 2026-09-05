import 'package:flutter/material.dart';

import '../models/room_runtime_models.dart';

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
          color: const Color(0xE6191930),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
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
                  color: poll.ended ? Colors.white70 : const Color(0xFFB388FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.ended ? 'Poll ended' : 'Room poll',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$total votes',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              poll.question,
              style: const TextStyle(
                color: Colors.white,
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
                              : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            selected ? const Color(0xFFB388FF) : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (poll.hasVoted || poll.ended)
                          Text(
                            '${(ratio * 100).round()}% (${option.voteCount})',
                            style: const TextStyle(
                              color: Colors.white70,
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
    backgroundColor: const Color(0xFF17172A),
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
              const Text(
                'Create Room Poll',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: question,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: first,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Option 1'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: second,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Option 2'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: third,
                style: const TextStyle(color: Colors.white),
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
