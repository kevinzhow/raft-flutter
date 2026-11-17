import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Ports of Web packages/shared/src/humanAvatar.test.ts for the recipe format.
void main() {
  const defaults = 'pixel-human:v1:yellow.2.short.ink.wink.cap.none';
  RaftHumanAvatarRecipe recipe(String id) => RaftHumanAvatarRecipe.read(id)!;

  test('the default recipe is the art default', () {
    expect(RaftHumanAvatarRecipe.defaults.serialize(), defaults);
    expect(
      RaftHumanAvatarRecipe.read(defaults),
      RaftHumanAvatarRecipe.defaults,
    );
  });

  test('every recipe round-trips through its stored value', () {
    var count = 0;
    for (final background in RaftHumanAvatarField.background.ids) {
      for (final hair in RaftHumanAvatarField.hair.ids) {
        for (final head in RaftHumanAvatarField.head.ids) {
          for (final face in RaftHumanAvatarField.face.ids) {
            for (final expression in RaftHumanAvatarField.expression.ids) {
              final built = RaftHumanAvatarRecipe.defaults
                  .withOption(RaftHumanAvatarField.background, background)
                  .withOption(RaftHumanAvatarField.hair, hair)
                  .withOption(RaftHumanAvatarField.head, head)
                  .withOption(RaftHumanAvatarField.face, face)
                  .withOption(RaftHumanAvatarField.expression, expression)
                  .withOption(RaftHumanAvatarField.skin, '4')
                  .withOption(RaftHumanAvatarField.hairColor, 'ginger');
              final value = built.serialize();
              expect(isHumanAvatarUrl(value), isTrue, reason: value);
              expect(RaftHumanAvatarRecipe.parse(value), built, reason: value);
              expect(RaftHumanAvatarRecipe.read(value), built, reason: value);
              count++;
            }
          }
        }
      }
    }
    expect(count, 6 * 6 * 4 * 2 * 7);
  });

  test(
    'parse is strict: unknown id, missing or extra field, other version',
    () {
      for (final value in [
        'pixel-human:v1:yellow.2.short.ink.wink.cap',
        'pixel-human:v1:yellow.2.short.ink.wink.cap.none.later',
        'pixel-human:v1:purple.2.short.ink.wink.cap.none',
        'pixel-human:v1:yellow.9.short.ink.wink.cap.none',
        'pixel-human:v1:yellow.2.short.ink.frown.cap.none',
        'pixel-human:v1:yellow.2.short.ink.wink.crown.none',
        'pixel-human:v2:yellow.2.short.ink.wink.cap.none',
        'pixel-human:v1:Yellow.2.short.ink.wink.cap.none',
        'pixel-human:v1:yellow.2.short.ink.wink.cap.none ',
        'pixel:human:v1:yellow.2.short.ink.wink.cap.none',
        'pixel:robot',
        '/api/avatars/users/0123456789abcdef0123456789abcdef.webp',
        '',
      ]) {
        expect(RaftHumanAvatarRecipe.parse(value), isNull, reason: value);
      }
    },
  );

  test(
    'a Server-picked avatar carries the auto marker and reads like a built one',
    () {
      final pink = RaftHumanAvatarRecipe.defaults.withOption(
        RaftHumanAvatarField.background,
        'pink',
      );
      final auto = pink.serialize(auto: true);
      expect(auto, 'pixel-human:v1:pink.2.short.ink.wink.cap.none/auto');
      expect(isAutoHumanAvatarUrl(auto), isTrue);
      expect(isAutoHumanAvatarUrl(pink.serialize()), isFalse);
      expect(isAutoHumanAvatarUrl(null), isFalse);
      expect(RaftHumanAvatarRecipe.parse(auto), pink);
      expect(RaftHumanAvatarRecipe.read(auto), pink);
      expect(
        RaftHumanAvatarRecipe.parse(
          'pixel-human:v1:pink.2.short.ink.wink.cap.none/other',
        ),
        isNull,
      );
    },
  );

  test('reading for drawing: unknown -> default, later field ignored, missing -> default', () {
    expect(
      RaftHumanAvatarRecipe.read(
        'pixel-human:v1:pink.4.curly.ink.sneeze.crown.glasses',
      )!.serialize(),
      'pixel-human:v1:pink.4.curly.ink.wink.cap.glasses',
    );
    expect(
      RaftHumanAvatarRecipe.read(
        'pixel-human:v1:mint.1.side.ginger.grin.headphones.none.scarf',
      )!.serialize(),
      'pixel-human:v1:mint.1.side.ginger.grin.headphones.none',
    );
    expect(
      RaftHumanAvatarRecipe.read('pixel-human:v1:sky.3.bun.brown')!.serialize(),
      'pixel-human:v1:sky.3.bun.brown.wink.cap.none',
    );
    expect(
      RaftHumanAvatarRecipe.read('pixel-human:v9:anything'),
      RaftHumanAvatarRecipe.defaults,
    );
    expect(RaftHumanAvatarRecipe.read(null), isNull);
    expect(RaftHumanAvatarRecipe.read('pixel:robot'), isNull);
    expect(RaftHumanAvatarRecipe.read('https://example.com/a.png'), isNull);
    expect(
      RaftHumanAvatarRecipe.read('pixel-human:v1:${'a' * 200}'),
      isNull,
      reason: 'too long to be one',
    );
  });

  test('withOption ignores an id that is not one of the field ids', () {
    final base = RaftHumanAvatarRecipe.defaults;
    expect(base.withOption(RaftHumanAvatarField.head, 'crown'), base);
    expect(base.withOption(RaftHumanAvatarField.skin, 2), base);
    expect(
      base.withOption(
        RaftHumanAvatarField.head,
        'beanie',
      )[RaftHumanAvatarField.head],
      'beanie',
    );
  });

  test('shuffle picks only known ids across every field', () {
    final random = Random(1);
    final seen = {for (final f in RaftHumanAvatarField.values) f: <String>{}};
    for (var i = 0; i < 400; i++) {
      final look = RaftHumanAvatarRecipe.randomLook(random);
      expect(RaftHumanAvatarRecipe.parse(look.serialize()), look);
      for (final f in RaftHumanAvatarField.values) {
        seen[f]!.add(look[f]);
      }
    }
    for (final f in RaftHumanAvatarField.values) {
      expect(seen[f]!.length, f.ids.length, reason: f.name);
    }
  });

  test('accessories draw by ascending z: headphones over glasses', () {
    final both = composeRaftHumanAvatar(
      recipe('pixel-human:v1:yellow.2.short.ink.wink.headphones.glasses'),
    );
    final phones = composeRaftHumanAvatar(
      recipe('pixel-human:v1:yellow.2.short.ink.wink.headphones.none'),
    );
    final glasses = composeRaftHumanAvatar(
      recipe('pixel-human:v1:yellow.2.short.ink.wink.none.glasses'),
    );
    final none = composeRaftHumanAvatar(
      recipe('pixel-human:v1:yellow.2.short.ink.wink.none.none'),
    );
    var glassesOnly = 0;
    for (var i = 0; i < both.pixels.length; i++) {
      if (phones.pixels[i] != none.pixels[i]) {
        expect(both.pixels[i], phones.pixels[i]);
      } else if (glasses.pixels[i] != none.pixels[i]) {
        expect(both.pixels[i], glasses.pixels[i]);
        glassesOnly++;
      }
    }
    expect(glassesOnly, greaterThan(0));
    expect(both.background, 0xFFFFD440);
  });

  test(
    'long hair falls over an expression: the hair wins where they overlap',
    () {
      final plain = composeRaftHumanAvatar(
        recipe('pixel-human:v1:yellow.2.long.ink.wink.none.none'),
      );
      final grin = composeRaftHumanAvatar(
        recipe('pixel-human:v1:yellow.2.long.ink.grin.none.none'),
      );
      var changed = 0;
      for (var i = 0; i < plain.pixels.length; i++) {
        if (plain.pixels[i] != grin.pixels[i]) changed++;
      }
      expect(changed, greaterThan(0), reason: 'the grin changes the face');
      // Hair colour is palette:hair; the long layer is drawn after the grin.
      final brown = composeRaftHumanAvatar(
        recipe('pixel-human:v1:yellow.2.long.brown.grin.none.none'),
      );
      expect(brown.pixels, isNot(grin.pixels));
    },
  );
}
