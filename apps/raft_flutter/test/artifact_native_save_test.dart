import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/artifact_download_controller.dart';
import 'package:raft_flutter/platform/artifact_download_bridge.dart';
import 'package:raft_flutter/platform/attachment_files.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  for (final committedFirst in [false, true]) {
    test(
      'Android save channel reports the actual ${committedFirst ? 'commit before late cancel' : 'cancel during slow write'} with complete file readback',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'raft-artifact-write-race-',
        );
        final staging = await Directory('${root.path}/staging').create();
        final destination = File('${root.path}/selected.csv');
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final bytes = List<int>.generate(65536, (i) => i % 251);
        server.listen((request) async {
          request.response.add(bytes);
          await request.response.close();
        });
        const uri = 'content://fixture.documents/document/selected';
        const token = 'fixture-only-native-receipt';
        var committed = false,
            cancelled = false,
            discards = 0,
            acknowledgements = 0;
        final writing = Completer<void>(),
            release = Completer<void>(),
            cancellation = Completer<void>();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AttachmentFiles.channel,
          (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            if (call.method == 'chooseSave') {
              expect(args['trackIncomplete'], isTrue);
              await destination.create();
              return {'uri': uri, 'saveToken': token};
            }
            expect(args['uri'], uri);
            expect(args['saveToken'], token);
            switch (call.method) {
              case 'writeSaved':
                final actual = await File(args['path'] as String).readAsBytes();
                expect(
                  actual,
                  bytes,
                  reason: 'the platform writer receives the complete staged response',
                );
                await destination.writeAsBytes(
                  committedFirst ? actual : actual.sublist(0, 1024),
                  flush: true,
                );
                committed = committedFirst;
                writing.complete();
                await release.future; // A real platform result remains pending.
                if (cancelled && !committed) {
                  await destination.delete();
                  return {'committed': false, 'discarded': true};
                }
                committed = true;
                return {'committed': true, 'discarded': false};
              case 'cancelSave':
                cancelled = !committed;
                cancellation.complete();
                return committed ? 'committed' : 'cancelled';
              case 'discardSave':
                discards++;
                expect(
                  committed,
                  isFalse,
                  reason: 'a committed target is never cleanup permission',
                );
                await destination.delete();
                return null;
              case 'acknowledgeSave':
                expect(committed, isTrue);
                acknowledgements++;
                return null;
            }
            throw MissingPluginException();
          },
        );
        final origin = Uri.parse('http://127.0.0.1:${server.port}');
        final controller = ArtifactDownloadController(
          origin: origin,
          files: (dio) => AttachmentFiles(
            dio: dio,
            androidSave: true,
            discardIncompleteDestination: true,
            stagingDirectory: () async => staging,
          ),
        );
        addTearDown(() async {
          if (!release.isCompleted) release.complete();
          controller.dispose();
          await server.close(force: true);
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            AttachmentFiles.channel,
            null,
          );
          await root.delete(recursive: true);
        });
        controller.receive(
          ArtifactDownloadRequest(
            url: origin.resolve('/file').toString(),
            filename: 'report.csv',
            mimeType: 'text/csv',
          ),
        );
        await writing.future.timeout(const Duration(seconds: 5));
        expect(controller.status, ArtifactDownloadStatus.saving);
        expect(
          await destination.length(),
          committedFirst ? bytes.length : 1024,
        );
        controller.cancel();
        expect(controller.status, ArtifactDownloadStatus.cancelling);
        await cancellation.future.timeout(const Duration(seconds: 5));
        release.complete();
        final end = DateTime.now().add(const Duration(seconds: 5));
        while (controller.busy && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(controller.busy, isFalse);
        expect(
          controller.status,
          committedFirst
              ? ArtifactDownloadStatus.saved
              : ArtifactDownloadStatus.cancelled,
        );
        if (committedFirst) {
          expect(await destination.readAsBytes(), bytes);
        } else {
          expect(await destination.exists(), isFalse);
        }
        expect(acknowledgements, committedFirst ? 1 : 0);
        expect(
          discards,
          0,
          reason: 'the native writer settled its own exact receipt; no duplicate or late deletion',
        );
        expect(await staging.list().toList(), isEmpty);
      },
    );
  }
}
