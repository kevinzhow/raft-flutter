import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/platform/raft_deployment_links.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  test(
    'raftPermalinks reserves deployment aliases from public client config',
    () async {
      final (workspace, adapter) = await fixture('owner');
      addTearDown(workspace.dispose);
      adapter.routes['GET /public/client-config'] = (_) => {
        'appHosts': ['deployment.example.com'],
      };
      adapter.routes['GET /servers'] = (_) => [];
      await workspace.loadServerDirectory();
      final requests = adapter.calls.where(
        (call) => call.path == '/public/client-config',
      );
      expect(requests, hasLength(1));
      final links = RaftDeploymentLinks.of(workspace.client);
      await links.load();
      final hosts = raftAppHostnames(workspace);
      expect(
        webPreviewTarget('https://deployment.example.com.', hosts),
        isNull,
      );
      expect(
        webPreviewTarget('https://deployment.example.org', hosts),
        isNotNull,
      );
      expect(
        links
            .parse(
              'https://deployment.example.com/s/design/channel/abcdefab?msg=abcdef00',
            )
            ?.messageId,
        'abcdef00',
      );
      expect(requests, hasLength(1));
      expect(
        requests.single.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
    },
  );
}
