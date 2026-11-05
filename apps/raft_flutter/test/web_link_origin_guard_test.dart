import 'package:flutter_test/flutter_test.dart';

import 'support/web_link_origin_guard.dart';

void main() {
  test('relative API paths and in-app locations are not browser URLs', () {
    for (final source in [
      r"final path = '/integration-invites/${Uri.encodeComponent(token)}';",
      r"final location = Uri(path: '/s/${server.slug}/settings/integrations');",
      r"void load(RaftClient c) { c.get('/integration-invites/$token'); }",
      r"final location = Uri(path: '/s/' + slug);",
      r"final location = Uri(path: '/s/$slug', queryParameters: {'source': w.client.origin});",
      r"final path = '/integration-invites/${w.client.origin}';",
      r"void load(RaftClient c) { c.post('/integration-invites/$token', data: {'api': c.origin}); }",
    ]) {
      expect(bareApiWebLinks(source), isEmpty, reason: source);
    }
  });

  test('resolved Web origins and unrelated absolute URLs remain allowed', () {
    for (final source in [
      r"final web = ContentLinks.originFor(w.client.origin); final url = '${web.origin}/s/$slug';",
      r"final url = '${ContentLinks.originFor(w.client.origin).origin}/integration-invites/$token';",
      r"final url = Uri.parse('https://app.raft.build').replace(path: '/s/$slug');",
      r"final url = '$repository/releases/latest/download';",
      r"void first() { final root = w.client.origin; } void second(Uri root) { final url = '${root.origin}/join/$token'; }",
      r"final first = second; final second = first; final url = '${first.origin}/join/$token';",
    ]) {
      expect(bareApiWebLinks(source), isEmpty, reason: source);
    }
  });

  test(
    'bare API interpolation, aliases, concat and Uri routes are rejected',
    () {
      for (final source in [
        r"final url = '${w.client.origin}/join/$token';",
        r"final root = w.client.origin; final url = '$root/integration-invites/$token';",
        r"final owner = w.client; final root = owner.origin; final url = '$root/s/$slug';",
        r"void link(RaftClient c) { final owner = c; final again = owner; final url = '${again.origin}/join/$token'; }",
        r"final webOrigin = w.client.origin; final alias = webOrigin; final url = '$alias/s/$slug';",
        r"final root = Uri.parse('https://api.raft.build'); final url = root.replace(path: '/s/$slug');",
        r"void link(RaftClient arbitraryName) { final url = arbitraryName.origin + '/s/' + slug; }",
        r"final url = 'https://api.raft.build/download';",
        r"final url = Uri.parse(w.client.origin).resolve('/join/$token');",
        r"const root = String.fromEnvironment('RAFT_ORIGIN'); final url = '$root/join/$token';",
        r"final url = ContentLinks.messageUrl(origin: Uri.parse(w.client.origin), slug: slug, channelId: c, messageId: m);",
      ]) {
        expect(bareApiWebLinks(source), isNotEmpty, reason: source);
      }
    },
  );

  test(
    'resolver text and unrelated resolver calls cannot exempt bad links',
    () {
      for (final source in [
        r"// ContentLinks resolves Web origins.\nfinal url = '${w.client.origin}/join/$token';"
            .replaceFirst(r'\n', '\n'),
        r"final webOrigin = 'ContentLinks'; final url = '${w.client.origin}/s/$slug';",
        r"final good = ContentLinks.originFor(w.client.origin); final bad = '${w.client.origin}/join/$token';",
      ]) {
        expect(bareApiWebLinks(source), isNotEmpty, reason: source);
      }
    },
  );
}
