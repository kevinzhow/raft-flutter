import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_auth.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/computer_runtime_pi_sign_in_dialog.dart';
import 'package:raft_flutter/features/computer_runtime_sign_in_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show ignoreOverflow;
import 'support/close_support.dart';

/// A fake of the server and the Computer's login: records every request,
/// answers them from [onGet] / [onPost], and pushes login events and results
/// on this person's socket.
class FakeAuth {
  final socket = StreamController<RaftEvent>.broadcast();
  final posts = <(String, Map<String, dynamic>)>[];
  final gets = <String>[];
  int logins = 0;

  /// The id the next start answers with.
  String Function() nextLoginId = () => 'login-1';
  Object? startError;
  Completer<void>? startGate;
  Object? codeError;
  Future<dynamic> Function(String path)? onGet;
  Future<dynamic> Function(String path, Map<String, dynamic> body)? onPost;

  late final client = RuntimeAuthClient(
    get: (path) async {
      gets.add(path);
      final custom = onGet;
      if (custom == null) return {'kind': 'listed', 'providers': []};
      return await custom(path);
    },
    post: (path, body) async {
      posts.add((path, body));
      final custom = onPost;
      if (custom != null) return await custom(path, body);
      if (path.endsWith('/login')) {
        logins++;
        await startGate?.future;
        if (startError != null) throw startError!;
        return {'loginId': nextLoginId()};
      }
      if (path.endsWith('/code') && codeError != null) throw codeError!;
      return {'accepted': true};
    },
    events: socket.stream,
  );

  Iterable<(String, Map<String, dynamic>)> posted(String suffix) =>
      posts.where((p) => p.$1.endsWith(suffix));

  void event(
    Map<String, dynamic> event, {
    String loginId = 'login-1',
    String machineId = 'm1',
    String runtime = 'claude',
  }) => socket.add(
    RaftEvent('runtime_auth:login:event', {
      'serverId': 's1',
      'machineId': machineId,
      'runtime': runtime,
      'loginId': loginId,
      'event': event,
    }),
  );

  void result(
    Map<String, dynamic> result, {
    String loginId = 'login-1',
    String machineId = 'm1',
    String runtime = 'claude',
  }) => socket.add(
    RaftEvent('runtime_auth:login:result', {
      'serverId': 's1',
      'machineId': machineId,
      'runtime': runtime,
      'loginId': loginId,
      'result': result,
    }),
  );
}

RaftApiException refused(int status, [String? code]) =>
    RaftApiException.response(
      'refused',
      status: status,
      body: {'error': 'refused', 'code': ?code},
    );

Finder txt(String text) => find.text(text, findRichText: true);

/// A workspace at [size] with the Computer `m1` ("Studio Mac") listed and a
/// mock of the system browser; [open] opens the sign-in dialog again.
class SignInHarness {
  SignInHarness(this.t, this.fake, this.w, this.launched);
  final WidgetTester t;
  final FakeAuth fake;
  final WorkspaceController w;
  final List<String> launched;

  static Future<SignInHarness> mount(
    WidgetTester t,
    FakeAuth fake, {
    Size size = const Size(390, 844),
    TargetPlatform? platform,
  }) async {
    ignoreOverflow();
    final launched = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        null,
      ),
    );
    await t.pumpWidget(const SizedBox.shrink());
    final (w, api) = await mountWorkspace(
      t,
      size,
      platform: platform ?? closePlatform(size),
    );
    api.routes['GET /servers/s1/machines'] = (_) => {
      'machines': [
        {'id': 'm1', 'name': 'Studio Mac', 'isComputer': true},
      ],
    };
    await t.runAsync(
      () => w.services.entityDirectory.refresh(
        WorkspaceEntityKind.computers,
        force: true,
      ),
    );
    addTearDown(fake.socket.close);
    return SignInHarness(t, fake, w, launched);
  }

  BuildContext get context => t.element(find.byType(Scaffold).first);

  Future<void> settle([int n = 12]) => frames(t, n);

  Future<void> openSignIn({
    String runtime = 'claude',
    String runtimeId = 'claude',
  }) async {
    unawaited(
      showComputerRuntimeSignInDialog(
        context,
        controller: w,
        client: fake.client,
        serverId: 's1',
        machineId: 'm1',
        runtimeId: runtimeId,
        runtime: runtime,
      ),
    );
    await settle();
  }

  Future<void> openPi({String runtime = 'pi', String runtimeId = 'pi'}) async {
    unawaited(
      showComputerRuntimePiSignInDialog(
        context,
        controller: w,
        client: fake.client,
        serverId: 's1',
        machineId: 'm1',
        runtimeId: runtimeId,
        runtime: runtime,
      ),
    );
    await settle();
  }

  Future<void> tapKey(String key) async {
    await t.ensureVisible(find.byKey(ValueKey(key)));
    await t.tap(find.byKey(ValueKey(key)));
    await settle();
  }

  Future<void> push(
    Map<String, dynamic> event, {
    String loginId = 'login-1',
  }) async {
    fake.event(event, loginId: loginId);
    await settle();
  }

  Future<void> finish(
    Map<String, dynamic> result, {
    String loginId = 'login-1',
  }) async {
    fake.result(result, loginId: loginId);
    await settle();
  }

  Future<void> esc() async {
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(20);
  }

  bool get dialogOpen =>
      find.byType(ComputerRuntimeSignInView).evaluate().isNotEmpty ||
      find.byType(ComputerRuntimePiSignInView).evaluate().isNotEmpty;
}

void main() {
  Future<SignInHarness> signIn(
    WidgetTester t,
    FakeAuth fake, {
    String runtime = 'claude',
    String runtimeId = 'claude',
    Size size = const Size(390, 844),
  }) async {
    final h = await SignInHarness.mount(t, fake, size: size);
    await h.openSignIn(runtime: runtime, runtimeId: runtimeId);
    return h;
  }

  testWidgets('starts the login on the Computer and says so until it answers', (
    t,
  ) async {
    final fake = FakeAuth()..startGate = Completer<void>();
    final h = await signIn(t, fake);
    expect(txt('Sign in to Claude Code'), findsOneWidget);
    expect(txt('Starting sign-in on Studio Mac…'), findsOneWidget);
    expect(
      fake.posts.single.$1,
      contains('/machines/m1/runtime-auth/claude/login'),
    );
    expect(fake.posts.single.$2, isEmpty);
    fake.startGate!.complete();
    await h.settle();
    await h.push({'kind': 'auth_url', 'url': 'https://claude.ai/oauth'});
    expect(txt('Starting sign-in on Studio Mac…'), findsNothing);
  });

  testWidgets('an auth link opens in the system browser, not in the dialog', (
    t,
  ) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake);
    await h.push({
      'kind': 'auth_url',
      'url': 'https://claude.ai/oauth/authorize?x=1',
      'instructions': 'Open this URL to sign in.',
    });
    expect(
      txt('Open the sign-in page and finish signing in to Claude Code there.'),
      findsOneWidget,
    );
    // The runtime's own English line is never shown.
    expect(txt('Open this URL to sign in.'), findsNothing);
    await h.tapKey('runtime-sign-in-open-page');
    expect(h.launched, ['https://claude.ai/oauth/authorize?x=1']);
  });

  testWidgets('a device code shows its page and a copyable code', (t) async {
    final fake = FakeAuth();
    final copied = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = await signIn(t, fake, runtime: 'codex', runtimeId: 'codex');
    fake.event({
      'kind': 'device_code',
      'userCode': 'ABCD-1234',
      'verificationUri': 'https://auth.openai.com/device',
      'expiresInSeconds': 900,
    }, runtime: 'codex');
    await h.settle();
    expect(txt('Open this page and enter the code below:'), findsOneWidget);
    expect(txt('https://auth.openai.com/device'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('runtime-sign-in-device-code')),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').replaceAll('\u200b', '') == 'ABCD-1234',
        ),
      ),
      findsOneWidget,
    );
    expect(txt('The code expires in 15 minutes.'), findsOneWidget);
    await t.tap(txt('https://auth.openai.com/device'));
    await h.settle();
    expect(h.launched, ['https://auth.openai.com/device']);
    await t.tap(find.bySemanticsLabel('Copy code'));
    await h.settle();
    expect(copied, ['ABCD-1234']);
    // The copy mark's own 1.4s confirmation ends.
    await t.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('a pasted code is sent once and cleared; retry asks again', (
    t,
  ) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake);
    await h.push({'kind': 'auth_url', 'url': 'https://claude.ai/oauth'});
    await h.push({'kind': 'code_prompt', 'message': 'Paste code here'});
    expect(txt('Paste the code shown after signing in'), findsOneWidget);
    // The prompt's own words are the hint for a runtime that keeps them.
    expect(txt('Paste code here'), findsOneWidget);
    final submit = find.byKey(const ValueKey('runtime-sign-in-submit-code'));
    expect(t.widget<RaftButton>(submit).onPressed, isNull);
    await t.enterText(
      find.byKey(const ValueKey('runtime-sign-in-code')),
      '  abc#def  ',
    );
    await h.settle();
    await h.tapKey('runtime-sign-in-submit-code');
    final codes = fake.posted('/login/login-1/code').toList();
    expect(codes, hasLength(1));
    expect(codes.single.$2, {'code': 'abc#def'});
    // Sent: the field does not keep it.
    expect(
      t
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('runtime-sign-in-code')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '',
    );
    expect(txt('Checking the code…'), findsOneWidget);
    // The runtime did not accept it: a new prompt asks again.
    await h.push({'kind': 'code_prompt', 'retry': true});
    expect(txt('That code was not accepted, paste it again'), findsOneWidget);
    expect(txt('Checking the code…'), findsNothing);
    await t.enterText(
      find.byKey(const ValueKey('runtime-sign-in-code')),
      'second',
    );
    await h.settle();
    await h.tapKey('runtime-sign-in-submit-code');
    expect(fake.posted('/code').map((p) => p.$2['code']), [
      'abc#def',
      'second',
    ]);
  });

  testWidgets('Enter submits the pasted code', (t) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake, size: const Size(1280, 800));
    await h.push({'kind': 'code_prompt'});
    await t.enterText(
      find.byKey(const ValueKey('runtime-sign-in-code')),
      'xyz',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await h.settle();
    expect(fake.posted('/code').single.$2, {'code': 'xyz'});
  });

  testWidgets('a refused code keeps the field; a lost one can be resent', (
    t,
  ) async {
    final fake = FakeAuth()..codeError = refused(400, 'invalid_code');
    final h = await signIn(t, fake);
    await h.push({'kind': 'code_prompt'});
    await t.enterText(
      find.byKey(const ValueKey('runtime-sign-in-code')),
      'bad',
    );
    await h.settle();
    await h.tapKey('runtime-sign-in-submit-code');
    expect(txt('Paste the whole code from the sign-in page.'), findsOneWidget);
    expect(find.text('bad'), findsOneWidget);
    // It never got there: say so and keep it to resend.
    fake.codeError = refused(500);
    await h.tapKey('runtime-sign-in-submit-code');
    expect(txt("Couldn't send the code. Try again."), findsOneWidget);
    fake.codeError = null;
    await h.tapKey('runtime-sign-in-submit-code');
    expect(fake.posted('/code'), hasLength(3));
    expect(txt("Couldn't send the code. Try again."), findsNothing);
    expect(txt('Checking the code…'), findsOneWidget);
  });

  testWidgets('a code sent to a login that is gone ends the sign-in', (
    t,
  ) async {
    final fake = FakeAuth()..codeError = refused(404);
    final h = await signIn(t, fake);
    await h.push({'kind': 'code_prompt'});
    await t.enterText(find.byKey(const ValueKey('runtime-sign-in-code')), 'c');
    await h.settle();
    await h.tapKey('runtime-sign-in-submit-code');
    expect(txt('This sign-in has ended. Start it again.'), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-sign-in-retry')), findsOneWidget);
  });

  group('how a login that did not sign in is worded', () {
    const retryable = <(Map<String, dynamic>, String)>[
      ({'kind': 'busy'}, 'A sign-in is already running on this Computer.'),
      ({'kind': 'cancelled'}, 'The sign-in was cancelled.'),
      (
        {'kind': 'failed', 'reason': 'timed_out'},
        'The sign-in took too long and stopped. Try again.',
      ),
      (
        {'kind': 'failed', 'reason': 'rejected'},
        'Claude Code did not accept the sign-in. Try again.',
      ),
      (
        {'kind': 'failed', 'reason': 'not_logged_in'},
        'The sign-in finished, but Claude Code is still not signed in. Try again.',
      ),
      (
        {'kind': 'failed', 'reason': 'process_failed'},
        'Claude Code stopped before the sign-in finished. Try again.',
      ),
    ];
    const final_ = <(Map<String, dynamic>, String)>[
      (
        {'kind': 'unsupported', 'reason': 'version_unsupported'},
        'Claude Code on this Computer is too old to sign in from the web; update it there.',
      ),
      (
        {'kind': 'unsupported', 'reason': 'not_installed'},
        'Claude Code is not installed on this Computer.',
      ),
      (
        {'kind': 'unsupported', 'reason': 'unsupported_installation'},
        "This Claude Code installation can't be signed in from the web. Sign in on the Computer itself.",
      ),
      (
        {'kind': 'failed', 'reason': 'interaction_failed'},
        "Claude Code asked for something this page can't show. Sign in on the Computer itself.",
      ),
    ];

    testWidgets('retryable ones offer Try again, which starts a new login', (
      t,
    ) async {
      final fake = FakeAuth();
      final h = await signIn(t, fake);
      var n = 0;
      for (final (result, sentence) in retryable) {
        final id = 'login-${++n}';
        fake.nextLoginId = () => 'login-${n + 1}';
        await h.finish(result, loginId: id);
        expect(
          find.byKey(const ValueKey('runtime-sign-in-failed')),
          findsOneWidget,
        );
        expect(txt(sentence), findsOneWidget, reason: sentence);
        expect(txt('Close'), findsWidgets);
        await h.tapKey('runtime-sign-in-retry');
        // Back to starting, with no old words left.
        expect(txt(sentence), findsNothing);
        expect(fake.logins, n + 1);
      }
    });

    testWidgets('the others only close', (t) async {
      final fake = FakeAuth();
      final h = await signIn(t, fake);
      for (final (result, sentence) in final_) {
        await h.finish(result);
        expect(txt(sentence), findsOneWidget, reason: sentence);
        expect(
          find.byKey(const ValueKey('runtime-sign-in-retry')),
          findsNothing,
        );
        await h.esc();
        expect(h.dialogOpen, isFalse);
        await h.openSignIn();
      }
    });

    testWidgets('a result after the first one is ignored', (t) async {
      final fake = FakeAuth();
      final h = await signIn(t, fake);
      await h.finish({'kind': 'failed', 'reason': 'timed_out'});
      await h.finish({
        'kind': 'logged_in',
        'account': {'maskedLabel': 'a***@b.com'},
      });
      expect(
        txt('The sign-in took too long and stopped. Try again.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('runtime-sign-in-success')),
        findsNothing,
      );
    });
  });

  group('a start the server refused', () {
    const cases = <(int, String?, String, bool)>[
      (
        409,
        'computer_offline',
        'This Computer is offline. Connect it, then try again.',
        true,
      ),
      (
        409,
        'login_in_progress',
        'A sign-in is already running on this Computer.',
        true,
      ),
      (
        429,
        null,
        'Too many sign-in attempts on this Computer. Try again in a few minutes.',
        true,
      ),
      (
        403,
        null,
        'Only the person who connected this Computer, or an owner or admin, can sign its runtimes in or out.',
        false,
      ),
      (404, null, "This Computer or runtime wasn't found.", false),
      (
        409,
        'computer_upgrade_required',
        'Upgrade this Computer to sign in from here',
        false,
      ),
      (500, null, 'The sign-in could not start. Try again.', true),
    ];
    testWidgets('says why, and offers Try again only where it could help', (
      t,
    ) async {
      final fake = FakeAuth();
      final h = await SignInHarness.mount(t, fake);
      for (final (status, code, sentence, again) in cases) {
        fake.startError = refused(status, code);
        await h.openSignIn();
        expect(txt(sentence), findsOneWidget, reason: sentence);
        expect(
          find.byKey(const ValueKey('runtime-sign-in-retry')),
          again ? findsOneWidget : findsNothing,
          reason: sentence,
        );
        if (again) {
          // Try again starts it for real once the server lets it.
          fake.startError = null;
          await h.tapKey('runtime-sign-in-retry');
          expect(txt(sentence), findsNothing);
          expect(txt('Starting sign-in on Studio Mac…'), findsOneWidget);
        }
        final cancels = fake.posted('/cancel').length;
        await h.esc();
        // A refused start left nothing running to cancel; a started one does.
        expect(fake.posted('/cancel').length - cancels, again ? 1 : 0);
      }
    });
  });

  testWidgets('Cancel cancels the running login and closes', (t) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake);
    await h.push({'kind': 'auth_url', 'url': 'https://claude.ai/oauth'});
    await h.tapKey('runtime-sign-in-cancel');
    expect(fake.posted('/login/login-1/cancel'), hasLength(1));
    expect(h.dialogOpen, isFalse);
  });

  testWidgets('closing mid-login cancels it, by Esc and by the system back', (
    t,
  ) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake);
    await h.push({'kind': 'auth_url', 'url': 'https://claude.ai/oauth'});
    await h.esc();
    expect(h.dialogOpen, isFalse);
    expect(fake.posted('/login/login-1/cancel'), hasLength(1));
    fake.nextLoginId = () => 'login-2';
    await h.openSignIn();
    await h.push({
      'kind': 'auth_url',
      'url': 'https://claude.ai/oauth',
    }, loginId: 'login-2');
    await systemBack(t);
    expect(h.dialogOpen, isFalse);
    expect(fake.posted('/login/login-2/cancel'), hasLength(1));
  });

  testWidgets('closing while it starts cancels the login that began', (
    t,
  ) async {
    final fake = FakeAuth()..startGate = Completer<void>();
    final h = await signIn(t, fake);
    await h.esc();
    expect(fake.posted('/cancel'), isEmpty);
    fake.startGate!.complete();
    await h.settle();
    expect(fake.posted('/login/login-1/cancel'), hasLength(1));
  });

  testWidgets('a finished login is not cancelled on close', (t) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake);
    await h.finish({'kind': 'failed', 'reason': 'timed_out'});
    await h.tapKey('runtime-sign-in-cancel');
    expect(fake.posted('/cancel'), isEmpty);
  });

  testWidgets(
    'logged in: says where, shows the account, and the card re-reads',
    (t) async {
      final fake = FakeAuth();
      final h = await signIn(t, fake);
      var changed = 0;
      final stop = fake.client.watch('m1', () => changed++);
      addTearDown(stop);
      await h.finish({
        'kind': 'logged_in',
        'account': {'maskedLabel': 'a***@b.com', 'planLabel': 'Max'},
      });
      expect(txt('Claude Code is signed in on Studio Mac'), findsOneWidget);
      expect(txt('a***@b.com · Max'), findsOneWidget);
      expect(changed, 1);
      expect(find.byKey(const ValueKey('runtime-sign-in-retry')), findsNothing);
      await h.tapKey('runtime-sign-in-done');
      expect(h.dialogOpen, isFalse);
      expect(fake.posted('/cancel'), isEmpty);
    },
  );

  testWidgets('logged in without an account shows no account line', (t) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake);
    await h.finish({'kind': 'logged_in'});
    expect(txt('Claude Code is signed in on Studio Mac'), findsOneWidget);
  });

  testWidgets('Kimi asks for a region before anything starts', (t) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake, runtime: 'kimi', runtimeId: 'kimi-sdk');
    expect(fake.posts, isEmpty);
    expect(txt('Choose your Kimi Code account.'), findsOneWidget);
    expect(txt('Kimi Code (kimi.com/code)'), findsOneWidget);
    expect(txt('Kimi Code (kimi.ai/code)'), findsOneWidget);
    final cont = find.byKey(const ValueKey('runtime-sign-in-continue'));
    // Nothing is chosen by default: Continue waits.
    await t.tap(cont);
    await h.settle();
    expect(fake.posts, isEmpty);
    await t.tap(find.byKey(const ValueKey('runtime-sign-in-region-global')));
    await h.settle();
    await h.tapKey('runtime-sign-in-continue');
    expect(fake.posts.single.$2, {'region': 'global'});
    // Try again keeps the chosen region.
    fake.event({
      'kind': 'auth_url',
      'url': 'https://kimi.ai/x',
    }, runtime: 'kimi');
    fake.result({'kind': 'failed', 'reason': 'timed_out'}, runtime: 'kimi');
    await h.settle();
    fake.nextLoginId = () => 'login-2';
    await h.tapKey('runtime-sign-in-retry');
    expect(fake.posts.last.$2, {'region': 'global'});
    expect(fake.logins, 2);
  });

  testWidgets('Cancel on the region choice starts nothing', (t) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake, runtime: 'kimi', runtimeId: 'kimi-sdk');
    await h.tapKey('runtime-sign-in-cancel');
    expect(fake.posts, isEmpty);
    expect(h.dialogOpen, isFalse);
  });

  testWidgets('pushes for another login, Computer or runtime are ignored', (
    t,
  ) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake);
    fake.event({
      'kind': 'auth_url',
      'url': 'https://other.example/a',
    }, loginId: 'other');
    fake.event({
      'kind': 'auth_url',
      'url': 'https://other.example/b',
    }, machineId: 'm2');
    fake.event({
      'kind': 'auth_url',
      'url': 'https://other.example/c',
    }, runtime: 'codex');
    fake.result({'kind': 'failed', 'reason': 'timed_out'}, loginId: 'other');
    await h.settle();
    expect(txt('Starting sign-in on Studio Mac…'), findsOneWidget);
    expect(find.byKey(const ValueKey('runtime-sign-in-failed')), findsNothing);
    await h.push({'kind': 'auth_url', 'url': 'https://claude.ai/mine'});
    await h.tapKey('runtime-sign-in-open-page');
    expect(h.launched, ['https://claude.ai/mine']);
  });

  testWidgets('events that beat the start answer are shown once it comes', (
    t,
  ) async {
    final fake = FakeAuth()..startGate = Completer<void>();
    final h = await signIn(t, fake);
    fake.event({'kind': 'auth_url', 'url': 'https://claude.ai/early'});
    fake.event({
      'kind': 'auth_url',
      'url': 'https://other.example',
    }, loginId: 'other');
    await h.settle();
    expect(txt('Starting sign-in on Studio Mac…'), findsOneWidget);
    fake.startGate!.complete();
    await h.settle();
    await h.tapKey('runtime-sign-in-open-page');
    expect(h.launched, ['https://claude.ai/early']);
  });

  testWidgets('Antigravity words its paste step for the address too', (
    t,
  ) async {
    final fake = FakeAuth();
    final h = await signIn(
      t,
      fake,
      runtime: 'antigravity',
      runtimeId: 'antigravity',
    );
    fake.event({'kind': 'code_prompt'}, runtime: 'antigravity');
    await h.settle();
    expect(
      txt(
        'After signing in with Google, paste the code shown, or the full address your browser landed on.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('phone (Android 390x844): a bottom sheet', (t) async {
    final phone = await signIn(t, FakeAuth());
    expect(find.byKey(const ValueKey('raft-sheet-handle')), findsOneWidget);
    await phone.esc();
    expect(phone.dialogOpen, isFalse);
  });

  testWidgets('desktop (Linux): no sheet handle, Esc closes and cancels', (
    t,
  ) async {
    final fake = FakeAuth();
    final h = await signIn(t, fake, size: const Size(1280, 800));
    await h.push({'kind': 'auth_url', 'url': 'https://claude.ai/oauth'});
    expect(find.byKey(const ValueKey('raft-sheet-handle')), findsNothing);
    await h.esc();
    expect(h.dialogOpen, isFalse);
    expect(fake.posted('/login/login-1/cancel'), hasLength(1));
  });
}
