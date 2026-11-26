import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Widget host(Widget child, Size size, {bool dark = false}) => MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: SizedBox.fromSize(
          size: size,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );

  for (final size in const [Size(390, 844), Size(841, 701), Size(1180, 820)]) {
    for (final dark in const [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets(
        'Wave 4A surfaces render cleanly at ${size.width.toInt()}x${size.height.toInt()} ($mode)',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1.0;
          addTearDown(() {
            t.view.resetPhysicalSize();
            t.view.resetDevicePixelRatio();
          });

          final agreementTitle = TextEditingController(text: 'House rules');
          final agreementBody = TextEditingController(
            text: '1. Be kind.\n2. Keep secrets private.',
          );
          addTearDown(() {
            agreementTitle.dispose();
            agreementBody.dispose();
          });

          await t.pumpWidget(
            host(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  RaftServerLabsSection(
                    status: RaftServerLabsStatus.ready,
                    masterEnabled: true,
                    canSetMaster: true,
                    onMasterChanged: (_) {},
                    labs: [
                      RaftServerLab(
                        key: 'voice',
                        name: 'Voice Channels',
                        description: 'Low-latency room audio.',
                        checked: true,
                        editable: true,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                  RaftArchivedChannelsSection(
                    rows: const [
                      RaftArchivedChannelRow(
                        id: 'ch-1',
                        name: 'legacy-ops',
                        type: 'channel',
                        metadata: 'Archived yesterday',
                      ),
                    ],
                    onOpen: (_) {},
                    onUnarchive: (_) {},
                  ),
                  RaftProviderConnectionsFrame(rows: const [], onAdd: () {}),
                  RaftMcpServersSection(
                    servers: [
                      RaftMcpServerRow(
                        id: 'mcp-1',
                        name: 'Linear',
                        provider: 'linear',
                        endpointUrl: 'https://mcp.linear.app/sse',
                        authMode: 'oauth',
                        oauthStatus: 'connected',
                        usageCalls: '14',
                        usageLastUsed: '2m ago',
                        usageLastTool: 'list_issues',
                      ),
                    ],
                    usage: true,
                  ),
                  const RaftAppEditorCallout(
                    'Scopes take effect on new grants.',
                  ),
                  const RaftAppEditorCallout(
                    'Rotation required before launch.',
                    tone: RaftAppEditorCalloutTone.warning,
                    bold: true,
                  ),
                  RaftAppEditorSecretReveal(
                    secret: 'raft_secret_abc123',
                    copied: false,
                    onCopy: () {},
                  ),
                  RaftDeclaredScopesPicker(
                    value: const {'profile', 'agent:message'},
                    onChanged: (_) {},
                    tooltips: const {
                      'profile': 'Basic profile',
                      'agent:message': 'Send agent messages',
                    },
                    fixedIdentity: const ['openid', 'profile'],
                    optionalIdentity: const ['email'],
                    agentMessaging: const ['agent:message'],
                  ),
                  RaftAppEditorSigningSecret(
                    secret: 'whsec_test_999',
                    copied: false,
                    onCopy: () {},
                  ),
                  const RaftOAuthScopeSummary(
                    title: 'Permissions',
                    description: 'Granted access scopes',
                    scopes: ['profile', 'agent:message'],
                    resourceScopes: {'agent:message'},
                  ),
                  RaftAppPermissionsApproval(
                    notice: 'This app requests additional scopes.',
                    groups: const ['agent:message', 'channel:read'],
                    action: RaftButton(label: 'Approve', onPressed: () {}),
                  ),
                  RaftAdminAgreementCard(
                    enabled: true,
                    onEnabled: (_) {},
                    title: agreementTitle,
                    body: agreementBody,
                    save: RaftAdminSaveState.idle,
                    onSave: () {},
                  ),
                  RaftPublicVisibilityCard(
                    publiclyVisible: true,
                    onPublic: (_) {},
                    publicUrl: 'https://raft.example/s/design',
                    onCopy: () {},
                    channels: const [
                      RaftPublicChannel(
                        name: 'announcements',
                        description: 'Release updates',
                      ),
                    ],
                  ),
                  RaftSettingsActionCard(
                    title: 'Diagnostics',
                    description: 'Export local logs for debugging.',
                    stacked: true,
                    action: RaftButton(label: 'Export', onPressed: () {}),
                  ),
                  const RaftSettingsSavedNote('Saved.'),
                  const RaftSettingsReadonlyValue(value: 'design-slug'),
                ],
              ),
              size,
              dark: dark,
            ),
          );

          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('RaftAdminPrincipalPicker opens RaftPopoverAnchor and selects', (
    t,
  ) async {
    String? selected;
    await t.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => host(
          RaftAdminPrincipalPicker(
            candidates: const [
              RaftAdminPrincipal(
                key: 'human:1',
                label: 'Ada Lovelace',
                agent: false,
                optionLabel: 'Ada Lovelace · ada@example.com',
              ),
              RaftAdminPrincipal(key: 'agent:2', label: 'Cipher', agent: true),
            ],
            selectedKey: selected,
            onSelect: (k) => setState(() => selected = k),
          ),
          const Size(841, 701),
        ),
      ),
    );

    await t.tap(find.byKey(const ValueKey('admin-principal-picker')));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-principal-popover')),
      findsOneWidget,
    );

    await t.tap(find.byKey(const ValueKey('admin-candidate-human:1')));
    await t.pumpAndSettle();
    expect(selected, 'human:1');
    expect(find.byKey(const ValueKey('admin-principal-popover')), findsNothing);
  });

  testWidgets('RaftAdminDateTimeField uses RaftDialog and applies/clears', (
    t,
  ) async {
    DateTime? current = DateTime(2026, 6, 10, 9, 30);
    await t.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => host(
          RaftAdminDateTimeField(
            value: current,
            onChanged: (next) => setState(() => current = next),
          ),
          const Size(841, 701),
        ),
      ),
    );

    await t.tap(find.byKey(const ValueKey('admin-join-link-expires-at')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-datetime-dialog')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('admin-datetime-day-15')));
    await t.tap(find.byKey(const ValueKey('admin-datetime-hour-up')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('admin-datetime-apply')));
    await t.pumpAndSettle();
    expect(current, DateTime(2026, 6, 15, 10, 30));

    await t.tap(find.byKey(const ValueKey('admin-join-link-expires-at')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('admin-datetime-clear')));
    await t.pumpAndSettle();
    expect(current, isNull);

    await t.tap(find.byKey(const ValueKey('admin-join-link-expires-at')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('admin-datetime-cancel')));
    await t.pumpAndSettle();
    expect(current, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'RaftAdminDateTimeField dialog scales at 2.0x and 3.1x without overflow',
    (t) async {
      final errors = <String>[];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString());
      addTearDown(() {
        FlutterError.onError = prevOnError;
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });

      for (final (size, platform, scale) in const [
        (Size(390, 844), TargetPlatform.android, 2.0),
        (Size(390, 844), TargetPlatform.iOS, 3.1),
        (Size(1280, 900), TargetPlatform.linux, 2.0),
        (Size(1280, 900), TargetPlatform.macOS, 3.1),
      ]) {
        errors.clear();
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1.0;

        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            builder: (context, inner) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(size: size, textScaler: TextScaler.linear(scale)),
              child: RaftTextScaling(child: inner!),
            ),
            home: Scaffold(
              body: RaftAdminDateTimeField(
                value: DateTime(2028, 2, 29, 23, 17),
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const ValueKey('admin-join-link-expires-at')));
        await t.pumpAndSettle();
        expect(
          errors,
          isEmpty,
          reason: 'Unexpected layout error at $size @ ${scale}x: $errors',
        );
        await t.tap(find.byKey(const ValueKey('admin-datetime-cancel')));
        await t.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'RaftAdminDateTimeField snaps arbitrary minutes to 5-minute steps',
    (t) async {
      DateTime? current = DateTime(2028, 2, 29, 12, 17);
      await t.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => host(
            RaftAdminDateTimeField(
              value: current,
              onChanged: (next) => setState(() => current = next),
            ),
            const Size(841, 701),
          ),
        ),
      );

      await t.tap(find.byKey(const ValueKey('admin-join-link-expires-at')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-datetime-min-up')));
      await t.tap(find.byKey(const ValueKey('admin-datetime-apply')));
      await t.pumpAndSettle();
      expect(current, DateTime(2028, 2, 29, 12, 20));

      current = DateTime(2028, 2, 29, 12, 17);
      await t.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => host(
            RaftAdminDateTimeField(
              value: current,
              onChanged: (next) => setState(() => current = next),
            ),
            const Size(841, 701),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('admin-join-link-expires-at')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-datetime-min-down')));
      await t.tap(find.byKey(const ValueKey('admin-datetime-apply')));
      await t.pumpAndSettle();
      expect(current, DateTime(2028, 2, 29, 12, 15));
    },
  );

  testWidgets('RaftAdminPrincipalPicker restores focus to trigger on Escape', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        RaftAdminPrincipalPicker(
          candidates: const [
            RaftAdminPrincipal(
              key: 'human:1',
              label: 'Ada Lovelace',
              agent: false,
            ),
          ],
          selectedKey: null,
          onSelect: (_) {},
        ),
        const Size(841, 701),
      ),
    );

    final trigger = find.byKey(const ValueKey('admin-principal-picker'));
    await t.tap(trigger);
    await t.pumpAndSettle();
    final searchField = find.descendant(
      of: find.byKey(const ValueKey('admin-principal-popover')),
      matching: find.byType(EditableText),
    );
    await t.tap(searchField);
    await t.pumpAndSettle();

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-principal-popover')), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'admin principal picker trigger',
    );
  });

  testWidgets(
    'RaftDashedBorderPainter handles zero size and zero width safely',
    (t) async {
      for (final (sz, w) in const [
        (Size.zero, 1.0),
        (Size(2, 2), 1.0),
        (Size(40, 20), 0.0),
      ]) {
        await t.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox.fromSize(
                size: sz,
                child: CustomPaint(
                  foregroundPainter: RaftDashedBorderPainter(
                    Colors.black,
                    w,
                    radius: 8,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
      }
    },
  );
}
