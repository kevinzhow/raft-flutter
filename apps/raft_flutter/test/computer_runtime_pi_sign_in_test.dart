import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/computer_runtime_sign_in_parts.dart';
import 'package:raft_ui/raft_ui.dart';

import 'computer_runtime_sign_in_test.dart'
    show FakeAuth, SignInHarness, refused, txt;

Map<String, dynamic> provider(
  String id,
  String label, {
  Map<String, dynamic>? oauth,
  List<Map<String, dynamic>>? methods,
  String? keyEntry,
  String? stored,
}) => {
  'id': id,
  'label': label,
  'configured': stored != null,
  'endpoint': {'kind': 'fixed'},
  'needsModelIds': false,
  'signIn': {
    'oauth': ?oauth,
    'oauthMethods': ?methods,
    if (keyEntry != null) 'apiKey': {'label': '$label key', 'entry': keyEntry},
    'stored': ?stored,
  },
};

Map<String, dynamic> listed(List<Map<String, dynamic>> providers) => {
  'kind': 'listed',
  'providers': providers,
};

const piProviders = <String>['anthropic', 'openai'];

Map<String, dynamic> flow(String label, String flow) => {
  'label': label,
  'flow': flow,
};

void main() {
  setUp(clearLoopbackRequiredForTests);

  Future<(SignInHarness, FakeAuth)> pi(
    WidgetTester t, {
    Object? providers,
    String runtime = 'pi',
    Size size = const Size(390, 844),
  }) async {
    final fake = FakeAuth()
      ..onGet = (path) async {
        if (providers is Future<dynamic> Function(String)) {
          return providers(path);
        }
        return providers ??
            listed([
              provider(
                'anthropic',
                'Anthropic',
                oauth: flow('Anthropic (Claude Pro/Max)', 'paste_code'),
                stored: 'oauth',
              ),
              provider(
                'github-copilot',
                'GitHub Copilot',
                oauth: flow('GitHub Copilot', 'device_code'),
              ),
              provider(
                'google-gemini-cli',
                'Google Gemini CLI',
                oauth: flow('Google Gemini CLI', 'paste_address'),
              ),
              provider(
                'local',
                'Local browser',
                oauth: flow('Local browser sign-in', 'computer_only'),
              ),
              provider('openai', 'OpenAI', keyEntry: 'key', stored: 'api_key'),
              provider('azure', 'Azure', keyEntry: 'more_fields'),
              provider('bedrock', 'Bedrock', keyEntry: 'outside'),
            ]);
      };
    final h = await SignInHarness.mount(t, fake, size: size);
    await h.openPi(runtime: runtime, runtimeId: runtime);
    return (h, fake);
  }

  Finder choice(String value) => find.byKey(ValueKey('pi-choice-$value'));

  Future<void> choose(SignInHarness h, String value) async {
    await h.t.ensureVisible(choice(value));
    await h.t.tap(choice(value));
    await h.settle();
  }

  testWidgets('reads the Computer\'s providers, saying so while it waits', (
    t,
  ) async {
    final gate = Completer<dynamic>();
    final (h, fake) = await pi(t, providers: (String path) => gate.future);
    expect(txt('Add a provider to Pi'), findsOneWidget);
    expect(txt('Reading the providers on Studio Mac…'), findsOneWidget);
    expect(
      fake.gets.single,
      endsWith('/machines/m1/runtime-auth/pi/providers'),
    );
    expect(
      find.byKey(const ValueKey('pi-sign-in-continue')),
      findsNothing,
      reason: 'nothing to continue with yet',
    );
    gate.complete(listed([provider('openai', 'OpenAI', keyEntry: 'key')]));
    await h.settle();
    expect(txt('Reading the providers on Studio Mac…'), findsNothing);
    expect(choice('key:openai'), findsOneWidget);
  });

  testWidgets('lists accounts and keys in two groups, with why a row waits', (
    t,
  ) async {
    final (h, _) = await pi(t);
    expect(txt('Sign in with an account'), findsOneWidget);
    expect(txt('Use an API key'), findsOneWidget);
    expect(txt('Anthropic (Claude Pro/Max)'), findsOneWidget);
    expect(txt('Sign in, then paste a code'), findsOneWidget);
    expect(txt('Sign in with a device code'), findsOneWidget);
    expect(txt('Sign in, then paste the page address'), findsOneWidget);
    // Stored sign-ins are marked, once per provider and way.
    expect(
      find.byKey(const ValueKey('pi-provider-signed-in-anthropic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pi-provider-signed-in-openai')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pi-provider-signed-in-azure')),
      findsNothing,
    );
    // A flow that needs the Computer's own browser, and keys that ask for
    // more or live outside Pi, are listed but cannot be chosen.
    expect(
      txt('Needs a browser on the Computer itself: sign in there'),
      findsOneWidget,
    );
    expect(
      txt('Asks for more than a key: set it up on the Computer'),
      findsOneWidget,
    );
    expect(txt('Set up outside Pi, on the Computer'), findsOneWidget);
    final cont = find.byKey(const ValueKey('pi-sign-in-continue'));
    expect(t.widget<RaftButton>(cont).onPressed, isNull);
    for (final value in ['account:local#0', 'key:azure', 'key:bedrock']) {
      await t.ensureVisible(choice(value));
      await t.tap(choice(value));
      await h.settle();
      expect(t.widget<RaftButton>(cont).onPressed, isNull, reason: value);
    }
    await choose(h, 'key:openai');
    expect(t.widget<RaftButton>(cont).onPressed, isNotNull);
  });

  testWidgets('search narrows the list; no match and no providers say so', (
    t,
  ) async {
    final (h, _) = await pi(t);
    await t.enterText(find.byType(EditableText).first, 'azure');
    await h.settle();
    expect(choice('key:azure'), findsOneWidget);
    expect(choice('key:openai'), findsNothing);
    await t.enterText(find.byType(EditableText).first, 'zzz');
    await h.settle();
    expect(txt('No matching providers'), findsOneWidget);
  });

  testWidgets('a Computer that lists no providers says so', (t) async {
    final (_, _) = await pi(t, providers: listed([]));
    expect(txt('Pi on this Computer lists no providers.'), findsOneWidget);
  });

  group('a provider list that did not come', () {
    testWidgets('a refused request says why; Try again reads it again', (
      t,
    ) async {
      var answers = 0;
      final (h, fake) = await pi(
        t,
        providers: (String path) async {
          if (answers++ == 0) throw refused(504);
          return listed([provider('openai', 'OpenAI', keyEntry: 'key')]);
        },
      );
      expect(
        txt('The Computer did not answer in time. Try again.'),
        findsOneWidget,
      );
      await h.tapKey('pi-sign-in-retry');
      expect(
        txt('The Computer did not answer in time. Try again.'),
        findsNothing,
      );
      expect(choice('key:openai'), findsOneWidget);
      expect(fake.gets, hasLength(2));
    });

    testWidgets('the ones Try again cannot help only close', (t) async {
      final fake = FakeAuth();
      final h = await SignInHarness.mount(t, fake);
      const cases = <(Object, String)>[
        (
          {'kind': 'unsupported', 'reason': 'not_installed'},
          'Pi is not installed on this Computer.',
        ),
        (
          {'kind': 'unsupported', 'reason': 'version_unsupported'},
          "Pi on this Computer can't be connected from the web.",
        ),
        (
          {'kind': 'failed', 'reason': 'invalid_response'},
          "Pi answered in a way this page can't read. Update Pi on the Computer, then try again.",
        ),
      ];
      for (final (answer, sentence) in cases) {
        fake.onGet = (path) async => answer;
        await h.openPi();
        expect(txt(sentence), findsOneWidget, reason: sentence);
        expect(find.byKey(const ValueKey('pi-sign-in-retry')), findsNothing);
        await h.tapKey('pi-sign-in-close');
        expect(h.dialogOpen, isFalse);
      }
      fake.onGet = (path) async => {'kind': 'failed', 'reason': 'timed_out'};
      await h.openPi();
      expect(txt('Pi took too long to answer. Try again.'), findsOneWidget);
      expect(find.byKey(const ValueKey('pi-sign-in-retry')), findsOneWidget);
      fake.onGet = (path) async => throw refused(403);
      await h.tapKey('pi-sign-in-retry');
      expect(
        txt(
          'Only the person who connected this Computer, or an owner or admin, can connect its runtimes to a provider.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pi-sign-in-retry')), findsNothing);
    });
  });

  group('signing a provider in with its account', () {
    testWidgets('Pi: pasting the page address, named after the provider', (
      t,
    ) async {
      final (h, fake) = await pi(t);
      await choose(h, 'account:google-gemini-cli#0');
      await h.tapKey('pi-sign-in-continue');
      // The same dialog goes on to the login, named after Pi's sign-in.
      expect(txt('Sign in to Google Gemini CLI'), findsOneWidget);
      final (path, body) = fake.posted('/login').single;
      expect(path, endsWith('/runtime-auth/pi/login'));
      expect(body, {'providerId': 'google-gemini-cli'});
      fake.event({
        'kind': 'auth_url',
        'url': 'https://accounts.google.com/o/oauth2',
      }, runtime: 'pi');
      fake.event({
        'kind': 'code_prompt',
        'message': 'pi english',
      }, runtime: 'pi');
      await h.settle();
      expect(txt('Paste the address of the page you land on'), findsOneWidget);
      expect(
        txt(
          "After signing in, your browser lands on a page that won't load. Paste the full address from the address bar here.",
        ),
        findsOneWidget,
      );
      // The prompt's own English is not shown for a provider.
      expect(txt('pi english'), findsNothing);
      await t.enterText(
        find.byKey(const ValueKey('runtime-sign-in-code')),
        'http://localhost:1455/auth/callback?code=abc',
      );
      await h.settle();
      await h.tapKey('runtime-sign-in-submit-code');
      expect(fake.posted('/code').single.$2, {
        'code': 'http://localhost:1455/auth/callback?code=abc',
      });
    });

    testWidgets('Pi: a pasted code is worded as a code', (t) async {
      final (h, fake) = await pi(t);
      await choose(h, 'account:anthropic#0');
      await h.tapKey('pi-sign-in-continue');
      fake.event({'kind': 'code_prompt'}, runtime: 'pi');
      await h.settle();
      expect(txt('Paste the code shown after signing in'), findsOneWidget);
      expect(
        txt(
          'After signing in, the page shows a code like abc…#xyz. Paste all of it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Pi: a busy sign-in names Pi', (t) async {
      final (h, fake) = await pi(t);
      await choose(h, 'account:github-copilot#0');
      await h.tapKey('pi-sign-in-continue');
      fake.result({'kind': 'busy'}, runtime: 'pi');
      await h.settle();
      expect(
        txt(
          'Another Pi sign-in is in progress on this Computer, for this or another provider. Finish or cancel it, then try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a device code works for a provider too, and Esc cancels it', (
      t,
    ) async {
      final (h, fake) = await pi(t, size: const Size(1280, 800));
      await choose(h, 'account:github-copilot#0');
      await h.tapKey('pi-sign-in-continue');
      fake.event({
        'kind': 'device_code',
        'userCode': 'WXYZ-9999',
        'verificationUri': 'https://github.com/login/device',
      }, runtime: 'pi');
      await h.settle();
      expect(txt('https://github.com/login/device'), findsOneWidget);
      await h.esc();
      expect(h.dialogOpen, isFalse);
      expect(fake.posted('/login/login-1/cancel'), hasLength(1));
    });
  });

  group('OpenCode names the sign-in it was asked for', () {
    final github = provider(
      'github',
      'GitHub',
      methods: [
        flow('Login with GitHub (device)', 'device_code'),
        flow('Login with GitHub (browser)', 'link'),
      ],
      keyEntry: 'outside',
    );

    testWidgets('one row per method, each by provider and method', (t) async {
      final (_, _) = await pi(
        t,
        runtime: 'opencode',
        providers: listed([github]),
      );
      expect(txt('GitHub · Login with GitHub (device)'), findsOneWidget);
      expect(txt('GitHub · Login with GitHub (browser)'), findsOneWidget);
      expect(txt("Sign in on the provider's page"), findsOneWidget);
      expect(txt('Set up outside OpenCode, on the Computer'), findsOneWidget);
    });

    testWidgets('the chosen method goes with the start', (t) async {
      final (h, fake) = await pi(
        t,
        runtime: 'opencode',
        providers: listed([github]),
      );
      await choose(h, 'account:github#1');
      await h.tapKey('pi-sign-in-continue');
      expect(txt('Sign in to GitHub'), findsOneWidget);
      final (path, body) = fake.posted('/login').single;
      expect(path, endsWith('/runtime-auth/opencode/login'));
      expect(body, {
        'providerId': 'github',
        'oauthMethod': 'Login with GitHub (browser)',
      });
    });

    testWidgets(
      'a method that needs the Computer\'s browser is greyed afterwards',
      (t) async {
        final (h, fake) = await pi(
          t,
          runtime: 'opencode',
          providers: listed([github]),
        );
        await choose(h, 'account:github#1');
        await h.tapKey('pi-sign-in-continue');
        fake.result({
          'kind': 'failed',
          'reason': 'loopback_required',
        }, runtime: 'opencode');
        await h.settle();
        expect(
          txt(
            "This way of signing in to GitHub needs a browser on the Computer itself. Choose another way, or sign in on the Computer.",
          ),
          findsOneWidget,
        );
        // Another way, not a retry.
        expect(
          find.byKey(const ValueKey('runtime-sign-in-retry')),
          findsNothing,
        );
        await h.tapKey('runtime-sign-in-cancel');
        expect(h.dialogOpen, isFalse);
        await h.openPi(runtime: 'opencode', runtimeId: 'opencode');
        final cont = find.byKey(const ValueKey('pi-sign-in-continue'));
        await t.ensureVisible(choice('account:github#1'));
        await t.tap(choice('account:github#1'));
        await h.settle();
        expect(t.widget<RaftButton>(cont).onPressed, isNull);
        expect(
          txt('Needs a browser on the Computer itself: sign in there'),
          findsOneWidget,
        );
        // The other method of the same provider stays available.
        await choose(h, 'account:github#0');
        expect(t.widget<RaftButton>(cont).onPressed, isNotNull);
      },
    );

    testWidgets('a busy sign-in names OpenCode, and one too old says 2.x', (
      t,
    ) async {
      final (h, fake) = await pi(
        t,
        runtime: 'opencode',
        providers: listed([github]),
      );
      await choose(h, 'account:github#0');
      await h.tapKey('pi-sign-in-continue');
      fake.result({'kind': 'busy'}, runtime: 'opencode');
      await h.settle();
      expect(
        txt(
          'Another OpenCode sign-in is in progress on this Computer, for this or another provider. Finish or cancel it, then try again.',
        ),
        findsOneWidget,
      );
      fake.nextLoginId = () => 'login-2';
      await h.tapKey('runtime-sign-in-retry');
      fake.result(
        {'kind': 'unsupported', 'reason': 'version_unsupported'},
        runtime: 'opencode',
        loginId: 'login-2',
      );
      await h.settle();
      expect(
        txt(
          "Upgrade OpenCode on the Computer to 2.x, then use Rescan runtimes on the Computer's page.",
        ),
        findsOneWidget,
      );
    });
  });

  group('saving an API key', () {
    Future<(SignInHarness, FakeAuth)> keyForm(
      WidgetTester t, {
      String runtime = 'pi',
      Size size = const Size(390, 844),
    }) async {
      final (h, fake) = await pi(t, runtime: runtime, size: size);
      await choose(h, 'key:openai');
      await h.tapKey('pi-sign-in-continue');
      return (h, fake);
    }

    Future<void> type(SignInHarness h, String key) async {
      await h.t.enterText(find.byKey(const ValueKey('pi-key-input')), key);
      await h.settle();
    }

    testWidgets('sends exactly the provider and the key, and keeps neither', (
      t,
    ) async {
      final (h, fake) = await keyForm(t);
      fake.onPost = (path, body) async => {'kind': 'connected'};
      var changed = 0;
      final stop = fake.client.watch('m1', () => changed++);
      addTearDown(stop);
      expect(txt('API key · OpenAI'), findsOneWidget);
      expect(txt('Find it in your OpenAI account settings.'), findsOneWidget);
      expect(
        txt(
          'Saved on this Computer for every Pi agent of this account, and for Pi run outside Raft.',
        ),
        findsOneWidget,
      );
      final connect = find.byKey(const ValueKey('pi-key-connect'));
      expect(t.widget<RaftButton>(connect).onPressed, isNull);
      await type(h, '  sk-secret-123  ');
      await h.tapKey('pi-key-connect');
      final (path, body) = fake.posted('/connect-provider').single;
      expect(path, endsWith('/runtime-auth/pi/connect-provider'));
      expect(body, {'providerId': 'openai', 'apiKey': 'sk-secret-123'});
      expect(
        txt(
          'Saved on this Computer. Pi checks the key when an agent uses OpenAI.',
        ),
        findsOneWidget,
      );
      expect(changed, 1);
      // The key is gone from the page.
      expect(find.byKey(const ValueKey('pi-key-input')), findsNothing);
      expect(find.text('sk-secret-123'), findsNothing);
      await h.tapKey('pi-sign-in-done');
      expect(h.dialogOpen, isFalse);
    });

    testWidgets('the key is a password field', (t) async {
      final (h, _) = await keyForm(t);
      await type(h, 'sk-secret');
      final editable = t.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('pi-key-input')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.obscureText, isTrue);
    });

    testWidgets('Enter in the field connects (desktop)', (t) async {
      final (h, fake) = await keyForm(t, size: const Size(1280, 800));
      fake.onPost = (path, body) async => {'kind': 'connected'};
      await type(h, 'sk-enter');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await h.settle();
      expect(fake.posted('/connect-provider'), hasLength(1));
    });

    testWidgets('Pi says at once, and sends nothing, for a key it would run', (
      t,
    ) async {
      final (h, fake) = await keyForm(t);
      final connect = find.byKey(const ValueKey('pi-key-connect'));
      for (final key in ['!rm -rf', r'$HOME', 'k€y']) {
        await type(h, key);
        expect(
          txt(
            r'Pi would run a key that starts with ! or fill in a $ name. Paste the key itself.',
          ),
          findsOneWidget,
          reason: key,
        );
        expect(t.widget<RaftButton>(connect).onPressed, isNull, reason: key);
      }
      await type(h, 'sk-fine');
      expect(t.widget<RaftButton>(connect).onPressed, isNotNull);
      expect(fake.posted('/connect-provider'), isEmpty);
    });

    testWidgets('OpenCode refuses a reference to an env var or a file', (
      t,
    ) async {
      final (h, fake) = await keyForm(t, runtime: 'opencode');
      await type(h, '{env:OPENAI_API_KEY}');
      expect(
        txt(
          "OpenCode can't take this as a key. Paste the key itself, not a reference to an environment variable or a file.",
        ),
        findsOneWidget,
      );
      expect(
        t
            .widget<RaftButton>(find.byKey(const ValueKey('pi-key-connect')))
            .onPressed,
        isNull,
      );
      expect(fake.posted('/connect-provider'), isEmpty);
    });

    testWidgets('each way a save can fail says why, and the key stays', (
      t,
    ) async {
      final (h, fake) = await keyForm(t);
      await type(h, 'sk-keep');
      const answers = <(Object, String)>[
        (
          {'kind': 'failed', 'reason': 'rejected'},
          'OpenAI did not accept these settings. Check the key and try again.',
        ),
        (
          {'kind': 'failed', 'reason': 'timed_out'},
          'OpenAI took too long to answer. The key may or may not be saved: check the card, then try again if needed.',
        ),
        (
          {'kind': 'failed', 'reason': 'process_failed'},
          'OpenAI could not run on this Computer. Try again.',
        ),
        (
          {'kind': 'failed', 'reason': 'relay_failed'},
          "Couldn't reach the Computer. Try again.",
        ),
        (
          {'kind': 'busy'},
          'Another provider is being connected on this Computer. Try again in a moment.',
        ),
        (
          {'kind': 'unsupported', 'reason': 'not_installed'},
          'OpenAI is not installed on this Computer.',
        ),
      ];
      for (final (answer, sentence) in answers) {
        fake.onPost = (path, body) async => answer;
        await h.tapKey('pi-key-connect');
        expect(txt(sentence), findsOneWidget, reason: sentence);
        expect(find.byKey(const ValueKey('pi-key-failed')), findsOneWidget);
      }
      // A refusal that names the key shows under the field, not as a banner.
      fake.onPost = (path, body) async => throw refused(400, 'invalid_api_key');
      await h.tapKey('pi-key-connect');
      expect(txt('Paste the whole API key, with no spaces.'), findsOneWidget);
      expect(find.byKey(const ValueKey('pi-key-failed')), findsNothing);
      // The same key can be sent again once the Computer answers.
      fake.onPost = (path, body) async => {'kind': 'connected'};
      await h.tapKey('pi-key-connect');
      expect(fake.posted('/connect-provider').last.$2, {
        'providerId': 'openai',
        'apiKey': 'sk-keep',
      });
      expect(find.byKey(const ValueKey('pi-key-saved')), findsOneWidget);
    });

    testWidgets('a request the server refused is worded by its status', (
      t,
    ) async {
      final (h, fake) = await keyForm(t);
      await type(h, 'sk-keep');
      const cases = <(int, String?, String)>[
        (
          409,
          'computer_offline',
          'This Computer is offline. Connect it, then try again.',
        ),
        (
          504,
          null,
          'OpenAI took too long to answer. The key may or may not be saved: check the card, then try again if needed.',
        ),
        (
          429,
          null,
          'Too many attempts on this Computer. Try again in a few minutes.',
        ),
        (
          403,
          null,
          'Only the person who connected this Computer, or an owner or admin, can connect its runtimes to a provider.',
        ),
        (500, null, "Couldn't reach the Computer. Try again."),
      ];
      for (final (status, code, sentence) in cases) {
        fake.onPost = (path, body) async => throw refused(status, code);
        await h.tapKey('pi-key-connect');
        expect(txt(sentence), findsOneWidget, reason: sentence);
      }
    });

    testWidgets('OpenCode: a sign-in in progress makes the save busy', (
      t,
    ) async {
      final (h, fake) = await keyForm(t, runtime: 'opencode');
      fake.onPost = (path, body) async => {'kind': 'busy'};
      await type(h, 'sk-keep');
      await h.tapKey('pi-key-connect');
      expect(
        txt(
          'A sign-in is in progress on this Computer. Finish or cancel it, then try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Back drops the key and returns to the list', (t) async {
      final (h, fake) = await keyForm(t);
      await type(h, 'sk-dropped');
      await h.tapKey('pi-sign-in-back');
      expect(find.byKey(const ValueKey('pi-key-input')), findsNothing);
      await choose(h, 'key:openai');
      await h.tapKey('pi-sign-in-continue');
      expect(
        t
            .widget<RaftButton>(find.byKey(const ValueKey('pi-key-connect')))
            .onPressed,
        isNull,
        reason: 'the field starts empty again',
      );
      expect(fake.posted('/connect-provider'), isEmpty);
    });

    testWidgets('closing the dialog sends nothing', (t) async {
      final (h, fake) = await keyForm(t);
      await type(h, 'sk-typed');
      await h.esc();
      expect(h.dialogOpen, isFalse);
      expect(fake.posts, isEmpty);
    });
  });

  testWidgets('phone (Android 390x844): a sheet that Esc closes', (t) async {
    final (h, _) = await pi(t);
    expect(find.byKey(const ValueKey('raft-sheet-handle')), findsOneWidget);
    await h.esc();
    expect(h.dialogOpen, isFalse);
  });

  testWidgets('desktop (Linux): a centered dialog that Cancel closes', (
    t,
  ) async {
    final (h, _) = await pi(t, size: const Size(1280, 800));
    expect(find.byKey(const ValueKey('raft-sheet-handle')), findsNothing);
    await h.tapKey('pi-sign-in-cancel');
    expect(h.dialogOpen, isFalse);
  });
}
