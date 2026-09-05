import 'package:flutter_test/flutter_test.dart';
import 'package:belive/services/iap_service.dart';

void main() {
  // Note: IapService.instance instantiates InAppPurchase.instance which
  // requires Google Play Billing platform bindings. These tests are skipped
  // in pure unit-test mode and should be run as integration tests on a
  // device/emulator.
  group('IapService', () {
    test('is a singleton', () {
      expect(IapService.instance, same(IapService.instance));
    }, skip: 'Requires platform plugin (Google Play Billing)');

    test('setUserId stores user id', () {
      IapService.instance.setUserId('test_user_123');
      // No getter exposed, but should not throw
      expect(() => IapService.instance.setUserId('test_user_123'), returnsNormally);
    }, skip: 'Requires platform plugin (Google Play Billing)');
  });
}
