import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_updater/raft_updater.dart';
import 'package:raft_updater/src/appimage/appimage_environment.dart';
import 'package:raft_updater/src/appimage/update_information.dart';

/// A minimal 64-bit little-endian ELF: header, `.upd_info`, `.shstrtab`, then
/// the section header table, the layout of the type-2 runtime (squashfs
/// follows it in a real AppImage).
Uint8List elfWith(String? information, {int infoSize = 1024}) {
  const names = '\u0000.upd_info\u0000.shstrtab\u0000';
  final infoOffset = 64, namesOffset = 64 + infoSize;
  final tableOffset = namesOffset + names.length;
  final out = Uint8List(tableOffset + 3 * 64 + 4096);
  final header = ByteData.sublistView(out);
  out.setAll(0, [0x7f, 0x45, 0x4c, 0x46, 2, 1, 1]);
  header.setUint64(0x28, tableOffset, Endian.little);
  header.setUint16(0x3a, 64, Endian.little);
  header.setUint16(0x3c, 3, Endian.little);
  header.setUint16(0x3e, 2, Endian.little);
  if (information != null) out.setAll(infoOffset, information.codeUnits);
  out.setAll(namesOffset, names.codeUnits);
  void section(int index, int name, int offset, int size) {
    final at = tableOffset + index * 64;
    header.setUint32(at, name, Endian.little);
    header.setUint64(at + 0x18, offset, Endian.little);
    header.setUint64(at + 0x20, size, Endian.little);
  }

  section(1, 1, infoOffset, infoSize);
  section(2, 11, namesOffset, names.length);
  return out;
}

// A throwaway public key (RFC 8032 test vector 1); no release was signed with it.
const publicKey = '11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=';

void main() {
  late Directory directory;
  setUp(
    () => directory = Directory.systemTemp.createTempSync('appimage-support'),
  );
  tearDown(() async {
    await Process.run('chmod', ['0755', directory.path]);
    directory.deleteSync(recursive: true);
  });

  File write(String name, Uint8List bytes) =>
      File('${directory.path}/$name')..writeAsBytesSync(bytes);

  group('update information', () {
    test('parses both transports and refuses everything else', () {
      final github = AppImageUpdateInformation.parse(
        AppImageUpdateInformation.official,
      );
      expect(github, isA<GithubReleasesInformation>());
      github as GithubReleasesInformation;
      expect((github.owner, github.repository), ('kevinzhow', 'raft-flutter'));
      expect(
        github.matches('raft-flutter-0.1.1+3-appimage-x64.AppImage.zsync'),
        isTrue,
      );
      expect(
        github.matches('raft-flutter-0.1.1+3-appimage-x64.AppImage'),
        isFalse,
      );
      expect(github.matches('xraft-flutter-0.1.1-windows-x64.zip'), isFalse);
      expect(
        github.assetUrl('v0.1.1+3', 'a b+c.zsync').toString(),
        'https://github.com/kevinzhow/raft-flutter/releases/download/v0.1.1+3/a%20b+c.zsync',
      );
      expect(
        github
            .assetUrl('v1', 'a', origin: Uri.parse('http://127.0.0.1:9'))
            .toString(),
        'http://127.0.0.1:9/kevinzhow/raft-flutter/releases/download/v1/a',
      );
      final direct = AppImageUpdateInformation.parse(
        'zsync|https://example.com/x/raft.AppImage.zsync',
      );
      expect((direct as DirectZsyncInformation).url.host, 'example.com');
      for (final bad in [
        '',
        'zsync|',
        'zsync|ftp://example.com/x',
        'zsync|https://a/b|c',
        'gh-releases-zsync|a|b|latest',
        'gh-releases-zsync|a|b|v1.0|*.zsync',
        'gh-releases-zsync|a|b|latest-pre|*.zsync',
        'gh-releases-zsync|a/b|c|latest|*.zsync',
        'gh-releases-zsync|a|b|latest|../*.zsync',
        'bittorrent|x',
      ]) {
        expect(AppImageUpdateInformation.parse(bad), isNull, reason: bad);
      }
    });

    test('reads .upd_info from the ELF section table', () {
      final file = write('a', elfWith(AppImageUpdateInformation.official));
      expect(
        readUpdateInformationText(file.path),
        AppImageUpdateInformation.official,
      );
      expect(
        AppImageUpdateInformation.read(file.path),
        isA<GithubReleasesInformation>(),
      );
    });

    test(
      'an empty section, a non-ELF file and a truncated file give nothing',
      () {
        expect(
          readUpdateInformationText(write('empty', elfWith(null)).path),
          isNull,
        );
        expect(
          readUpdateInformationText(
            write('text', Uint8List.fromList('#!/bin/sh\n'.codeUnits)).path,
          ),
          isNull,
        );
        final elf = elfWith(AppImageUpdateInformation.official);
        expect(
          readUpdateInformationText(write('cut', elf.sublist(0, 200)).path),
          isNull,
        );
        expect(readUpdateInformationText('${directory.path}/missing'), isNull);
      },
    );
  });

  group('detection', () {
    Map<String, String> env(File? appImage) => {
      if (appImage != null) 'APPIMAGE': appImage.path,
    };

    test(
      'needs APPIMAGE, a file with update information and a writable folder',
      () {
        expect(AppImageSupport.detect({}).available, isFalse);
        expect(
          AppImageSupport.detect({'APPIMAGE': '${directory.path}/gone'}).reason,
          contains('missing'),
        );
        final bare = write('bare.AppImage', elfWith(null));
        expect(
          AppImageSupport.detect(env(bare)).reason,
          contains('update information'),
        );
        final good = write(
          'good.AppImage',
          elfWith(AppImageUpdateInformation.official),
        );
        final support = AppImageSupport.detect(env(good));
        expect(support.available, isTrue, reason: support.reason);
        expect(support.path, good.resolveSymbolicLinksSync());
        expect(
          directory.listSync().map((e) => e.path.split('/').last),
          isNot(contains(startsWith('.raft-update-probe'))),
        );
      },
    );

    test('resolves a symlink to the real file, whose folder must accept the update', () {
      final real = write(
        'real.AppImage',
        elfWith(AppImageUpdateInformation.official),
      );
      final link = Link('${directory.path}/link.AppImage')
        ..createSync(real.path);
      expect(
        AppImageSupport.detect({'APPIMAGE': link.path}).path,
        real.resolveSymbolicLinksSync(),
      );
    });

    test('a read-only folder is explained', () async {
      final good = write(
        'good.AppImage',
        elfWith(AppImageUpdateInformation.official),
      );
      await Process.run('chmod', ['0555', directory.path]);
      final probe = await Process.run('sh', [
        '-c',
        'touch "${directory.path}/x" 2>/dev/null && rm "${directory.path}/x" && echo writable',
      ]);
      if ('${probe.stdout}'.contains('writable')) return; // running as root
      final support = AppImageSupport.detect(env(good));
      expect(support.available, isFalse);
      expect(support.reason, contains('not writable'));
    });
  });

  group('AppUpdater on Linux', () {
    AppUpdater updater(AppImageSupport Function(Map<String, String>) detect) =>
        AppUpdater(
          platform: TargetPlatform.linux,
          config: AppUpdaterConfig(buildNumber: '5', publicKey: publicKey),
          environment: const {},
          detectAppImage: detect,
          openUrl: (_) async => true,
        );

    test(
      'is unavailable, with the reason, in a build without the update key',
      () {
        final file = write(
          'good.AppImage',
          elfWith(AppImageUpdateInformation.official),
        );
        final u = AppUpdater(
          platform: TargetPlatform.linux,
          config: const AppUpdaterConfig(buildNumber: '5'),
          environment: const {},
          detectAppImage: (_) => AppImageSupport.available(
            file.path,
            AppImageUpdateInformation.parse(AppImageUpdateInformation.official),
          ),
          openUrl: (_) async => true,
        );
        u.configureAppImage(httpClientFactory: (_) async => HttpClient());
        expect(u.available, isFalse);
        expect(u.unavailableReason, contains('signing key'));
        expect(u.appImage, isNull);
      },
    );

    test('is unavailable until the app gives it a network client', () {
      final u = updater((_) => const AppImageSupport.available('/x', null));
      expect(u.available, isFalse);
      expect(u.unavailableReason, contains('network client'));
      expect(u.appImage, isNull);
    });

    test('is unavailable, with the reason, when not running from a usable AppImage', () {
      final u = updater(
        (_) =>
            const AppImageSupport.unavailable('Not running from an AppImage'),
      );
      u.configureAppImage(httpClientFactory: (_) async => HttpClient());
      expect(u.available, isFalse);
      expect(u.unavailableReason, 'Not running from an AppImage');
      expect(u.appImage, isNull);
    });

    test('is available for a usable AppImage and notifies listeners', () {
      final file = write(
        'good.AppImage',
        elfWith(AppImageUpdateInformation.official),
      );
      final u = updater(
        (_) => AppImageSupport.available(
          file.path,
          AppImageUpdateInformation.parse(AppImageUpdateInformation.official),
        ),
      );
      final seen = <bool>[];
      u.availability.addListener(() => seen.add(u.available));
      u.configureAppImage(httpClientFactory: (_) async => HttpClient());
      expect(u.available, isTrue);
      expect(u.appImage, isNotNull);
      expect(u.unavailableReason, isNull);
      expect(seen, [true]);
    });

    test('checkAndInstall still opens the release page: the card drives the install itself', () async {
      final opened = <Uri>[];
      final u = AppUpdater(
        platform: TargetPlatform.linux,
        environment: const {},
        detectAppImage: (_) => const AppImageSupport.unavailable('x'),
        openUrl: (url) async {
          opened.add(url);
          return true;
        },
      );
      expect(await u.checkAndInstall(), AppUpdateOutcome.openedReleasePage);
      expect(opened, [AppUpdater.releasePage]);
    });
  });
}
