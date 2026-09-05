import 'package:flutter_test/flutter_test.dart';
import 'package:belive/models/missing_models.dart';

void main() {
  group('AdsRoot', () {
    test('fromJson parses advertisement block', () {
      final json = {
        'status': true,
        'message': 'ok',
        'advertisement': {
          '_id': 'ad1',
          'banner': 'banner_id',
          'interstitial': 'int_id',
          'reward': 'rew_id',
          'native': 'native_id',
          'show': true,
        },
      };
      final res = AdsRoot.fromJson(json);
      expect(res.status, true);
      expect(res.advertisement, isNotNull);
      expect(res.advertisement!.id, 'ad1');
      expect(res.advertisement!.banner, 'banner_id');
      expect(res.advertisement!.nativeAd, 'native_id');
      expect(res.advertisement!.show, true);
    });

    test('fromJson handles null advertisement', () {
      final res = AdsRoot.fromJson({'status': false});
      expect(res.status, false);
      expect(res.advertisement, isNull);
    });
  });

  group('BroadcastBannerRoot', () {
    test('fromJson parses banner list', () {
      final json = {
        'status': true,
        'broadcastBanner': [
          {'_id': 'b1', 'image': 'http://img.com/1.jpg'},
          {'id': 'b2', 'image': 'http://img.com/2.jpg'},
        ],
      };
      final res = BroadcastBannerRoot.fromJson(json);
      expect(res.status, true);
      expect(res.broadcastBanner.length, 2);
      expect(res.broadcastBanner[0].id, 'b1');
      expect(res.broadcastBanner[1].id, 'b2');
    });
  });

  group('CountryRoot', () {
    test('fromJson parses country', () {
      final res = CountryRoot.fromJson({'countryName': 'India', 'countryImage': 91});
      expect(res.countryName, 'India');
      expect(res.countryImage, 91);
    });

    test('fromJson handles missing fields', () {
      final res = CountryRoot.fromJson({});
      expect(res.countryName, isNull);
      expect(res.countryImage, 0);
    });
  });

  group('HashtagRoot (missing_models copy)', () {
    test('fromJson parses hashtag list', () {
      final json = {
        'status': true,
        'hashtag': [
          {'_id': 'h1', 'hashtag': '#flutter', 'count': 42},
        ],
      };
      final res = HashtagRoot.fromJson(json);
      expect(res.status, true);
      expect(res.hashtag.length, 1);
      expect(res.hashtag[0].id, 'h1');
      expect(res.hashtag[0].hashtag, '#flutter');
      expect(res.hashtag[0].count, 42);
    });
  });

  group('HostLevelRoot (missing_models copy)', () {
    test('fromJson parses level list', () {
      final json = {
        'status': true,
        'level': [
          {'_id': 'l1', 'name': 'Bronze', 'coin': 100, 'bgColor': '#CD7F32'},
        ],
      };
      final res = HostLevelRoot.fromJson(json);
      expect(res.status, true);
      expect(res.level.length, 1);
      expect(res.level[0].id, 'l1');
      expect(res.level[0].name, 'Bronze');
      expect(res.level[0].coin, 100);
      expect(res.level[0].bgColor, '#CD7F32');
    });
  });

  group('ReactionRoot', () {
    test('fromJson parses reaction list', () {
      final json = {
        'status': true,
        'data': [
          {'_id': 'r1', 'image': 'http://img.com/r1.png'},
        ],
      };
      final res = ReactionRoot.fromJson(json);
      expect(res.status, true);
      expect(res.data.length, 1);
      expect(res.data[0].id, 'r1');
      expect(res.data[0].image, 'http://img.com/r1.png');
    });
  });

  group('SvgaListRoot', () {
    test('fromJson parses svga list', () {
      final json = {
        'status': true,
        'data': [
          {'_id': 's1', 'name': 'Heart', 'url': 'http://svga.com/heart.svga'},
        ],
      };
      final res = SvgaListRoot.fromJson(json);
      expect(res.status, true);
      expect(res.data.length, 1);
      expect(res.data[0].id, 's1');
      expect(res.data[0].name, 'Heart');
    });
  });

  group('BlockUserRoot', () {
    test('fromJson parses blocked state', () {
      final res = BlockUserRoot.fromJson({'blocked': true, 'expiresAt': '2025-12-31', 'status': true});
      expect(res.blocked, true);
      expect(res.expiresAt, '2025-12-31');
      expect(res.status, true);
    });

    test('fromJson defaults', () {
      final res = BlockUserRoot.fromJson({});
      expect(res.blocked, false);
      expect(res.expiresAt, isNull);
      expect(res.status, false);
    });
  });

  group('WhoBlockedmeRoot', () {
    test('fromJson parses blocked-by list', () {
      final json = {
        'status': true,
        'blockedUsers': [
          {
            '_id': 'b1',
            'userId': {'_id': 'u1', 'name': 'Alice'},
          },
        ],
        'total': 1,
      };
      final res = WhoBlockedmeRoot.fromJson(json);
      expect(res.status, true);
      expect(res.blockedUsers.length, 1);
      expect(res.blockedUsers[0].id, 'b1');
      expect(res.blockedUsers[0].userId?.name, 'Alice');
      expect(res.total, 1);
    });
  });

  group('CreateUserStripe', () {
    test('fromJson parses stripe credentials', () {
      final json = {
        'status': true,
        'publishableKey': 'pk_test_x',
        'customer': 'cus_123',
        'clientSecret': 'secret_abc',
      };
      final res = CreateUserStripe.fromJson(json);
      expect(res.status, true);
      expect(res.publishableKey, 'pk_test_x');
      expect(res.customer, 'cus_123');
      expect(res.clientSecret, 'secret_abc');
    });
  });
}
