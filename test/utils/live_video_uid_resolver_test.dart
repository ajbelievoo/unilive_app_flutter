import 'package:belive/utils/live_video_uid_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveLiveVideoParticipant', () {
    test('room host always maps remote publisher to co-host', () {
      expect(
        resolveLiveVideoParticipant(
          isRoomHost: true,
          remoteUid: 202,
          expectedHostUid: 101,
          currentHostUid: null,
          knownCoHostUids: const {},
        ),
        LiveVideoParticipantRole.coHost,
      );
    });

    test('audience maps only authoritative host uid to main canvas', () {
      expect(
        resolveLiveVideoParticipant(
          isRoomHost: false,
          remoteUid: 101,
          expectedHostUid: 101,
          currentHostUid: null,
          knownCoHostUids: const {202},
        ),
        LiveVideoParticipantRole.host,
      );
      expect(
        resolveLiveVideoParticipant(
          isRoomHost: false,
          remoteUid: 202,
          expectedHostUid: 101,
          currentHostUid: 101,
          knownCoHostUids: const {202},
        ),
        LiveVideoParticipantRole.coHost,
      );
    });

    test('audience discovers host when backend host uid is missing', () {
      expect(
        resolveLiveVideoParticipant(
          isRoomHost: false,
          remoteUid: 345,
          expectedHostUid: 0,
          currentHostUid: null,
          knownCoHostUids: const {},
        ),
        LiveVideoParticipantRole.host,
      );
    });

    test('PK opponent never enters the co-host strip', () {
      expect(
        resolveLiveVideoParticipant(
          isRoomHost: true,
          remoteUid: 909,
          expectedHostUid: 101,
          currentHostUid: null,
          knownCoHostUids: const {},
          pkOpponentUid: 909,
        ),
        LiveVideoParticipantRole.pkOpponent,
      );
    });
  });

  group('resolvePkScores', () {
    test('reads host scores from numeric and string payload values', () {
      expect(
        resolvePkScores(
          payload: const {'host1Score': '125', 'host2Score': 75},
          currentHost1: 10,
          currentHost2: 20,
        ),
        (host1: 125, host2: 75),
      );
    });

    test('supports score aliases without resetting missing values', () {
      expect(
        resolvePkScores(
          payload: const {'score1': 40},
          currentHost1: 10,
          currentHost2: 20,
        ),
        (host1: 40, host2: 20),
      );
    });
  });

  group('pkScoresFromLocalPerspective', () {
    test('maps Host 2 local rank back to Host 1 perspective', () {
      expect(
        pkScoresFromLocalPerspective(
          localIsHost1: false,
          localScore: 90,
          remoteScore: 30,
        ),
        (host1: 30, host2: 90),
      );
    });
  });

  group('resolvePkRelayDestinationToken', () {
    test('uses the opposite channel token for each host relay', () {
      expect(
        resolvePkRelayDestinationToken(
          localIsHost1: true,
          host1Token: 'host-2-to-host-1',
          host2Token: 'host-1-to-host-2',
          host1RelayDestToken: null,
          host2RelayDestToken: null,
        ),
        'host-1-to-host-2',
      );
      expect(
        resolvePkRelayDestinationToken(
          localIsHost1: false,
          host1Token: 'host-2-to-host-1',
          host2Token: 'host-1-to-host-2',
          host1RelayDestToken: null,
          host2RelayDestToken: null,
        ),
        'host-2-to-host-1',
      );
    });

    test('prefers relay-specific destination tokens', () {
      expect(
        resolvePkRelayDestinationToken(
          localIsHost1: true,
          host1Token: 'host-2-to-host-1',
          host2Token: 'host-1-to-host-2',
          host1RelayDestToken: 'host-2-relay-dest',
          host2RelayDestToken: 'host-1-relay-dest',
        ),
        'host-1-relay-dest',
      );
      expect(
        resolvePkRelayDestinationToken(
          localIsHost1: false,
          host1Token: 'host-2-to-host-1',
          host2Token: 'host-1-to-host-2',
          host1RelayDestToken: 'host-2-relay-dest',
          host2RelayDestToken: 'host-1-relay-dest',
        ),
        'host-2-relay-dest',
      );
    });

    test('falls back to legacy tokens when relay-dest tokens are empty', () {
      expect(
        resolvePkRelayDestinationToken(
          localIsHost1: true,
          host1Token: 'host-2-to-host-1',
          host2Token: 'host-1-to-host-2',
          host1RelayDestToken: '   ',
          host2RelayDestToken: '   ',
        ),
        'host-1-to-host-2',
      );
      expect(
        resolvePkRelayDestinationToken(
          localIsHost1: false,
          host1Token: 'host-2-to-host-1',
          host2Token: 'host-1-to-host-2',
          host1RelayDestToken: null,
          host2RelayDestToken: null,
        ),
        'host-2-to-host-1',
      );
    });
  });

  group('PK participant connection data', () {
    test('accepting host replaces stale request channel and uid', () {
      expect(
        resolvePkParticipantChannel(
          authoritative: 'host-2-real-channel',
          fallback: 'host-1-stale-channel',
        ),
        'host-2-real-channel',
      );
      expect(resolvePkParticipantUid(authoritative: 222, fallback: 111), 222);
    });

    test('falls back only when authoritative connection data is absent', () {
      expect(
        resolvePkParticipantChannel(
          authoritative: ' ',
          fallback: 'host-2-request-channel',
        ),
        'host-2-request-channel',
      );
      expect(resolvePkParticipantUid(authoritative: 0, fallback: 222), 222);
    });
  });

  group('pkWinnerFromScores', () {
    test('uses native winner values for win, loss, and tie', () {
      expect(pkWinnerFromScores(host1Score: 10, host2Score: 5), 2);
      expect(pkWinnerFromScores(host1Score: 5, host2Score: 10), 1);
      expect(pkWinnerFromScores(host1Score: 10, host2Score: 10), 0);
    });
  });
}
