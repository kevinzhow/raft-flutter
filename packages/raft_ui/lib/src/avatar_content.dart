import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'avatar_pixel_data.dart';
import 'avatar_image_cache.dart';
import 'human_avatar_recipe.dart' show isHumanAvatarUrl;
import 'human_pixel_avatar.dart';
import 'icons.dart';
import 'sized_image.dart';

/// Image/artwork only. The product retains its authorized identity projection,
/// origin resolution, semantic identity label, and theme-specific avatar frame.
enum RaftAvatarContentKind { human, agent, server, app }

class RaftAvatarContent extends StatelessWidget {
  const RaftAvatarContent({
    super.key,
    required this.name,
    this.kind = RaftAvatarContentKind.human,
    this.uploadedUrl,
    this.gravatarUrl,
    this.pixelKey,
    this.fallback,
    this.imageProviderBuilder,
  });
  final String name;
  final RaftAvatarContentKind kind;

  /// Authorized adapter-resolved public URL; never an attachment capability.
  final String? uploadedUrl, gravatarUrl;

  /// An agent's parsed source pixel key, e.g. robot or random:seed (no pixel:
  /// prefix). For a person, their built avatar's stored value
  /// (`pixel-human:v1:...`), drawn from its recipe (Web PersonAvatar).
  final String? pixelKey;
  final Widget? fallback;

  /// Optional controlled provider for deterministic decode/error tests.
  /// Production defaults to [RaftAvatarImageProvider] (public, no authentication headers).
  final ImageProvider<Object> Function(String url)? imageProviderBuilder;

  static bool isUploadedHumanAvatar(String? url) {
    if (url == null) return false;
    final parsed = Uri.tryParse(url);
    return parsed != null &&
        RegExp(
          r'^/(?:api/)?avatars/users/[0-9a-f]+\.webp$',
          caseSensitive: false,
        ).hasMatch(parsed.path);
  }

  static bool _publicUrl(String? url) {
    final parsed = url == null ? null : Uri.tryParse(url);
    return parsed != null &&
        parsed.userInfo.isEmpty &&
        ['http', 'https'].contains(parsed.scheme) &&
        parsed.host.isNotEmpty;
  }

  Widget _image(String url, Widget placeholder, Widget Function() failure) =>
      RaftSizedImage(
        key: ValueKey('avatar-content-image-$url'),
        // Decodes at the slot's extent x devicePixelRatio, not the upload size.
        image: imageProviderBuilder?.call(url) ?? RaftAvatarImageProvider(url),
        avatar: true,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // Keep the previous frame while a replacement resolves; decoded
        // images come from the shared ImageCache on remount.
        gaplessPlayback: true,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, loadedSynchronously) =>
            frame == null ? placeholder : child,
        errorBuilder: (context, error, stack) => failure(),
      );

  @override
  Widget build(BuildContext context) {
    final empty =
        fallback ??
        Center(
          child: switch (kind) {
            RaftAvatarContentKind.human => const RaftIcon(
              RaftGlyph.user,
              size: 16,
            ),
            RaftAvatarContentKind.agent => const SizedBox.shrink(),
            RaftAvatarContentKind.server || RaftAvatarContentKind.app => Text(
              name.trim().isEmpty
                  ? (kind == RaftAvatarContentKind.server ? 'S' : 'A')
                  : name
                        .trim()
                        .characters
                        .take(kind == RaftAvatarContentKind.server ? 1 : 2)
                        .toString()
                        .toUpperCase(),
            ),
          },
        );
    if (kind == RaftAvatarContentKind.agent) {
      final pixel = RaftPixelAvatar(
        avatarKey: pixelKey ?? raftDefaultPixelAvatarKey,
      );
      // `pixel:ottie` is every personal assistant's avatar: the otter art, with
      // the sprite as the fallback (AgentAvatar in PixelAvatar.tsx).
      if (pixelKey == raftOttieAvatarKey) {
        return RaftSizedImage(
          // ignore: raft_lints/avoid_raw_image_decode -- Bundled brand art handed straight to RaftSizedImage, so it decodes at the display size.
          image: const AssetImage('assets/otter/wave.webp', package: 'raft_ui'),
          avatar: true,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stack) => pixel,
        );
      }
      return _publicUrl(uploadedUrl)
          ? _image(uploadedUrl!, pixel, () => pixel)
          : pixel;
    }
    if (kind != RaftAvatarContentKind.human) {
      return _publicUrl(uploadedUrl)
          ? _image(uploadedUrl!, empty, () => empty)
          : empty;
    }
    // A person's stored photo, else the avatar they built, else the User
    // placeholder (a photo that fails to load is the placeholder too).
    final built = pixelKey;
    final person = isHumanAvatarUrl(built)
        ? RaftHumanPixelAvatar(avatarUrl: built!, fallback: empty)
        : empty;
    Widget gravatar() => _publicUrl(gravatarUrl)
        ? _image(gravatarUrl!, person, () => person)
        : person;
    return _publicUrl(uploadedUrl) && isUploadedHumanAvatar(uploadedUrl)
        ? _image(uploadedUrl!, person, gravatar)
        : gravatar();
  }
}

/// Source eight-by-eight artwork. A key this build does not know (an avatar
/// added after it shipped) draws the default avatar rather than nothing.
class RaftPixelAvatar extends StatelessWidget {
  const RaftPixelAvatar({super.key, required this.avatarKey});
  final String avatarKey;
  @override
  Widget build(BuildContext context) {
    final data = raftPixelAvatarData(avatarKey);
    return CustomPaint(
      painter: _PixelPainter(data),
      child: const SizedBox.expand(),
    );
  }
}

class _PixelPainter extends CustomPainter {
  const _PixelPainter(this.data);
  final RaftPixelAvatarData data;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    paint.color = raftPixelAvatarColor(data.background);
    canvas.drawRect(Offset.zero & size, paint);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final key = data.rows[y][x];
        if (key == '_') continue;
        paint.color = raftPixelAvatarColor(raftPixelAvatarPalette[key]!);
        canvas.drawRect(
          Rect.fromLTRB(
            x * size.width / 8,
            y * size.height / 8,
            (x + 1) * size.width / 8,
            (y + 1) * size.height / 8,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) =>
      old.data.background != data.background ||
      !listEquals(old.data.rows, data.rows);
}
