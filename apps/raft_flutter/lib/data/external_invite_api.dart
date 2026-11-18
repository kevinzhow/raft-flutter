typedef ExternalJson = Map<String, dynamic>;

ExternalJson externalObject(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
List<ExternalJson> externalRows(Object? value) => value is List
    ? value.whereType<Map>().map(externalObject).toList()
    : const [];
String externalString(Object? value) => value is String ? value : '';

typedef ExternalInviteRequest = Future<dynamic> Function(
  String method,
  String path, {
  dynamic data,
});

class ExternalInviteApi {
  const ExternalInviteApi(this.request);

  final ExternalInviteRequest request;

  Future<ExternalJson> _send(
    String method,
    String path, [
    ExternalJson? data,
  ]) async => externalObject(await request(method, path, data: data));

  String _channel(String id) => '/channels/${Uri.encodeComponent(id)}';
  String _invite(String token) =>
      '/external-invites/${Uri.encodeComponent(token)}';
  String _approval(String id) =>
      '/server-connect-requests/${Uri.encodeComponent(id)}';

  Future<ExternalJson> previewLink(String token) =>
      _send('GET', '${_invite(token)}/preview');
  Future<ExternalJson> invite(String token) => _send('GET', _invite(token));
  Future<ExternalJson> guest(String token) =>
      _send('POST', '${_invite(token)}/accept-as-guest');
  Future<ExternalJson> connect(String token, String serverId) =>
      _send('POST', '${_invite(token)}/connect', {'serverId': serverId});
  Future<ExternalJson> connectServers(
    String token,
    List<ExternalJson> servers,
  ) => _send('POST', '${_invite(token)}/connect-servers', {'servers': servers});
  Future<ExternalJson> connectNew(String token, String name, String slug) =>
      _send('POST', '${_invite(token)}/connect-new-server', {
        'name': name,
        'slug': slug,
      });
  Future<ExternalJson> ask(
    String token,
    String serverId,
    String approverUserId,
  ) => _send('POST', '${_invite(token)}/request-approval', {
    'serverId': serverId,
    'approverUserId': approverUserId,
  });
  Future<ExternalJson> cancel(String token, [String? requestId]) => _send(
    'POST',
    '${_invite(token)}/cancel-request',
    requestId == null ? null : {'requestId': requestId},
  );

  Future<ExternalJson> approval(String id) => _send('GET', _approval(id));
  Future<ExternalJson> approve(String id) =>
      _send('POST', '${_approval(id)}/approve');
  Future<ExternalJson> reject(String id) =>
      _send('POST', '${_approval(id)}/reject');

  Future<bool> atFreeLimit() async =>
      (await _send(
        'GET',
        '/channels/external-availability',
      ))['freeLimitReached'] ==
      true;
  Future<ExternalJson> channelInvites(String id) =>
      _send('GET', '${_channel(id)}/external-invites');
  Future<ExternalJson> previewEmails(String? id, List<String> emails) => _send(
    'POST',
    '${id == null ? '/channels' : _channel(id)}/external-invites/preview',
    {'emails': emails},
  );
  Future<ExternalJson> sendEmails(
    String id,
    List<String> emails, {
    required bool makePrivate,
  }) => _send('POST', '${_channel(id)}/external-invites', {
    'emails': emails,
    if (makePrivate) 'makePrivate': true,
  });
  Future<ExternalJson> resend(String id, String inviteId) => _send(
    'POST',
    '${_channel(id)}/external-invites/${Uri.encodeComponent(inviteId)}/resend',
  );
  Future<ExternalJson> revoke(String id, String inviteId) => _send(
    'DELETE',
    '${_channel(id)}/external-invites/${Uri.encodeComponent(inviteId)}',
  );
  Future<List<ExternalJson>> ownServers() async => externalRows(
    (await _send('GET', '/channels/external-connect-servers'))['servers'],
  );
  Future<ExternalJson> connectOwn(
    String id,
    List<String> serverIds, {
    required bool makePrivate,
  }) => _send('POST', '${_channel(id)}/external-connect-servers', {
    'serverIds': serverIds,
    if (makePrivate) 'makePrivate': true,
  });
  Future<List<ExternalJson>> memberServers(String id) async => externalRows(
    (await _send('GET', '${_channel(id)}/connect-my-servers'))['servers'],
  );
  Future<ExternalJson> connectMemberServers(
    String id,
    List<String> serverIds,
  ) => _send('POST', '${_channel(id)}/connect-my-servers', {
    'serverIds': serverIds,
  });
  Future<ExternalJson> disconnect(String id, String serverId) => _send(
    'POST',
    '${_channel(id)}/joint-servers/${Uri.encodeComponent(serverId)}/disconnect',
  );
}
