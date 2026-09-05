import 'dart:convert';
import 'dart:typed_data';

import 'package:belive/models/host_compliance_models.dart';
import 'package:belive/services/host_presence_guard_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Agora I420 conversion', () {
    test('converts tightly packed I420 planes to NV21', () {
      final image = HostPresenceGuardService.agoraFrameToInputImage(
        yBuffer: Uint8List.fromList(List<int>.generate(16, (i) => i)),
        uBuffer: Uint8List.fromList([10, 11, 12, 13]),
        vBuffer: Uint8List.fromList([20, 21, 22, 23]),
        yStride: 4,
        uStride: 2,
        vStride: 2,
        width: 4,
        height: 4,
        rotation: 0,
      );

      expect(image, isNotNull);
      expect(
        image!.bytes,
        Uint8List.fromList([
          0,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          20,
          10,
          21,
          11,
          22,
          12,
          23,
          13,
        ]),
      );
    });

    test('honors padded row strides', () {
      final image = HostPresenceGuardService.agoraFrameToInputImage(
        yBuffer: Uint8List.fromList([
          1,
          2,
          3,
          4,
          99,
          99,
          5,
          6,
          7,
          8,
          99,
          99,
          9,
          10,
          11,
          12,
          99,
          99,
          13,
          14,
          15,
          16,
          99,
          99,
        ]),
        uBuffer: Uint8List.fromList([30, 31, 99, 40, 41, 99]),
        vBuffer: Uint8List.fromList([50, 51, 99, 60, 61, 99]),
        yStride: 6,
        uStride: 3,
        vStride: 3,
        width: 4,
        height: 4,
        rotation: 0,
      );

      expect(image, isNotNull);
      expect(
        image!.bytes,
        Uint8List.fromList([
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
          50,
          30,
          51,
          31,
          60,
          40,
          61,
          41,
        ]),
      );
    });
  });

  group('presence timeline', () {
    test('uses exact warning and violation thresholds', () {
      expect(
        HostPresenceGuardService.severityForElapsedSeconds(59),
        HostPresenceSeverity.clear,
      );
      expect(
        HostPresenceGuardService.severityForElapsedSeconds(60),
        HostPresenceSeverity.warning,
      );
      expect(
        HostPresenceGuardService.severityForElapsedSeconds(179),
        HostPresenceSeverity.warning,
      );
      expect(
        HostPresenceGuardService.severityForElapsedSeconds(180),
        HostPresenceSeverity.violation,
      );
    });

    test('pauses without resetting and resets on compliance', () {
      final accumulated = HostPresenceGuardService.nextViolationElapsedMs(
        currentMs: 45000,
        elapsed: const Duration(seconds: 10),
        violating: true,
        paused: true,
      );
      expect(accumulated, 45000);
      expect(
        HostPresenceGuardService.nextViolationElapsedMs(
          currentMs: accumulated,
          elapsed: const Duration(seconds: 10),
          violating: false,
          paused: false,
        ),
        0,
      );
    });

    test('caps elapsed time at 180 seconds', () {
      expect(
        HostPresenceGuardService.nextViolationElapsedMs(
          currentMs: 179000,
          elapsed: const Duration(seconds: 5),
          violating: true,
          paused: false,
        ),
        180000,
      );
    });
  });

  group('penalty policy', () {
    test('maps daily violations to 5m, 1h, and 4h bans', () {
      final first = HostPresenceGuardService.tierForViolationCount(1);
      final second = HostPresenceGuardService.tierForViolationCount(2);
      final third = HostPresenceGuardService.tierForViolationCount(3);
      expect(first, HostPresenceBanTier.first);
      expect(second, HostPresenceBanTier.second);
      expect(third, HostPresenceBanTier.third);
      expect(HostPresenceGuardService.tierForViolationCount(10), third);
      expect(HostPresenceGuardService.banDurationMinutesForTier(first), 5);
      expect(HostPresenceGuardService.banDurationMinutesForTier(second), 60);
      expect(HostPresenceGuardService.banDurationMinutesForTier(third), 240);
    });

    test('keeps bans isolated by user and resets daily counter', () async {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final ban = HostPresenceBanInfo(
        tier: HostPresenceBanTier.second,
        banDurationMinutes: 60,
        banStartEpochMs: now.millisecondsSinceEpoch,
        banExpiresEpochMs:
            now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        dailyViolationCount: 2,
        violationDateKey: '2000-01-01',
      );
      SharedPreferences.setMockInitialValues({
        'host_presence_ban_info_userA': jsonEncode(ban.toJson()),
        'host_presence_violation_date_userA': '2000-01-01',
        'host_presence_violation_count_userA': 2,
      });

      expect(
        await HostPresenceGuardService.persistedBanForUser('userA'),
        isNotNull,
      );
      expect(
        await HostPresenceGuardService.persistedBanForUser('userB'),
        isNull,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('host_presence_violation_date_userA'), today);
      expect(prefs.getInt('host_presence_violation_count_userA'), 0);
    });
  });
}
