import 'dart:math';

const channelConversionFlag = 'channel_to_joint_conversion_v0';
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

class ChannelConversionSnapshot {
  const ChannelConversionSnapshot(this.status, this.command, this.job);
  final String status;
  final Map<String, dynamic> command, job;
  static ChannelConversionSnapshot from(dynamic value) {
    final payload = _map(value), channel = _map(payload['channel']);
    final canonical = payload['conversionState'] ?? channel['conversionState'];
    final state = _map(canonical);
    final command = _map(
      canonical != null
          ? state['command']
          : payload['conversionCommand'] ?? channel['conversionCommand'],
    );
    final job = _map(
      canonical != null
          ? state['job']
          : payload['conversionJob'] ?? channel['conversionJob'],
    );
    const jobStates = {'pending', 'running', 'failed', 'done', 'canceled'},
        commandStates = {'pending', 'completed', 'failed'};
    if (command.isNotEmpty &&
        (command['id'] is! String ||
            !commandStates.contains(command['status']) ||
            !{'start', 'retry', 'cancel'}.contains(command['kind']))) {
      throw const FormatException('Unsupported conversion command.');
    }
    if (job.isNotEmpty &&
        (job['id'] is! String ||
            !jobStates.contains(job['status']) ||
            job['phase'] is! String ||
            (job.containsKey('canCancel') && job['canCancel'] is! bool))) {
      throw const FormatException('Unsupported conversion receipt.');
    }
    final status = canonical != null
        ? state['status']
        : command['status'] == 'pending'
        ? 'pending'
        : job.isNotEmpty
        ? job['status'] == 'pending'
              ? 'running'
              : job['status']
        : command['status'] == 'failed'
        ? 'failed'
        : 'idle';
    final expected = command['status'] == 'pending'
        ? 'pending'
        : job.isNotEmpty
        ? job['status'] == 'pending'
              ? 'running'
              : job['status']
        : command['status'] == 'failed'
        ? 'failed'
        : 'idle';
    if (status != expected) {
      throw const FormatException('Inconsistent conversion state.');
    }
    if (!{
          'idle',
          'pending',
          'running',
          'failed',
          'done',
          'canceled',
        }.contains(status) ||
        (['running', 'done', 'canceled'].contains(status) && job.isEmpty) ||
        (status == 'pending' && command.isEmpty)) {
      throw const FormatException('Unsupported conversion state.');
    }
    return ChannelConversionSnapshot(
      status,
      Map.unmodifiable(command),
      Map.unmodifiable(job),
    );
  }

  bool get canCancel =>
      ['pending', 'running', 'failed'].contains(job['status']) &&
      (job['canCancel'] == true ||
          (!job.containsKey('canCancel') &&
              job['phase'] == 'prepare' &&
              _map(job['progress'])['canonicalCopyStarted'] != true));
  bool get active => status == 'pending' || status == 'running';
}

class ConversionObservation {
  ConversionObservation({
    required this.token,
    required this.kind,
    required this.baseline,
    required this.previousCommandId,
  });
  final String token, kind;
  final ChannelConversionSnapshot baseline;
  final String? previousCommandId;
  bool settles(ChannelConversionSnapshot next) {
    if (next.command['id'] == token) {
      if (next.command['status'] == 'failed') return true;
      return next.command['status'] == 'completed' &&
          next.job.isNotEmpty &&
          (next.command['jobId'] == null ||
              next.command['jobId'] == next.job['id']);
    }
    final sameJob =
        baseline.job['id'] != null && baseline.job['id'] == next.job['id'];
    if (kind == 'cancel' && sameJob && next.job['status'] == 'canceled') {
      return true;
    }
    if (sameJob && baseline.job['status'] != next.job['status']) return true;
    final laterCommand =
        next.command.isNotEmpty && next.command['id'] != previousCommandId;
    return laterCommand &&
        next.command['status'] != 'pending' &&
        next.job.isNotEmpty;
  }
}

String conversionCommandIdentity() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The durable server fence remains authoritative even if rollout is disabled.
bool channelConversionBlocksSending(Map<String, dynamic> channel) {
  try {
    final state = ChannelConversionSnapshot.from(channel);
    if (state.status == 'pending') return true;
    final job = state.job;
    if (job['status'] == 'failed' &&
        _map(job['progress'])['rollbackState'] == 'restored')
      return false;
    return {'pending', 'running', 'failed'}.contains(job['status']);
  } on FormatException {
    return true;
  }
}
