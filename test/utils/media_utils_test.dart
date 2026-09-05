import 'package:belive/utils/media_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoUtil gift URL resolution', () {
    test('getFullImageUrl returns empty for SVGA URLs', () {
      expect(
        VideoUtil.getFullImageUrl('assets/svga/zipper.svga'),
        '',
      );
      expect(
        VideoUtil.getFullImageUrl('/uploads/svga/zipper.svga'),
        '',
      );
      expect(
        VideoUtil.getFullImageUrl('https://cdn.example.com/svga/zipper.svga'),
        '',
      );
    });

    test('getFullSvgaUrl resolves relative and absolute SVGA paths', () {
      expect(
        VideoUtil.getFullSvgaUrl('/uploads/svga/zipper.svga'),
        'https://admin.unilive.me/uploads/svga/zipper.svga',
      );
      expect(
        VideoUtil.getFullSvgaUrl('zipper.svga'),
        'https://cdn.unilive.me/zipper.svga',
      );
      expect(
        VideoUtil.getFullSvgaUrl('https://cdn.example.com/zipper.svga'),
        'https://cdn.example.com/zipper.svga',
      );
    });

    test('getFullSvgaUrl also works for hashed / non-extension animation URLs', () {
      // Some CDNs use hashed paths with no .svga extension. The resolver
      // should still prepend the CDN so the overlay can attempt decode.
      expect(
        VideoUtil.getFullSvgaUrl('/uploads/svga/abc123def'),
        'https://admin.unilive.me/uploads/svga/abc123def',
      );
      expect(
        VideoUtil.getFullSvgaUrl('gifts/xyz789'),
        'https://cdn.unilive.me/gifts/xyz789',
      );
    });

    test('getFullImageUrl resolves normal image paths', () {
      expect(
        VideoUtil.getFullImageUrl('/uploads/gifts/zipper.png'),
        'https://admin.unilive.me/uploads/gifts/zipper.png',
      );
      expect(
        VideoUtil.getFullImageUrl('zipper.png'),
        'https://cdn.unilive.me/zipper.png',
      );
      expect(
        VideoUtil.getFullImageUrl('https://cdn.example.com/zipper.png'),
        'https://cdn.example.com/zipper.png',
      );
    });

    test('getFullImageUrl resolves video paths', () {
      expect(
        VideoUtil.getFullImageUrl('/uploads/gifts/zipper.mp4'),
        'https://admin.unilive.me/uploads/gifts/zipper.mp4',
      );
      expect(
        VideoUtil.getFullImageUrl('zipper.mp4'),
        'https://cdn.unilive.me/zipper.mp4',
      );
    });
  });
}
