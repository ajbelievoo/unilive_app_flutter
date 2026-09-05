import 'package:flutter_test/flutter_test.dart';
import 'package:belive/services/socket_service.dart';

void main() {
  group('SocketService', () {
    test('is a singleton', () {
      expect(SocketService.instance, same(SocketService.instance));
    });

    test('isConnected starts as false', () {
      expect(SocketService.instance.isConnected, false);
    });

    test('connectionStream is a broadcast stream', () {
      expect(SocketService.instance.connectionStream, isA<Stream<bool>>());
    });

    test('disconnect when not connected does not throw', () {
      expect(() => SocketService.instance.disconnect(), returnsNormally);
    });
  });
}
