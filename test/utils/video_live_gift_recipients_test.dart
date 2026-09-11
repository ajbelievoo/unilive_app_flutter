import 'package:flutter_test/flutter_test.dart';
import 'package:belive/utils/video_live_gift_recipients.dart';

void main() {
  group('buildVideoLiveGiftRecipients', () {
    test('includes host and accepted co-host payload shapes', () {
      final recipients = buildVideoLiveGiftRecipients(
        hostId: 'host-1',
        hostName: 'Host',
        hostImage: 'host.png',
        coHosts: [
          {
            'userId': 'guest-1',
            'name': 'Guest One',
            'userImage': 'guest-1.png',
          },
          {
            'guestUserId': 'guest-2',
            'user': {'userName': 'Guest Two', 'avatar': 'guest-2.png'},
          },
        ],
      );

      expect(recipients.map((seat) => seat.userId), [
        'host-1',
        'guest-1',
        'guest-2',
      ]);
      expect(recipients.first.position, -1);
      expect(recipients.first.role, 'host');
      expect(recipients[1].name, 'Guest One');
      expect(recipients[2].name, 'Guest Two');
      expect(recipients.every((seat) => seat.reserved), isTrue);
    });

    test('drops empty and duplicate recipients', () {
      final recipients = buildVideoLiveGiftRecipients(
        hostId: 'same-user',
        hostName: 'Host',
        hostImage: '',
        coHosts: [
          {'userId': 'same-user', 'name': 'Duplicate'},
          {'name': 'Missing ID'},
        ],
      );

      expect(recipients, hasLength(1));
      expect(recipients.single.name, 'Host');
    });
  });
}
