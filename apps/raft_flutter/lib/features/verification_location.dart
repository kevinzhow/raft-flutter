import 'package:raft_client/raft_client.dart';

import '../data/raft_location.dart';
import '../platform/content_links.dart';

Uri? localVerificationLocation(Uri location, String origin) {
  if (location.hasAuthority || location.hasScheme) {
    if (!const {'http', 'https'}.contains(location.scheme) ||
        !location.hasAuthority ||
        location.userInfo.isNotEmpty ||
        location.origin != ContentLinks.originFor(origin).origin) {
      return null;
    }
  }
  final local =
      '${location.path.isEmpty ? '/' : location.path}'
      '${location.hasQuery ? '?${location.query}' : ''}'
      '${location.hasFragment ? '#${location.fragment}' : ''}';
  return raftVerificationReturnPath(local);
}

Uri verificationLocationAfter(Uri current, Uri? landing) {
  if (!current.queryParameters.containsKey('verify')) return landing ?? current;
  return landing ??
      raftRemoveQueryParameters(current, const {'verify', 'returnTo'});
}
