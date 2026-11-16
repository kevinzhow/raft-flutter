// WP-COMP1 R17 (Web v1.24 ComputerOwnerField / TransferComputerOwnerDialog):
// the Computer page's Owner row, Transfer owner and Make it mine.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mobile_computer_navigation_test.dart' show computer, fixture;

const _bob = {
  'id': 'bob',
  'name': 'bob',
  'displayName': 'Bob Builder',
  'avatarUrl': null,
};

class _Owner {
  _Owner({
    String? ownerUserId,
    Map<String, dynamic>? owner,
    Map<String, dynamic> extra = const {},
    String role = 'owner',
  }) {
    machine = {
      ...computer,
      'ownerUserId': ?ownerUserId,
      'owner': ?owner,
      ...extra,
    };
    f.servers[0]['role'] = role;
    f.overrides['GET /servers/a/machines'] = (_) => {
      'machines': [machine],
    };
    f.overrides['GET /servers/a/members'] = (_) => [
      {
        'userId': 'alice',
        'name': 'alice',
        'displayName': 'Alice',
        'role': 'owner',
      },
      {
        'userId': 'bob',
        'name': 'bob',
        'displayName': 'Bob Builder',
        'role': 'member',
      },
      {
        'userId': 'carol',
        'name': 'carol',
        'displayName': 'Carol Guest',
        'role': 'guest',
      },
      {
        'userId': 'dave',
        'name': 'dave',
        'displayName': 'Dave Dev',
        'role': 'admin',
      },
    ];
    f.overrides['PUT /servers/a/machines/computer-a/owner'] = (o) {
      puts.add(Map<String, dynamic>.from(o.data as Map));
      if (failPut) {
        f.adapter.statuses['PUT /servers/a/machines/computer-a/owner'] = 500;
        return {'error': 'nope'};
      }
      f.adapter.statuses.remove('PUT /servers/a/machines/computer-a/owner');
      final next = putAnswer?.call(o.data as Map);
      return next ?? <String, dynamic>{};
    };
  }

  final f = fixture();
  late Map<String, dynamic> machine;
  final puts = <Map<String, dynamic>>[];
  bool failPut = false;
  Map<String, dynamic>? Function(Map body)? putAnswer;

  Future<void> open(WidgetTester t, {double width = 390}) async {
    await f.mount(
      t,
      'light',
      width,
      uri: Uri.parse('/s/alpha/computer/computer-a'),
    );
    addTearDown(() => f.close(t));
    await f.flush(t);
  }

  Finder get ownerLink => find.byKey(const ValueKey('computer-owner'));
  Finder get publicText => find.byKey(const ValueKey('computer-owner-public'));
  Finder get transfer => find.byKey(const ValueKey('computer-owner-transfer'));
  Finder get makeMine => find.byKey(const ValueKey('computer-owner-make-mine'));
  Finder get dialog =>
      find.byKey(const ValueKey('transfer-computer-owner-dialog'));
  Finder inDialog(Finder child) => find.descendant(of: dialog, matching: child);

  Future<void> see(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    await t.pump();
  }

  Future<void> openDialog(WidgetTester t) async {
    await see(t, transfer);
    await t.tap(transfer);
    await f.flush(t);
    expect(dialog, findsOneWidget);
  }

  Future<void> pickPerson(WidgetTester t, String label) async {
    await t.tap(inDialog(find.byKey(const ValueKey('transfer-owner-person'))));
    await t.pumpAndSettle();
    await t.tap(find.text(label).last);
    await t.pumpAndSettle();
  }
}

void main() {
  testWidgets('shows the owner with name, handle and avatar slot', (t) async {
    final h = _Owner(ownerUserId: 'bob', owner: _bob);
    await h.open(t);
    await h.see(t, h.ownerLink);
    expect(h.publicText, findsNothing);
    expect(
      find.descendant(of: h.ownerLink, matching: find.text('Bob Builder')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: h.ownerLink, matching: find.text('@bob')),
      findsOneWidget,
    );
    expect(find.text('Owner'), findsWidgets);
  });

  testWidgets('shows Public (no owner) when there is none', (t) async {
    final h = _Owner();
    await h.open(t);
    await h.see(t, h.publicText);
    expect(h.ownerLink, findsNothing);
    expect(find.text('Public (no owner)'), findsOneWidget);
  });

  testWidgets('tapping the owner opens their human profile', (t) async {
    final h = _Owner(ownerUserId: 'bob', owner: _bob);
    await h.open(t);
    await h.see(t, h.ownerLink);
    await t.tap(h.ownerLink);
    await h.f.flush(t);
    final profile = h.f.workspace(t).location.profile;
    expect(profile?.kind, RaftProfileKind.human);
    expect(profile?.id, 'bob');
  });

  group('Transfer owner is for server admins and the owner', () {
    testWidgets('editMachines (a server admin), not the owner', (t) async {
      final h = _Owner(ownerUserId: 'bob', owner: _bob, role: 'admin');
      await h.open(t);
      await h.see(t, h.ownerLink);
      expect(h.transfer, findsOneWidget);
    });

    testWidgets('the owner, a plain member', (t) async {
      final h = _Owner(
        ownerUserId: 'alice',
        owner: {..._bob, 'id': 'alice', 'name': 'alice'},
        role: 'member',
      );
      await h.open(t);
      await h.see(t, h.ownerLink);
      expect(h.transfer, findsOneWidget);
    });

    testWidgets('neither: a member who is not the owner', (t) async {
      final h = _Owner(ownerUserId: 'bob', owner: _bob, role: 'member');
      await h.open(t);
      await h.see(t, h.ownerLink);
      expect(h.transfer, findsNothing);
      expect(h.makeMine, findsNothing);
    });
  });

  group('Make it mine', () {
    testWidgets('shown to the connector of a Public Computer, PUTs me', (
      t,
    ) async {
      final h = _Owner(
        extra: {'computerAttachedByCurrentUser': true},
        role: 'member',
      );
      await h.open(t);
      await h.see(t, h.makeMine);
      expect(h.transfer, findsNothing);
      h.putAnswer = (body) => {
        'machine': {
          ...h.machine,
          'ownerUserId': 'alice',
          'owner': {'id': 'alice', 'name': 'alice', 'displayName': 'Alice'},
        },
      };
      await t.tap(h.makeMine);
      await h.f.flush(t);
      expect(h.puts, [
        {'ownerUserId': 'alice'},
      ]);
      // The field now shows me as the owner and the claim is gone.
      await h.see(t, h.ownerLink);
      expect(
        find.descendant(of: h.ownerLink, matching: find.text('Alice')),
        findsOneWidget,
      );
      expect(h.makeMine, findsNothing);
    });

    testWidgets('not shown when the Computer already has an owner', (t) async {
      final h = _Owner(
        ownerUserId: 'bob',
        owner: _bob,
        extra: {'computerAttachedByCurrentUser': true},
        role: 'member',
      );
      await h.open(t);
      await h.see(t, h.ownerLink);
      expect(h.makeMine, findsNothing);
    });

    testWidgets('not shown to someone who did not connect it', (t) async {
      final h = _Owner(role: 'member', extra: {'userId': 'bob'});
      await h.open(t);
      await h.see(t, h.publicText);
      expect(h.makeMine, findsNothing);
    });

    testWidgets('a raw daemon row: the registrant (userId) may claim', (
      t,
    ) async {
      final h = _Owner(
        role: 'member',
        extra: {'isComputer': false, 'userId': 'alice'},
      );
      await h.open(t);
      await h.see(t, h.makeMine);
    });

    testWidgets('a failure toasts and the button stays', (t) async {
      final h = _Owner(
        extra: {'computerAttachedByCurrentUser': true},
        role: 'member',
      )..failPut = true;
      await h.open(t);
      await h.see(t, h.makeMine);
      await t.tap(h.makeMine);
      await h.f.flush(t);
      expect(h.puts, [
        {'ownerUserId': 'alice'},
      ]);
      expect(
        find.text('Couldn’t make this computer yours. Try again.'),
        findsOneWidget,
      );
      expect(h.makeMine, findsOneWidget);
      expect(h.publicText, findsOneWidget);
    });
  });

  group('Transfer owner dialog', () {
    for (final width in [390.0, 856.0]) {
      testWidgets('a person is picked and saved at $width', (t) async {
        final h = _Owner(
          ownerUserId: 'alice',
          owner: {
            ..._bob,
            'id': 'alice',
            'name': 'alice',
            'displayName': 'Alice',
          },
        );
        h.putAnswer = (body) => {
          'machine': {
            ...h.machine,
            'ownerUserId': body['ownerUserId'],
            'owner': _bob,
          },
        };
        await h.open(t, width: width);
        await h.openDialog(t);
        expect(
          find.text(
            'Raft records one person as the owner of Build Computer. Choose who, or make it Public with no owner.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('transfer-owner-credentials')),
          findsOneWidget,
        );
        // Confirm waits for a person.
        final confirm = h.inDialog(find.widgetWithText(RaftButton, 'Transfer'));
        expect(t.widget<RaftButton>(confirm).onPressed, isNull);
        await h.pickPerson(t, 'Bob Builder');
        expect(t.widget<RaftButton>(confirm).onPressed, isNotNull);
        await t.tap(confirm);
        await h.f.flush(t);
        expect(h.puts, [
          {'ownerUserId': 'bob'},
        ]);
        expect(h.dialog, findsNothing);
        await h.see(t, h.ownerLink);
        expect(
          find.descendant(of: h.ownerLink, matching: find.text('Bob Builder')),
          findsOneWidget,
        );
      });
    }

    testWidgets(
      'only non-guest members who are not the owner are offered; me reads (you)',
      (t) async {
        final h = _Owner(ownerUserId: 'bob', owner: _bob);
        await h.open(t);
        await h.openDialog(t);
        await t.tap(
          h.inDialog(find.byKey(const ValueKey('transfer-owner-person'))),
        );
        await t.pumpAndSettle();
        expect(find.text('Alice (you)'), findsOneWidget);
        expect(find.text('Dave Dev'), findsOneWidget);
        expect(find.text('Carol Guest'), findsNothing);
        // Bob is the owner: only the page's Owner row names him, not the list.
        expect(find.text('Bob Builder'), findsOneWidget);
      },
    );

    testWidgets('Public: PUT {ownerUserId: null}', (t) async {
      final h = _Owner(ownerUserId: 'bob', owner: _bob);
      h.putAnswer = (body) => {
        'machine': {...h.machine, 'ownerUserId': null, 'owner': null},
      };
      await h.open(t);
      await h.openDialog(t);
      await t.tap(
        h.inDialog(find.byKey(const ValueKey('transfer-owner-choice-public'))),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('transfer-owner-person')), findsNothing);
      final confirm = h.inDialog(
        find.widgetWithText(RaftButton, 'Make public'),
      );
      await t.tap(confirm);
      await h.f.flush(t);
      expect(h.puts, [
        {'ownerUserId': null},
      ]);
      expect(h.dialog, findsNothing);
      await h.see(t, h.publicText);
    });

    testWidgets('Public is disabled when the Computer is already Public', (
      t,
    ) async {
      final h = _Owner(role: 'owner');
      await h.open(t);
      await h.openDialog(t);
      final choice = find.byKey(const ValueKey('transfer-owner-choice-public'));
      expect(
        t.widget<RaftRadioGroupItem<String>>(h.inDialog(choice)).enabled,
        isFalse,
      );
      await t.tap(h.inDialog(choice));
      await t.pumpAndSettle();
      // Still choosing a person: the person field stays.
      expect(
        find.byKey(const ValueKey('transfer-owner-person')),
        findsOneWidget,
      );
    });

    testWidgets('a failure shows a banner, keeps the dialog and the choice', (
      t,
    ) async {
      final h = _Owner(ownerUserId: 'bob', owner: _bob)..failPut = true;
      await h.open(t);
      await h.openDialog(t);
      await h.pickPerson(t, 'Dave Dev');
      await t.tap(h.inDialog(find.widgetWithText(RaftButton, 'Transfer')));
      await h.f.flush(t);
      expect(h.puts, [
        {'ownerUserId': 'dave'},
      ]);
      expect(h.dialog, findsOneWidget);
      expect(
        find.byKey(const ValueKey('transfer-owner-failed')),
        findsOneWidget,
      );
      expect(find.text('The owner wasn’t changed. Try again.'), findsOneWidget);
      expect(find.text('Dave Dev'), findsWidgets);
    });

    testWidgets('cannot be closed while saving', (t) async {
      final h = _Owner(ownerUserId: 'bob', owner: _bob);
      final gate = Completer<void>();
      h.f.overrides['PUT /servers/a/machines/computer-a/owner'] = (o) async {
        h.puts.add(Map<String, dynamic>.from(o.data as Map));
        await gate.future;
        return <String, dynamic>{};
      };
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await h.open(t);
      await h.openDialog(t);
      await h.pickPerson(t, 'Dave Dev');
      await t.tap(h.inDialog(find.widgetWithText(RaftButton, 'Transfer')));
      await t.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(h.dialog, findsOneWidget);
      await t.tapAt(const Offset(4, 4));
      await t.pump();
      expect(h.dialog, findsOneWidget);
      expect(await t.binding.handlePopRoute(), isTrue);
      await t.pump();
      expect(h.dialog, findsOneWidget);
      gate.complete();
      await h.f.flush(t);
      expect(h.dialog, findsNothing);
    });

    testWidgets('the close X (Cancel) closes without a request', (t) async {
      final h = _Owner(ownerUserId: 'bob', owner: _bob);
      await h.open(t);
      await h.openDialog(t);
      // 390 wide: the NarrowDialog sheet head, where the X is Cancel.
      await t.tap(h.inDialog(find.byType(RaftCloseButton)));
      await h.f.flush(t);
      expect(h.dialog, findsNothing);
      expect(h.puts, isEmpty);
    });
  });
}
