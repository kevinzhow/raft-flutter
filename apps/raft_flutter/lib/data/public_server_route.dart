/// App.tsx: `/^\/s\/([^/]+)(?:\/channel\/([^/]+))?(?:\/.*)?$/`.
({String slug, String? channelId})? publicRoute(Uri location) {
  final segments = location.pathSegments;
  if (segments.length < 2 || segments.first != 's' || segments[1].isEmpty) {
    return null;
  }
  final channel = segments.length >= 4 && segments[2] == 'channel'
      ? segments[3]
      : null;
  return (slug: segments[1], channelId: channel);
}
