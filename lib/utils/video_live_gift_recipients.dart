import '../models/audio_room_root.dart';

List<SeatItem> buildVideoLiveGiftRecipients({
  required String hostId,
  required String hostName,
  required String hostImage,
  required List<Map<String, dynamic>> coHosts,
}) {
  final recipients = <SeatItem>[];
  final seen = <String>{};

  void addRecipient(Map<String, dynamic> data, int position, String role) {
    final nested = data['user'];
    final nestedUser = nested is Map ? Map<String, dynamic>.from(nested) : null;
    final userId =
        (data['userId'] ??
                data['guestUserId'] ??
                nestedUser?['_id'] ??
                nestedUser?['userId'])
            ?.toString() ??
        '';
    if (userId.isEmpty || !seen.add(userId)) return;

    recipients.add(
      SeatItem(
        userId: userId,
        name:
            (data['name'] ??
                    data['userName'] ??
                    nestedUser?['name'] ??
                    nestedUser?['userName'])
                ?.toString(),
        image:
            (data['image'] ??
                    data['userImage'] ??
                    data['avatar'] ??
                    nestedUser?['image'] ??
                    nestedUser?['userImage'] ??
                    nestedUser?['avatar'])
                ?.toString(),
        position: position,
        reserved: true,
        role: role,
      ),
    );
  }

  addRecipient(
    {'userId': hostId, 'name': hostName, 'image': hostImage},
    -1,
    'host',
  );
  for (var index = 0; index < coHosts.length; index++) {
    addRecipient(coHosts[index], index, 'user');
  }
  return recipients;
}
