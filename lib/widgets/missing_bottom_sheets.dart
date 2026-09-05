import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class BannedListSheet extends StatelessWidget {
  const BannedListSheet({super.key, required this.bannedUserIds});

  final List<String> bannedUserIds;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _sheetHeader(context, 'Banned Users', Icons.block, Colors.red),
            if (bannedUserIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${bannedUserIds.length} banned', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            Expanded(
              child: bannedUserIds.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 12),
                      Text('No banned users', style: TextStyle(color: Colors.grey)),
                    ]))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: bannedUserIds.length,
                      itemBuilder: (_, i) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withValues(alpha: 0.1),
                            ),
                            child: const Icon(Icons.person_off, color: Colors.red, size: 20),
                          ),
                          title: Text('User ${bannedUserIds[i]}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Unban', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          onTap: () => Navigator.pop(context, bannedUserIds[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetHeader(BuildContext context, String title, IconData icon, Color iconColor) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ],
        ),
      );
}

class BlockTimeSheet extends StatefulWidget {
  const BlockTimeSheet({super.key, required this.onSelect});

  final void Function(int hours) onSelect;

  @override
  State<BlockTimeSheet> createState() => _BlockTimeSheetState();
}

class _BlockTimeSheetState extends State<BlockTimeSheet> {
  static const _durations = [
    {'label': '1 Hour', 'hours': 1, 'icon': Icons.hourglass_empty},
    {'label': '6 Hours', 'hours': 6, 'icon': Icons.hourglass_bottom},
    {'label': '12 Hours', 'hours': 12, 'icon': Icons.hourglass_full},
    {'label': '24 Hours', 'hours': 24, 'icon': Icons.today},
    {'label': '3 Days', 'hours': 72, 'icon': Icons.date_range},
    {'label': '7 Days', 'hours': 168, 'icon': Icons.calendar_month},
    {'label': '30 Days', 'hours': 720, 'icon': Icons.calendar_today},
    {'label': 'Permanent', 'hours': -1, 'icon': Icons.block},
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
            child: Row(children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text('Select Block Duration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          ..._durations.map((d) {
            final isPermanent = (d['hours'] as int) == -1;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isPermanent ? Colors.red.withValues(alpha: 0.05) : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isPermanent ? Colors.red.withValues(alpha: 0.2) : Colors.transparent),
              ),
              child: ListTile(
                leading: Icon(d['icon'] as IconData, color: isPermanent ? Colors.red : AppTheme.primary),
                title: Text(d['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  widget.onSelect(d['hours'] as int);
                  Navigator.pop(context);
                },
              ),
            );
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class JoinRequestsSheet extends StatelessWidget {
  const JoinRequestsSheet({super.key, required this.requests, required this.onAccept, required this.onReject});

  final List<Map<String, dynamic>> requests;
  final void Function(String userId) onAccept;
  final void Function(String userId) onReject;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text('Join Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (requests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${requests.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: requests.isEmpty
                  ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 12),
                      Text('No pending requests', style: TextStyle(color: Colors.grey)),
                    ]))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: requests.length,
                      itemBuilder: (_, i) {
                        final req = requests[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.purpleGradient,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: req['image'] != null
                                  ? ClipOval(child: CachedNetworkImage(imageUrl: req['image'] as String, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white)))
                                  : const Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(req['name'] as String? ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _iconBtn(Icons.check, Colors.green, () => onAccept(req['userId'] as String)),
                                _iconBtn(Icons.close, Colors.red, () => onReject(req['userId'] as String)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class AdminListSheet extends StatelessWidget {
  const AdminListSheet({super.key, required this.adminIds});

  final List<String> adminIds;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Admins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: adminIds.isEmpty
                  ? const Center(child: Text('No admins'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: adminIds.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.shield)),
                        title: Text('Admin ${adminIds[i]}'),
                        trailing: TextButton(
                          onPressed: () => Navigator.pop(context, adminIds[i]),
                          child: const Text('Remove'),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class RankingSheet extends StatelessWidget {
  const RankingSheet({super.key, required this.rankings});

  final List<Map<String, dynamic>> rankings;

  static const _medalColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];
  static const _medalIcons = [Icons.emoji_events, Icons.military_tech, Icons.shield];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.leaderboard, color: Color(0xFFFFD700)),
                  const SizedBox(width: 8),
                  const Text('Ranking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: rankings.length,
                itemBuilder: (_, i) {
                  final r = rankings[i];
                  final isTop3 = i < 3;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: isTop3
                          ? LinearGradient(colors: [_medalColors[i].withValues(alpha: 0.15), _medalColors[i].withValues(alpha: 0.05)])
                          : null,
                      color: isTop3 ? null : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: isTop3 ? Border.all(color: _medalColors[i].withValues(alpha: 0.3), width: 1.5) : null,
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isTop3 ? LinearGradient(colors: [_medalColors[i], _medalColors[i].withValues(alpha: 0.7)]) : null,
                          color: isTop3 ? null : AppTheme.surfaceVariant,
                          boxShadow: isTop3 ? [BoxShadow(color: _medalColors[i].withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))] : null,
                        ),
                        child: isTop3
                            ? Icon(_medalIcons[i], color: Colors.white, size: 22)
                            : Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                      ),
                      title: Text(r['name'] as String? ?? 'User', style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.diamond, size: 16, color: Color(0xFFFFB800)),
                          const SizedBox(width: 4),
                          Text('${r['coin'] ?? r['diamond'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportOptionsSheet extends StatelessWidget {
  const ReportOptionsSheet({super.key, required this.onSelect});

  final void Function(String reason) onSelect;

  static const _reasons = [
    'Nudity or sexual content',
    'Hate speech',
    'Harassment or bullying',
    'Violence or harmful behavior',
    'Spam or misleading',
    'Illegal activities',
    'Other',
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
            child: Text('Report User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ..._reasons.map((r) => ListTile(
                leading: const Icon(Icons.flag, color: Colors.red),
                title: Text(r),
                onTap: () {
                  onSelect(r);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class MessageOptionsSheet extends StatelessWidget {
  const MessageOptionsSheet({
    super.key,
    required this.isStarred,
    required this.isMine,
    required this.onReply,
    required this.onStar,
    required this.onDelete,
    required this.onCopy,
  });

  final bool isStarred;
  final bool isMine;
  final VoidCallback onReply;
  final VoidCallback onStar;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

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
          ListTile(leading: const Icon(Icons.reply), title: const Text('Reply'), onTap: () { onReply(); Navigator.pop(context); }),
          ListTile(leading: Icon(isStarred ? Icons.star : Icons.star_border), title: Text(isStarred ? 'Unstar' : 'Star'), onTap: () { onStar(); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.copy), title: const Text('Copy'), onTap: () { onCopy(); Navigator.pop(context); }),
          if (isMine)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () { onDelete(); Navigator.pop(context); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class PkRoundHistorySheet extends StatelessWidget {
  const PkRoundHistorySheet({super.key, required this.rounds});

  final List<Map<String, dynamic>> rounds;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('PK Round History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: rounds.isEmpty
                  ? const Center(child: Text('No rounds completed'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: rounds.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text('Round ${i + 1}'),
                        subtitle: Text('Winner: ${rounds[i]['winnerName'] ?? 'N/A'}'),
                        trailing: Text('Score: ${rounds[i]['hostScore']} - ${rounds[i]['guestScore']}'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioRoomPasscodeSheet extends StatefulWidget {
  const AudioRoomPasscodeSheet({super.key, required this.onSubmit});

  final void Function(String passcode) onSubmit;

  @override
  State<AudioRoomPasscodeSheet> createState() => _AudioRoomPasscodeSheetState();
}

class _AudioRoomPasscodeSheetState extends State<AudioRoomPasscodeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          const Text('Enter Room Passcode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Passcode'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  widget.onSubmit(_controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Join Room'),
            ),
          ),
        ]),
      ),
    );
  }
}

class AudioRoomWelcomeSheet extends StatefulWidget {
  const AudioRoomWelcomeSheet({super.key, this.currentMessage = '', required this.onSave});

  final String currentMessage;
  final void Function(String message) onSave;

  @override
  State<AudioRoomWelcomeSheet> createState() => _AudioRoomWelcomeSheetState();
}

class _AudioRoomWelcomeSheetState extends State<AudioRoomWelcomeSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          const Text('Welcome Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter welcome message'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(_controller.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ),
        ]),
      ),
    );
  }
}

class WheatModeSheet extends StatelessWidget {
  const WheatModeSheet({super.key, required this.onSelect});

  final void Function(int mode) onSelect;

  static const _modes = [
    {'mode': 0, 'label': 'Free Talk', 'icon': Icons.mic_none},
    {'mode': 1, 'label': 'Raise Hand', 'icon': Icons.pan_tool_outlined},
    {'mode': 2, 'label': 'Host Only', 'icon': Icons.mic},
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
            child: Text('Mic Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ..._modes.map((m) => ListTile(
                leading: Icon(m['icon'] as IconData, color: AppTheme.primary),
                title: Text(m['label'] as String),
                onTap: () {
                  onSelect(m['mode'] as int);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class ViewersUsersSheet extends StatelessWidget {
  const ViewersUsersSheet({super.key, required this.viewers});

  final List<Map<String, dynamic>> viewers;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Viewers (${viewers.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: viewers.length,
                itemBuilder: (_, i) {
                  final v = viewers[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: v['image'] != null ? NetworkImage(v['image'] as String) : null,
                      child: const Icon(Icons.person),
                    ),
                    title: Text(v['name'] as String? ?? 'User'),
                    subtitle: Text(v['uniqueId'] as String? ?? ''),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HostMicSheet extends StatelessWidget {
  const HostMicSheet({super.key, required this.onMute, required this.onUnmute, this.isMuted = false});

  final VoidCallback onMute;
  final VoidCallback onUnmute;
  final bool isMuted;

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
            child: Text('Host Mic', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: Icon(isMuted ? Icons.mic : Icons.mic_off, color: isMuted ? Colors.green : Colors.red),
            title: Text(isMuted ? 'Unmute Mic' : 'Mute Mic'),
            onTap: () {
              if (isMuted) {
                onUnmute();
              } else {
                onMute();
              }
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class CommentDetailsSheet extends StatelessWidget {
  const CommentDetailsSheet({super.key, required this.comment, required this.onReply, required this.onReport, required this.onDelete, this.isMine = false});

  final Map<String, dynamic> comment;
  final VoidCallback onReply;
  final VoidCallback onReport;
  final VoidCallback onDelete;
  final bool isMine;

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
          ListTile(leading: const Icon(Icons.reply), title: const Text('Reply'), onTap: () { onReply(); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.flag, color: Colors.red), title: const Text('Report'), onTap: () { onReport(); Navigator.pop(context); }),
          if (isMine)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () { onDelete(); Navigator.pop(context); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class RedeemSheet extends StatefulWidget {
  const RedeemSheet({super.key, required this.maxCoins, required this.onSubmit});

  final int maxCoins;
  final void Function(int coins, String method, String account) onSubmit;

  @override
  State<RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<RedeemSheet> {
  final _coinController = TextEditingController();
  final _accountController = TextEditingController();
  String _method = 'bank';

  @override
  void dispose() {
    _coinController.dispose();
    _accountController.dispose();
    super.dispose();
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
          const Text('Redeem Beans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _coinController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Max: ${widget.maxCoins}',
              labelText: 'Beans to redeem',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _method,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'paypal', child: Text('PayPal')),
              DropdownMenuItem(value: 'upi', child: Text('UPI')),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'bank'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountController,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Account Details'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final coins = int.tryParse(_coinController.text) ?? 0;
                if (coins > 0 && _accountController.text.isNotEmpty) {
                  widget.onSubmit(coins, _method, _accountController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Submit'),
            ),
          ),
        ]),
      ),
    );
  }
}
