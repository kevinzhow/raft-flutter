/// The frontend origin can differ from the coordinator API origin (the pinned
/// desktop Web uses VITE_FRONTEND_URL). An alias is explicitly bound to one API.
class ContentLinks {
  static Uri originFor(String coordinator, {String? frontend, String? api}) {
    final origin = Uri.parse(coordinator);
    final compiled =
        frontend ?? const String.fromEnvironment('RAFT_FRONTEND_ORIGIN');
    final boundApi =
        api ??
        const String.fromEnvironment(
          'RAFT_ORIGIN',
          defaultValue: 'http://localhost:13041',
        );
    if (compiled.isEmpty || Uri.tryParse(boundApi)?.origin != origin.origin) {
      return origin;
    }
    final value = Uri.tryParse(compiled);
    if (value == null ||
        !['https', 'http'].contains(value.scheme) ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.query.isNotEmpty ||
        value.fragment.isNotEmpty ||
        value.path.isNotEmpty && value.path != '/' ||
        value.scheme == 'http' &&
            !['localhost', '127.0.0.1', '::1'].contains(value.host)) {
      return origin;
    }
    return Uri.parse(value.origin);
  }

  static Uri messageUrl({
    required Uri origin,
    required String slug,
    required String channelId,
    required String messageId,
    String kind = 'channel',
    String? parentMessageId,
  }) => origin.replace(
    path: '/s/$slug/${kind == 'dm' ? 'dm' : 'channel'}/$channelId',
    queryParameters: {
      'msg': messageId,
      if (parentMessageId != null) 'thread': '$channelId:$parentMessageId',
    },
    fragment: null,
  );
}
