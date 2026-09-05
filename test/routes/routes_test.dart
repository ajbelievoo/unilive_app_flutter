import 'package:flutter_test/flutter_test.dart';
import 'package:belive/routes/app_routes.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('AppRoutes', () {
    test('router is a GoRouter instance', () {
      expect(AppRoutes.router, isA<GoRouter>());
    });

    test('all route name constants are non-empty', () {
      expect(AppRoutes.splash, isNotEmpty);
      expect(AppRoutes.login, isNotEmpty);
      expect(AppRoutes.main, isNotEmpty);
      expect(AppRoutes.chat, isNotEmpty);
      expect(AppRoutes.liveRoom, isNotEmpty);
      expect(AppRoutes.recharge, isNotEmpty);
      expect(AppRoutes.complaintList, isNotEmpty);
      expect(AppRoutes.complaintDetail, isNotEmpty);
      expect(AppRoutes.callRequest, isNotEmpty);
      expect(AppRoutes.unbanAccount, isNotEmpty);
    });

    test('router configuration is valid', () {
      expect(AppRoutes.router, isA<GoRouter>());
    });
  });
}
