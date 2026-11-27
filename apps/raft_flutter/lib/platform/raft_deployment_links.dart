import 'dart:async';

import 'package:raft_client/raft_client.dart';

import '../data/raft_permalink.dart';
import 'content_links.dart';

class RaftDeploymentLinks {
  RaftDeploymentLinks._(this.client)
    : frontend = ContentLinks.originFor(client.origin) {
    _hosts = Set.unmodifiable({
      frontend.host,
      ...defaultRaftPermalinkHostnames,
    });
  }

  static final _deployments = Expando<RaftDeploymentLinks>();

  static RaftDeploymentLinks of(RaftClient client) =>
      _deployments[client] ??= RaftDeploymentLinks._(client);

  final RaftClient client;
  final Uri frontend;
  late Set<String> _hosts;
  Set<String> get hosts => _hosts;
  Future<RaftClientConfig>? _config;
  bool _prefetched = false;

  void prefetch(void Function() changed, bool Function() current) {
    if (_prefetched) return;
    _prefetched = true;
    final previous = hosts;
    unawaited(
      load().then((_) {
        if (!identical(previous, hosts) && current()) changed();
      }),
    );
  }

  Future<RaftClientConfig> load() =>
      _config ??= client.clientConfig().then((config) {
        final aliases = config.appHosts;
        if (aliases != null && !hosts.containsAll(aliases)) {
          _hosts = Set.unmodifiable({...hosts, ...aliases});
        }
        return config;
      });

  RaftPermalink? parse(String href) =>
      parseRaftPermalink(href, hostnames: hosts, webOrigin: frontend);

  ({String rawUrl, RaftPermalink parsed})? quote(String text, String? slug) =>
      extractFirstQuotedPermalink(
        text,
        hostnames: hosts,
        webOrigin: frontend,
        serverSlug: slug,
      );
}
