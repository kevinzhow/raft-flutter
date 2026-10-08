import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/public_avatar_url.dart';

void main() {
  test('public relative avatar resolves only at the active API origin', () {
    expect(
      raftPublicAvatarUrl(
        'http://127.0.0.1:13041/api',
        '/api/avatars/users/012345.webp',
      ),
      'http://127.0.0.1:13041/api/avatars/users/012345.webp',
    );
    expect(
      raftPublicAvatarUrl(
        'https://api.example.test',
        '/api/external-avatars/a.webp',
      ),
      'https://api.example.test/api/external-avatars/a.webp',
    );
    expect(
      raftPublicAvatarUrl(
        'https://second.example.test',
        '/api/avatars/users/012345.webp',
      ),
      'https://second.example.test/api/avatars/users/012345.webp',
    );
  });
  test('absolute provider and CDN URLs remain public and unchanged', () {
    const url = 'https://images.example.test/profile.webp?version=2';
    expect(raftPublicAvatarUrl('https://api.example.test', url), url);
  });
  test('private surfaces, implicit external authorities and unsafe schemes fail closed', () {
    for (final value in [
      '',
      '/api/attachments/private',
      '//external.example.test/a.webp',
      'pixel:mug',
      'file:///tmp/profile.webp',
      '/api/avatars/../auth/me',
      'https://user:password@example.test/a.webp',
    ]) {
      expect(raftPublicAvatarUrl('https://api.example.test', value), isNull);
    }
    expect(
      raftPublicAvatarUrl('file:///tmp', '/api/avatars/users/a.webp'),
      isNull,
    );
    expect(
      raftPublicAvatarUrl('not-an-origin', '/api/avatars/users/a.webp'),
      isNull,
    );
  });
}
