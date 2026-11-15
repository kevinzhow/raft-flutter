import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_api.dart';
import 'package:raft_flutter/features/artifacts/artifact_message_links.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_actions.dart';

import '../support/artifact_fake_client.dart';

/// Artifact ids, links, the deployment and the object summaries loader, as
/// Raft Web v1.24 reads them (WP-ART1).
void main() {
  test('short ids round-trip (shared artifactShortId)', () {
    expect(encodeArtifactShortId(artifactUuid), artifactShort);
    expect(decodeArtifactShortId(artifactShort), artifactUuid);
    expect(parseArtifactId(artifactShort), artifactId);
    expect(parseArtifactId(artifactId), artifactId);
    expect(parseArtifactId('not-an-id'), isNull);
    expect(artifactPagePath(artifactId, 3), '/artifacts/$artifactShort/v/3');
  });

  test(
    'links name an Artifact only on the app hosts (shared parseArtifactRef)',
    () {
      const hosts = ['app.raft.build', 'localhost'];
      ArtifactLinkTarget? at(String url) => artifactLinkTarget(url, hosts);
      expect(
        at('https://app.raft.build/artifacts/$artifactShort'),
        const ArtifactLinkTarget(artifactId),
      );
      expect(
        at('https://app.raft.build/artifacts/$artifactShort/v/2'),
        const ArtifactLinkTarget(artifactId, 2),
      );
      expect(
        at('http://localhost:15194/s/dev/artifacts/$artifactId'),
        const ArtifactLinkTarget(artifactId),
      );
      expect(
        at('https://a-pt-$artifactUuid.raftusercontent.com/x'),
        const ArtifactLinkTarget(artifactId),
      );
      expect(at('https://evil.example/artifacts/$artifactShort'), isNull);
      expect(at('https://app.raft.build/artifacts/$artifactShort/v/0'), isNull);
      expect(
        at('https://raft-artifacts.com/p/acme/report'),
        isNull,
        reason: 'legacy links keep the old viewer',
      );
      expect(at('https://app.raft.build/s/dev/channel/c1'), isNull);
    },
  );

  test(
    'visible links: bare and with words, once each, never code or images',
    () {
      const short = 'https://app.raft.build/artifacts/$artifactShort';
      expect(
        artifactVisibleLinks(
          'See [the page]($short/v/2) and $short. '
          '`$short/v/9` ![x]($short/v/8)\n```\n$short/v/7\n```\n<$short>',
        ),
        ['$short/v/2', short],
      );
      expect(mayLinkArtifacts('no link'), isFalse);
      expect(mayLinkArtifacts(short), isTrue);
    },
  );

  test('the official deployment frames from w.raftusercontent.com; a '
      'self-hosted one knows no content domain', () {
    final official = ArtifactDeployment.resolve('https://api.raft.build', null);
    expect(official.webOrigin, Uri.parse('https://app.raft.build'));
    expect(official.contentDomain, 'w.raftusercontent.com');
    expect(official.appHosts, ['app.raft.build']);
    final own = ArtifactDeployment.resolve('https://raft.example.com', [
      'raft.example.com',
    ]);
    expect(own.contentDomain, isNull);
    final embedding = ArtifactDeployment.resolve('https://raft.example.com', [
      'raft.example.com',
    ], embedOrigin: 'https://embed.content.example');
    expect(embedding.contentDomain, 'content.example');
    expect(
      ArtifactDeployment.resolve(
        'https://raft.example.com',
        null,
        embedOrigin: 'https://embed-staging.content.example',
      ).contentDomain,
      isNull,
    );
    expect(
      ArtifactDeployment.resolve(
        'https://api.raft.build',
        null,
        embedOrigin: 'https://embed.raftusercontent.com',
      ).contentDomain,
      'w.raftusercontent.com',
    );
    final local = ArtifactDeployment.resolve(
      'http://localhost:13022',
      ['localhost'],
      define: 'artifacts.localhost:18787',
      boundApi: 'http://localhost:13022',
    );
    expect(local.contentDomain, 'artifacts.localhost:18787');
    expect(artifactContentDomainOf('https://x.example'), isNull);
    expect(artifactContentDomainOf('com'), isNull);
  });

  test('zip names follow Web artifactZipName', () {
    expect(artifactZipName('probe', 1), 'probe v1.zip');
    expect(artifactZipName('Q3: 报告 / final', 4), 'Q3 final v4.zip');
    expect(artifactZipName('...', 2), 'artifact v2.zip');
  });

  test('summaries: one batched request per window, kept 60 s, 429 holds', () {
    fakeAsync((async) {
      final posts = <List<ArtifactLinkTarget>>[];
      Object? fail;
      final loader = ObjectSummaryLoader(
        post: (refs) async {
          posts.add(refs);
          if (fail != null) throw fail;
          return [
            for (final ref in refs)
              ref.version == 9
                  ? {
                      'ref': {'id': ref.id, 'version': 9},
                      'ok': false,
                      'reason': 'unavailable',
                    }
                  : {
                      'ref': {'id': ref.id, 'version': ?ref.version},
                      'ok': true,
                      'summary': artifactCardJson(version: ref.version ?? 1),
                    },
          ];
        },
      );
      const a = ArtifactLinkTarget(artifactId),
          b = ArtifactLinkTarget(artifactId, 9);
      expect(loader.stateOf(a), isA<ArtifactLinkLoading>());
      expect(loader.stateOf(b), isA<ArtifactLinkLoading>());
      async.elapse(const Duration(milliseconds: 20));
      expect(posts.length, 1);
      expect(posts.single, [a, b]);
      expect(loader.stateOf(a), isA<ArtifactLinkOk>());
      expect(loader.stateOf(b), isA<ArtifactLinkUnavailable>());
      async.elapse(const Duration(seconds: 30));
      loader.stateOf(a);
      async.elapse(const Duration(milliseconds: 20));
      expect(posts.length, 1, reason: 'kept for 60 s');
      loader.invalidate(artifactId);
      fail = RaftApiException.response(
        'slow down',
        status: 429,
        body: {'error': 'slow down'},
        retryAfter: const Duration(seconds: 3),
      );
      loader.stateOf(a);
      async.elapse(const Duration(milliseconds: 20));
      expect(posts.length, 2);
      expect(loader.stateOf(a), isA<ArtifactLinkUnavailable>());
      loader.dispose();
    });
  });

  test('the session reads workspace_artifacts_v0 and drops summaries on a '
      'server switch', () async {
    final client = ArtifactFakeClient();
    addTearDown(client.dispose);
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    addTearDown(w.dispose);
    final session = ArtifactSession.of(w);
    await pumpEventQueue();
    expect(session.enabled, isTrue);
    expect(
      session.linkTarget('https://app.raft.build/artifacts/$artifactShort'),
      const ArtifactLinkTarget(artifactId),
    );
    client.enabled = false;
    w.server = RaftRecord({'id': 's2', 'role': 'member'});
    w.notifyListeners();
    await pumpEventQueue();
    expect(session.enabled, isFalse);
    expect(
      session.linkTarget('https://app.raft.build/artifacts/$artifactShort'),
      isNull,
      reason: 'with the flag off a link to an Artifact is a plain link',
    );
  });
}
