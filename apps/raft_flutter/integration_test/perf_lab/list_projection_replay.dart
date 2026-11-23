part of 'list_scenes.dart';

class _ProjectionReplay {
  _ProjectionReplay(this.fixture);

  final _ListFixture fixture;
  final saved = <Map<String, dynamic>>[];
  final search = <Map<String, dynamic>>[];
  final files = <Map<String, dynamic>>[];
  final apps = <Map<String, dynamic>>[];

  static bool supports(String surface) =>
      const {'search', 'saved', 'files', 'apps'}.contains(surface);

  LabAdapter get api => fixture.api;
  LabChannel get feed => fixture.feed;
  static const searchRead = 'GET /messages/search';
  static const savedRead = 'GET /channels/saved';
  static const save = 'POST /channels/saved';
  static const appsRead = 'GET /integrations/marketplace/listings';
  static const install = 'POST /integrations/marketplace/app-0/install';
  String get filesRead => 'GET /channels/${feed.id}/files';

  Map<String, dynamic> _message(String id, String content) => {
    ...feed.rows.first,
    'id': id,
    'messageId': id,
    'content': content,
    'channelName': feed.record.name,
    'savedAt': feed.rows.first['createdAt'],
  };

  void bind(LabImages images) {
    switch (fixture.surface) {
      case 'saved':
        api.routes[save] = (request) {
          final data = request.data as Map;
          if (data['messageId'] != 'replay-saved') {
            throw StateError('Unexpected save payload');
          }
          saved.insert(0, _message('replay-saved', 'Saved during replay'));
          return {};
        };
      case 'files':
        files.addAll([
          for (final (index, row) in feed.rows.indexed)
            {
              'id': 'file-$index',
              'channelId': feed.id,
              'messageId': row['id'],
              'filename': 'Lab image $index.png',
              'mimeType': 'image/png',
              'width': LabImages.sizes[index % 4].$1,
              'height': LabImages.sizes[index % 4].$2,
              'sizeBytes': images.pngs[index % 4].$3.length,
              'thumbnailUrl': images.url(index % 4, 'file-$index'),
              'createdAt': row['createdAt'],
              'source': {'type': 'channel', 'channelId': feed.id},
            },
        ]);
        api.routes[filesRead] = (request) =>
            _ListFixture._page(request, 'files', files);
      case 'apps':
        apps.addAll([
          for (var index = 0; index < _ListFixture.rowCount; index++)
            {
              'id': 'app-$index',
              'clientId': 'client-$index',
              'name': 'Lab application $index',
              'description': 'Workspace app for incoming notifications $index',
            },
        ]);
        api.routes.addAll({
          'GET /mcp/apps': (_) => {'apps': []},
          'GET /integrations/marketplace': (_) => apps,
          appsRead: (request) => _ListFixture._page(request, 'items', [
            for (final app in apps)
              {
                'kind': 'app',
                'id': 'app:${app['id']}',
                'name': app['name'],
                'app': app,
                'installed': app['installedAt'] != null,
              },
          ]),
          install: (_) {
            apps.firstWhere((app) => app['id'] == 'app-0')['installedAt'] =
                '2026-11-01T12:00:00Z';
            return {'ok': true};
          },
        });
    }
  }

  Future<Map<String, Object?>> run(
    WidgetTester tester, {
    required bool dark,
  }) async {
    final actions = <Map<String, Object?>>[];
    Finder key(String value) => find.byKey(ValueKey(value)).hitTestable();
    Future<void> visible(
      Finder target, {
      bool Function()? ready,
      bool present = true,
    }) async {
      bool arrived() =>
          target.evaluate().isNotEmpty == present && (ready?.call() ?? true);
      final timeout = Stopwatch()..start();
      while (!arrived() && timeout.elapsed < const Duration(seconds: 3)) {
        if (tester.takeException() case final Object error) throw error;
        await idle(const Duration(milliseconds: 16));
      }
      if (!arrived()) {
        throw StateError(
          'Expected $target, present: $present. Missing routes: ${api.misses}',
        );
      }
    }

    Future<void> step(
      String name,
      FutureOr<void> Function() dispatch,
      Finder target,
      List<String> routes,
    ) async {
      final before = {
        for (final route in routes) route: api.completedHits[route] ?? 0,
      };
      final start = developer.Timeline.now;
      await dispatch();
      await visible(
        target,
        ready: () => routes.every(
          (route) => (api.completedHits[route] ?? 0) > before[route]!,
        ),
      );
      final requests = {
        for (final route in routes)
          route: (api.completedHits[route] ?? 0) - before[route]!,
      };
      final end = developer.Timeline.now;
      actions.add({
        'name': name,
        't0': start,
        't1': end,
        'shownUs': end,
        'requests': requests,
      });
    }

    void upgrade() => fixture.client.emit('server:plan-updated', {
      'serverId': fixture.workspace.server!.id,
      'plan': 'pro',
    });
    Future<void> pull() async {
      final visibleRow = fixture.rows.first;
      final rect = fixture.visibleRect(visibleRow);
      final start = Offset(rect.left + 16, rect.center.dy);
      await tester.timedDragFrom(
        start,
        const Offset(0, 240),
        const Duration(milliseconds: 200),
      );
    }

    final surface = fixture.surface;
    final first = '${feed.id}-0';
    final (initial, read) = switch (surface) {
      'search' => ('search-message:$first', searchRead),
      'saved' => ('saved-$first', savedRead),
      'files' => ('channel-file-file-0', filesRead),
      _ => ('connected-app-app-0', appsRead),
    };
    await step(
      'load',
      () async {
        await fixture.mount(
          tester,
          dark: dark,
          touch: surface == 'files' || surface == 'apps',
        );
        if (surface == 'apps') {
          final marketplace = key('connected-apps-tab-marketplace');
          await visible(marketplace);
          await tester.tap(marketplace);
        }
      },
      key(initial),
      [read],
    );
    switch (surface) {
      case 'search':
        await step(
          'plan-change',
          () {
            search.add(_message('replay-search', 'Lab search result restored'));
            upgrade();
          },
          key('search-message:replay-search'),
          [searchRead],
        );
      case 'saved':
        await step(
          'save',
          () =>
              SavedCountStore.of(fixture.workspace)
                  .setSaved('replay-saved', true),
          key('saved-replay-saved'),
          [save, savedRead],
        );
        await step(
          'plan-change',
          () {
            saved.insert(0, _message('replay-restored', 'Restored by plan'));
            upgrade();
          },
          key('saved-replay-restored'),
          [savedRead],
        );
      case 'files':
        await step(
          'refresh',
          () async {
            files.insert(0, {
              ...files.first,
              'id': 'file-refresh',
              'filename': 'Lab refreshed image.png',
            });
            await pull();
          },
          key('channel-file-file-refresh'),
          [filesRead],
        );
        final lightbox = find.byType(RaftAttachmentLightbox);
        await step(
          'preview',
          () => tester.tap(key('channel-file-preview-file-refresh')),
          find
              .descendant(of: lightbox, matching: find.byType(Image))
              .hitTestable(),
          ['GET /attachments/file-refresh/url'],
        );
        final close = find
            .descendant(
              of: lightbox,
              matching: find.bySemanticsLabel('Close Preview'),
            )
            .hitTestable();
        await visible(close);
        await tester.tap(close);
        await visible(lightbox, present: false);
        await visible(key('channel-file-file-refresh'));
      case 'apps':
        await step(
          'refresh',
          () async {
            apps.insert(0, {
              'id': 'app-refresh',
              'clientId': 'client-refresh',
              'name': 'Lab refreshed application',
            });
            await pull();
          },
          key('connected-app-app-refresh'),
          [appsRead],
        );
        final confirm = key('connected-app-install');
        await step(
          'install',
          () async {
            await tester.tap(key(initial));
            await visible(find.text('Install to this server').hitTestable());
            await tester.tap(confirm);
          },
          find
              .descendant(
                of: find.byKey(ValueKey(initial)),
                matching: find.text('Installed'),
              )
              .hitTestable(),
          [install, appsRead],
        );
    }
    return {
      'arrived': true,
      'fixtureRows': fixture.size,
      'projectionActions': actions,
    };
  }
}
