import 'package:flutter_test/flutter_test.dart';
import 'package:belive/models/audio_room_root.dart';
import 'package:belive/models/chat_root.dart';
import 'package:belive/models/chat_user_list_root.dart';
import 'package:belive/models/common_models.dart';
import 'package:belive/models/leaderboard_complain_models.dart';
import 'package:belive/models/level_summary_models.dart';
import 'package:belive/models/live_user_root.dart' as lur;
import 'package:belive/models/pk_call_models.dart';
import 'package:belive/models/room_runtime_models.dart';
import 'package:belive/models/store_models.dart';
import 'package:belive/models/transaction_models.dart';
import 'package:belive/services/api_service.dart';

void main() {
  group('RestResponse', () {
    test('fromJson parses correctly', () {
      final json = {'message': 'Success', 'status': true};
      final res = RestResponse.fromJson(json);
      expect(res.message, 'Success');
      expect(res.status, true);
    });

    test('fromJson handles missing fields', () {
      final res = RestResponse.fromJson({});
      expect(res.message, isNull);
      expect(res.status, false);
    });

    test('toJson roundtrips', () {
      final res = RestResponse(message: 'Test', status: true);
      final json = res.toJson();
      expect(json['message'], 'Test');
      expect(json['status'], true);
    });
  });

  group('ComplainItem', () {
    test('fromJson parses correctly', () {
      final json = {
        '_id': 'abc123',
        'userId': 'user1',
        'userName': 'John',
        'issue': 'spam',
        'message': 'User is spamming',
        'status': 'pending',
        'createdAt': '2024-01-01',
      };
      final item = ComplainItem.fromJson(json);
      expect(item.id, 'abc123');
      expect(item.userId, 'user1');
      expect(item.userName, 'John');
      expect(item.issue, 'spam');
      expect(item.status, 'pending');
    });

    test('fromJson handles alternative field names', () {
      final json = {
        'id': 'xyz',
        'name': 'Jane',
        'image': 'http://img.com/a.jpg',
        'contact': 'jane@email.com',
      };
      final item = ComplainItem.fromJson(json);
      expect(item.id, 'xyz');
      expect(item.userName, 'Jane');
      expect(item.userImage, 'http://img.com/a.jpg');
      expect(item.contactDetails, 'jane@email.com');
    });
  });

  group('LeaderboardEntry', () {
    test('rankingValue returns correct value per type', () {
      final entry = LeaderboardEntry(
        totalSpentDiamond: 500.0,
        totalEarnrCoin: 300,
        finalTotalAmount: 1000,
      );
      expect(entry.rankingValue('user'), 500);
      expect(entry.rankingValue('host'), 300);
      expect(entry.rankingValue('agency'), 1000);
    });

    test('displayName uses agency name when available', () {
      final entry = LeaderboardEntry(
        name: 'User',
        agency: LeaderboardAgency(name: 'MyAgency'),
      );
      expect(entry.displayName, 'MyAgency');
    });

    test('displayName falls back to name', () {
      final entry = LeaderboardEntry(name: 'User');
      expect(entry.displayName, 'User');
    });

    test('displayName falls back to Unknown', () {
      final entry = LeaderboardEntry();
      expect(entry.displayName, 'Unknown');
    });
  });

  group('LevelItem', () {
    test('fromJson parses correctly', () {
      final json = {
        '_id': 'lvl1',
        'name': 'Bronze',
        'image': 'http://img.com/bronze.png',
        'coin': 100,
        'cashOut': true,
        'liveStreaming': false,
      };
      final item = LevelItem.fromJson(json);
      expect(item.id, 'lvl1');
      expect(item.name, 'Bronze');
      expect(item.coin, 100);
      expect(item.cashOut, true);
      expect(item.liveStreaming, false);
    });
  });

  group('HostLevelItem', () {
    test('fromJson parses correctly', () {
      final json = {
        '_id': 'hl1',
        'name': 'Silver Host',
        'coin': 5000,
        'bgColor': '#CCCCCC',
      };
      final item = HostLevelItem.fromJson(json);
      expect(item.id, 'hl1');
      expect(item.name, 'Silver Host');
      expect(item.coin, 5000);
      expect(item.bgColor, '#CCCCCC');
    });
  });

  group('LiveSummaryRoot', () {
    test('fromJson parses correctly', () {
      final json = {
        'status': true,
        'duration': 3600,
        'comments': 50,
        'rCoin': 1000,
        'user': 200,
        'gifts': 75,
        'fans': 10,
      };
      final summary = LiveSummaryRoot.fromJson(json);
      expect(summary.status, true);
      expect(summary.duration, 3600);
      expect(summary.comments, 50);
      expect(summary.rCoin, 1000);
      expect(summary.user, 200);
      expect(summary.gifts, 75);
      expect(summary.fans, 10);
    });
  });

  group('ChatTopicRoot', () {
    test('fromJson extracts topic from chatTopic.chat', () {
      final json = {
        'status': true,
        'chatTopic': {'_id': 'topicDocId', 'chat': 'actual_conversation_id'},
      };
      final root = ChatTopicRoot.fromJson(json);
      expect(root.topic, 'actual_conversation_id');
      expect(root.status, true);
    });

    test('fromJson unwraps data wrapper', () {
      final json = {
        'status': true,
        'data': {
          'chatTopic': {'_id': 'topicDocId', 'chat': 'actual_conversation_id'},
        },
      };
      final root = ChatTopicRoot.fromJson(json);
      expect(root.topic, 'actual_conversation_id');
    });

    test('fromJson falls back to topic/topicId/id', () {
      expect(
        ChatTopicRoot.fromJson({'status': true, 'topic': 't1'}).topic,
        't1',
      );
      expect(
        ChatTopicRoot.fromJson({'status': true, 'topicId': 't2'}).topic,
        't2',
      );
      expect(ChatTopicRoot.fromJson({'status': true, 'id': 't3'}).topic, 't3');
    });
  });

  group('ChatUserListRoot', () {
    test(
      'ChatUserItem extracts topic from chatTopic.chat, not the doc _id',
      () {
        final json = {
          '_id': 'topicDocId',
          'chatTopic': {'_id': 'topicDocId', 'chat': 'actual_conversation_id'},
          'user': {
            '_id': 'u1',
            'name': 'Rom',
            'image': 'https://cdn.belive.app/rom.jpg',
          },
          'message': 'New',
          'unreadCount': 5,
        };
        final item = ChatUserItem.fromJson(json);
        expect(item.topic, 'actual_conversation_id');
        expect(item.userId, 'u1');
        expect(item.name, 'Rom');
        expect(item.message, 'New');
        expect(item.unreadCount, 5);
      },
    );

    test('ChatUserItem extracts topic from nested last-message map', () {
      final json = {
        '_id': 'topicDocId',
        'chat': {
          '_id': 'msg1',
          'topic': 'actual_conversation_id',
          'message': 'hello',
          'createdAt': '2025-08-11 14:25',
        },
        'user': {'_id': 'u2', 'name': 'TestUser'},
        'unreadCount': 4,
      };
      final item = ChatUserItem.fromJson(json);
      expect(item.topic, 'actual_conversation_id');
      expect(item.message, 'hello');
      expect(item.time, '2025-08-11 14:25');
      expect(item.unreadCount, 4);
    });

    test(
      'ChatUserItem does not mistake message _id for conversation topic',
      () {
        final json = {
          'chat': {'_id': 'msgId', 'topic': 'conversation_id', 'message': 'hi'},
        };
        final item = ChatUserItem.fromJson(json);
        expect(item.topic, 'conversation_id');
      },
    );

    test('ChatUserListRoot unwraps data wrapper', () {
      final json = {
        'status': true,
        'data': {
          'chatList': [
            {
              '_id': 't1',
              'topic': 'conv1',
              'user': {'_id': 'u1', 'name': 'A'},
            },
          ],
        },
      };
      final root = ChatUserListRoot.fromJson(json);
      expect(root.chatList.length, 1);
      expect(root.chatList.first.topic, 'conv1');
      expect(root.chatList.first.name, 'A');
    });
  });

  group('Report payload', () {
    test('normalizes reporter and target aliases', () {
      final payload = ApiService.normalizeReportPayload({
        'reporterUserId': 'reporter',
        'blockedUserId': 'target',
        'description': 'spam',
      });
      expect(payload['fromUserId'], 'reporter');
      expect(payload['toUserId'], 'target');
      expect(payload['reportedUserId'], 'target');
      expect(payload['reason'], 'spam');
    });
  });

  group('PkConfig', () {
    test('parses request and answer field aliases', () {
      final config = PkConfig.fromJson({
        'id': 'pk1',
        'requesterId': 'host1',
        'targetHostId': 'host2',
        'host1LiveStreamingId': 'room1',
        'targetRoomId': 'room2',
        'host1AgoraId': '101',
        'host2AgoraId': 202,
        'host1Channel': 'channel1',
        'host2Channel': 'channel2',
        'host1RelayDestToken': 'relay1',
        'host2RelayDestToken': 'relay2',
        'host1Details': 'invalid',
      });
      expect(config.pkId, 'pk1');
      expect(config.host1Id, 'host1');
      expect(config.host2Id, 'host2');
      expect(config.host1LiveId, 'room1');
      expect(config.host2LiveId, 'room2');
      expect(config.host1AgoraUID, 101);
      expect(config.host2AgoraUID, 202);
      expect(config.host1RelayDestToken, 'relay1');
      expect(config.host2RelayDestToken, 'relay2');
      expect(config.host1Details, isNull);
    });

    test('parses authoritative PK session response', () {
      final root = PkCallRoot.fromJson({
        'status': true,
        'pkCall': {
          '_id': 'pk2',
          'host1Id': 'host1',
          'host2Id': 'host2',
          'host1Channel': 'one',
          'host2Channel': 'two',
          'host1AgoraUID': 101,
          'host2AgoraUID': 202,
          'host1SrcToken': 'src1',
          'host2SrcToken': 'src2',
          'host1RelayDestToken': 'dest1',
          'host2RelayDestToken': 'dest2',
          'durationSeconds': 300,
          'pkRoundCount': 1,
        },
      });
      expect(root.pkCall?.id, 'pk2');
      expect(root.pkCall?.hostId, 'host1');
      expect(root.pkCall?.guestId, 'host2');
      expect(root.pkCall?.config?.host1RelayDestToken, 'dest1');
      expect(root.pkCall?.config?.pkRoundCount, 1);
    });

    test('live user ignores malformed PK config', () {
      final user = lur.LiveUser.fromJson({
        '_id': 'live1',
        'isPkMode': true,
        'pkConfig': 'invalid',
      });
      expect(user.isPkMode, true);
      expect(user.pkConfig, isNull);
    });
  });

  group('Audio room runtime contract', () {
    test('parses authoritative host position and seat state aliases', () {
      final room = AudioRoomUser.fromJson({
        '_id': 'room1',
        'hostUserId': 'host1',
        'hostPosition': 2,
        'musicPermission': 'friends',
        'seat': [
          {
            'position': 2,
            'userId': 'host1',
            'agoraUID': '1234',
            'mute': 1,
            'isLocked': true,
            'reserved': true,
            'role': 'host',
          },
        ],
      });
      expect(room.hostUserId, 'host1');
      expect(room.hostPosition, 2);
      expect(room.hasHostPosition, true);
      expect(room.musicPermission, 'friends');
      expect(room.seat.single.agoraUid, 1234);
      expect(room.seat.single.mute, 1);
      expect(room.seat.single.lock, true);
    });
  });

  group('Room runtime models', () {
    test('parses authoritative room gift total wrapper', () {
      final root = RoomGiftTotalRoot.fromJson({
        'status': true,
        'data': {
          'totalCoins': 12345,
          'windowStartedAt': '2026-08-29T10:00:00Z',
          'expiresAt': '2026-08-30T10:00:00Z',
        },
      });
      expect(root.status, true);
      expect(root.data?.totalCoins, 12345);
      expect(root.data?.expiresAt, DateTime.parse('2026-08-30T10:00:00Z'));
    });

    test('parses room poll counts and voter state', () {
      final poll = RoomPoll.fromJson({
        'pollId': 'poll1',
        'liveStreamingId': 'room1',
        'question': 'Choose one',
        'options': [
          {'id': 'a', 'text': 'A', 'count': 3},
          {'id': 'b', 'text': 'B', 'votes': 2},
        ],
        'hasVoted': true,
        'selectedOptionId': 'a',
      });
      expect(poll.pollId, 'poll1');
      expect(poll.totalVotes, 5);
      expect(poll.hasVoted, true);
      expect(poll.selectedOptionId, 'a');
    });

    test('parses realtime analytics aliases', () {
      final analytics = LiveRoomAnalytics.fromJson({
        'data': {
          'currentViewers': 15,
          'peakViewers': 30,
          'totalCoins': 500,
          'liveSeconds': 120,
          'watchTimeMinutes': 45,
        },
      });
      expect(analytics.viewerCount, 15);
      expect(analytics.peakViewerCount, 30);
      expect(analytics.receivedCoins, 500);
      expect(analytics.durationSeconds, 120);
      expect(analytics.watchMinutes, 45);
    });
  });

  group('StoreItemRoot', () {
    test('parses nested catalog items', () {
      final root = StoreItemRoot.fromJson({
        'status': true,
        'data': {
          'items': [
            {'_id': 'item1', 'name': 'Frame', 'diamond': '250'},
          ],
        },
      });
      expect(root.status, true);
      expect(root.data.single.id, 'item1');
      expect(root.data.single.diamond, 250);
    });

    test('parses nested owned inventory', () {
      final root = OwnedStoreItemRoot.fromJson({
        'status': true,
        'data': {
          'inventory': [
            {'_id': 'owned1', 'itemId': 'item1', 'source': 'buy'},
          ],
        },
      });
      expect(root.status, true);
      expect(root.data.single.id, 'owned1');
      expect(root.data.single.itemId, 'item1');
    });
  });

  group('TransactionHistoryRoot', () {
    test('parses wrapped offline recharge record', () {
      final root = TransactionHistoryRoot.fromJson({
        'status': true,
        'data': {
          'total': 1,
          'history': [
            {
              '_id': 'txn1',
              'type': 'credit',
              'category': 'offline_recharge',
              'coin': '500',
              'relatedUserId': 'seller1',
              'idempotencyKey': 'recharge-1',
              'createdAt': '2026-08-29T10:00:00Z',
            },
          ],
        },
      });
      expect(root.status, true);
      expect(root.total, 1);
      expect(root.history.single.category, 'offline_recharge');
      expect(root.history.single.amount, 500);
      expect(root.history.single.relatedUserId, 'seller1');
      expect(root.history.single.idempotencyKey, 'recharge-1');
    });
  });

  group('ChatRoot', () {
    test('fromJson finds messages under data.chat', () {
      final json = {
        'status': true,
        'data': {
          'chat': [
            {
              '_id': 'm1',
              'senderId': 's1',
              'receiverId': 'r1',
              'message': 'hi',
              'messageType': 'message',
            },
          ],
        },
      };
      final root = ChatRoot.fromJson(json);
      expect(root.chat.length, 1);
      expect(root.chat.first.message, 'hi');
    });

    test('ChatItem fromJson coerces sender/receiver objects to ids', () {
      final json = {
        '_id': 'm1',
        'sender': {'_id': 's1'},
        'receiver': {'_id': 'r1'},
        'message': 'hello',
        'messageType': 'message',
      };
      final item = ChatItem.fromJson(json);
      expect(item.senderId, 's1');
      expect(item.receiverId, 'r1');
    });

    test('fromJson digs into chat Map for message list', () {
      final json = {
        'status': true,
        'chat': {
          '_id': 'topicDocId',
          'messages': [
            {
              '_id': 'm1',
              'senderId': 's1',
              'receiverId': 'r1',
              'message': 'nested',
            },
          ],
        },
      };
      final root = ChatRoot.fromJson(json);
      expect(root.chat.length, 1);
      expect(root.chat.first.message, 'nested');
    });

    test('fromJson finds messages under data.chatTopic.messages', () {
      final json = {
        'status': true,
        'data': {
          'chatTopic': {
            '_id': 'topicDocId',
            'chat': 'convId',
            'messages': [
              {
                '_id': 'm1',
                'senderId': 's1',
                'receiverId': 'r1',
                'message': 'deep nested',
              },
            ],
          },
        },
      };
      final root = ChatRoot.fromJson(json);
      expect(root.chat.length, 1);
      expect(root.chat.first.message, 'deep nested');
    });

    test('fromJson finds messages under top-level chatTopic.messages', () {
      final json = {
        'status': true,
        'chatTopic': {
          '_id': 'topicDocId',
          'chat': 'convId',
          'messages': [
            {
              '_id': 'm1',
              'senderId': 's1',
              'receiverId': 'r1',
              'message': 'top-level nested',
            },
          ],
        },
      };
      final root = ChatRoot.fromJson(json);
      expect(root.chat.length, 1);
      expect(root.chat.first.message, 'top-level nested');
    });

    test('fromJson handles data as a plain list', () {
      final json = {
        'status': true,
        'data': [
          {
            '_id': 'm1',
            'senderId': 's1',
            'receiverId': 'r1',
            'message': 'list data',
          },
        ],
      };
      final root = ChatRoot.fromJson(json);
      expect(root.chat.length, 1);
      expect(root.chat.first.message, 'list data');
    });
  });
}
