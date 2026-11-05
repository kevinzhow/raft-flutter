import 'dart:async';

import 'package:flutter/widgets.dart';

import 'html_region_hint_raster.dart';
import 'html_region_native_types.dart';

int _nextGeneration = 0;

/// The SDK owns native input generations and canonical frame publication.
/// Platform adapters remain paint/input transports, without comment state.
class RaftHtmlNativeRegionBinding {
  RaftHtmlNativeRegionBinding(this.onInput, this.onRetire);
  final ValueChanged<RaftHtmlNativeRegionInput> onInput;
  final VoidCallback onRetire;
  RaftHtmlNativeRegionController? _owner;
  StreamSubscription<RaftHtmlNativeRegionInput>? _subscription;
  int _generation = ++_nextGeneration, _outputSequence = 0, _inputSequence = 0;
  int _hintRevision = 0;
  bool _disposed = false,
      _captureEnabled = false,
      _scheduled = false,
      _rasterizing = false;
  Size _viewport = Size.zero;
  Object? _hintSignature, _pendingHintSignature;
  RaftHtmlNativeRegionHint? _hint;
  List<RaftHtmlNativeRegionMarker> _markers = const [];
  GlobalKey? _hintKey, _paneKey;

  void bind(Object? controller) {
    final owner = controller is RaftHtmlNativeRegionController
        ? controller
        : null;
    if (identical(_owner, owner)) return;
    invalidate();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _owner = owner;
    if (owner != null) {
      _subscription = owner.nativeRegionInputs.listen(
        (event) {
          if (_disposed ||
              !identical(owner, _owner) ||
              !_captureEnabled ||
              event.generation != _generation ||
              event.sequence <= _inputSequence ||
              event.viewport != _viewport ||
              !valid(event))
            return;
          _inputSequence = event.sequence;
          onInput(event);
        },
        onError: (Object error, StackTrace stack) {
          invalidate();
        },
      );
    }
  }

  bool valid(RaftHtmlNativeRegionInput event) =>
      event.sequence > 0 &&
      event.position.dx.isFinite &&
      event.position.dy.isFinite &&
      event.position.dx >= 0 &&
      event.position.dx <= 1 &&
      event.position.dy >= 0 &&
      event.position.dy <= 1 &&
      event.delta.dx.isFinite &&
      event.delta.dy.isFinite &&
      event.delta.dx.abs() <= 1024 &&
      event.delta.dy.abs() <= 1024;

  void invalidate() {
    onRetire();
    _generation = ++_nextGeneration;
    _outputSequence = _inputSequence = 0;
    _hintRevision++;
    _captureEnabled = false;
    _hintSignature = null;
    _hint = null;
    _markers = const [];
    publish();
  }

  void update({
    required Size viewport,
    required bool captureEnabled,
    required List<RaftHtmlNativeRegionMarker> markers,
    required GlobalKey paneKey,
    required GlobalKey hintKey,
    required Object hintSignature,
  }) {
    if (_disposed || _owner == null) return;
    if (_viewport != viewport || _captureEnabled != captureEnabled)
      invalidate();
    _viewport = viewport;
    _captureEnabled = captureEnabled;
    _markers = markers;
    _paneKey = paneKey;
    _hintKey = hintKey;
    if (_pendingHintSignature != hintSignature) {
      _hintRevision++;
      _hint = null;
    }
    _pendingHintSignature = hintSignature;
    if (!captureEnabled) {
      _hint = null;
      _hintSignature = null;
      _hintRevision++;
    }
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || _owner == null) return;
      publish();
      if (_captureEnabled &&
          !_rasterizing &&
          _hintSignature != _pendingHintSignature) {
        _hintSignature = _pendingHintSignature;
        final generation = _generation, revision = ++_hintRevision;
        unawaited(rasterize(generation, revision));
      }
    });
  }

  Future<void> rasterize(int generation, int revision) async {
    final hintKey = _hintKey, paneKey = _paneKey;
    if (hintKey == null || paneKey == null) return;
    _rasterizing = true;
    try {
      final hint = await raftCaptureHtmlRegionHint(hintKey, paneKey);
      if (!_disposed &&
          generation == _generation &&
          revision == _hintRevision &&
          _captureEnabled) {
        _hint = hint;
        publish();
      }
    } catch (_) {
      // A retired or not-yet-painted layer cannot supply a frame. Never expose
      // raster/disposal errors as an unhandled application exception.
    } finally {
      _rasterizing = false;
      if (!_disposed &&
          _captureEnabled &&
          _hintSignature != _pendingHintSignature) {
        _hintSignature = _pendingHintSignature;
        unawaited(rasterize(_generation, ++_hintRevision));
      }
    }
  }

  void publish() {
    if (_owner == null || _disposed) return;
    try {
      _owner!.updateNativeRegionOverlay(
        RaftHtmlNativeRegionOverlay(
          generation: _generation,
          sequence: ++_outputSequence,
          viewport: _viewport,
          captureEnabled: _captureEnabled,
          markers: List.unmodifiable(_markers),
          hint: _hint,
        ),
      );
    } catch (_) {
      // A native child may retire before this parent surface. Late paint must
      // never turn disposal into an application error or admit more input.
      _captureEnabled = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    invalidate();
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _owner = null;
    _hintKey = _paneKey = null;
  }
}
