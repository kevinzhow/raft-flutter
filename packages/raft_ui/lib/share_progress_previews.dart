import 'package:flutter/material.dart';

import 'raft_ui.dart';

/// The three ways the incoming-share page can show a copy that is still
/// running (docs/parity.md). Previews and the widget tests render real
/// raft_ui widgets; no API, files or platform channel.
enum RaftShareWaitOption {
  /// A: Continue turns into a progress block (bar, bytes, Cancel).
  button,

  /// B: each file chip carries its own bar / error; Continue keeps A's block.
  card,

  /// C: navigate at once; the composer's attachment chips show the progress.
  composer,
}

/// Where the share is in the preview.
enum RaftShareWaitScenario {
  /// The copy is running; Continue has not been pressed.
  copying,

  /// Continue was pressed before the copy ended.
  continued,

  /// A file cannot be added.
  failed,
}

const _sizes = [2400000, 12900000, 18100000];
const _names = ['IMG_2041.jpg', 'VID_0932.mp4', 'review.pdf'];
const _mimes = ['image/jpeg', 'video/mp4', 'application/pdf'];

/// 2 of 3 files copied is not what the bar shows: 1 done, 1 half-way, 1 queued.
final _progress = [
  ValueNotifier<RaftTransferProgress?>(
    const RaftTransferProgress(received: 2400000, total: 2400000),
  ),
  ValueNotifier<RaftTransferProgress?>(
    const RaftTransferProgress(received: 5200000, total: 12900000),
  ),
  ValueNotifier<RaftTransferProgress?>(null),
];
// ignore: raft_lints/avoid_unreleased_resource -- Preview-only top-level notifier; lives for the process.
final _overall = ValueNotifier<RaftTransferProgress?>(
  const RaftTransferProgress(received: 7600000, total: 33400000),
);

Widget incomingShareWaitPreview({
  RaftShareWaitOption option = RaftShareWaitOption.card,
  RaftShareWaitScenario scenario = RaftShareWaitScenario.continued,
}) => option == RaftShareWaitOption.composer
    ? _ComposerMock(scenario: scenario)
    : _ReviewMock(option: option, scenario: scenario);

class _ReviewMock extends StatelessWidget {
  const _ReviewMock({required this.option, required this.scenario});
  final RaftShareWaitOption option;
  final RaftShareWaitScenario scenario;
  @override
  Widget build(BuildContext context) {
    final failed = scenario == RaftShareWaitScenario.failed;
    final continued = scenario == RaftShareWaitScenario.continued;
    final chips = option == RaftShareWaitOption.card;
    RaftForwardShareFileState state(int i) {
      if (failed) {
        return i == 2
            ? RaftForwardShareFileState.failed
            : RaftForwardShareFileState.ready;
      }
      if (!chips) return RaftForwardShareFileState.ready;
      return switch (i) {
        0 => RaftForwardShareFileState.ready,
        1 => RaftForwardShareFileState.copying,
        _ => RaftForwardShareFileState.waiting,
      };
    }

    return RaftForwardPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftForwardPageHeader(
            leading: RaftForwardIconAction(
              glyph: RaftGlyph.arrowLeft,
              tooltip: 'Back',
              onPressed: () {},
            ),
            title: 'Add shared content',
            subtitle: 'Add to #design',
          ),
          Expanded(
            child: RaftForwardPreviewStep(
              previewLabel: 'Shared content',
              error: failed
                  ? 'review.pdf is larger than 25 MB and cannot be added.'
                  : null,
              preview: RaftForwardSharePreview(
                header: 'Shared',
                count: '3 files',
                files: [
                  for (var i = 0; i < 3; i++)
                    RaftForwardShareFile(
                      filename: _names[i],
                      mimeType: _mimes[i],
                      sizeBytes: failed && i == 2 ? 31000000 : _sizes[i],
                      state: state(i),
                      transfer: _progress[i],
                      error: failed && i == 2 ? 'Larger than 25 MB' : null,
                    ),
                ],
              ),
              hint: 'Files are added to the composer. Review them before sending.',
              action: RaftForwardContinueAction(
                label: 'Continue',
                busy: continued,
                busyLabel: 'Preparing files',
                onPressed: failed || continued ? null : () {},
                wait: continued
                    ? RaftForwardWait(
                        label: 'Preparing 1 of 3 files',
                        progress: _overall,
                        onCancel: () {},
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Option C: the channel with the composer open and the shared files already
/// staged as chips whose bars fill as the copy finishes.
class _ComposerMock extends StatelessWidget {
  const _ComposerMock({required this.scenario});
  final RaftShareWaitScenario scenario;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final failed = scenario == RaftShareWaitScenario.failed;
    final items = [
      for (var i = 0; i < 3; i++)
        RaftComposerAttachment(
          id: _names[i],
          name: _names[i],
          mimeType: _mimes[i],
          status: switch ((failed, i)) {
            (true, 2) => RaftComposerAttachmentStatus.failed,
            (_, 0) => RaftComposerAttachmentStatus.ready,
            _ => RaftComposerAttachmentStatus.uploading,
          },
          progress: i == 1 ? 40 : 0,
          error: failed && i == 2 ? 'Larger than 25 MB' : null,
          canRetry: false,
        ),
    ];
    return ColoredBox(
      color: t.canvas,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  RaftIcon(RaftGlyph.arrowLeft, size: 20, color: t.strong),
                  const SizedBox(width: 12),
                  Text(
                    '# design',
                    style: RaftTypography.body(
                      t,
                      size: 18,
                      line: 24,
                      weight: FontWeight.w700,
                      color: t.strong,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          RaftComposer(
            onSend: (_) async => false,
            hint: 'Message #design',
            // Send waits until every file is in the app.
            canSend: false,
            hasAttachments: true,
            attachments: RaftComposerAttachments(
              items: items,
              onRemove: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
