import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum LinuxDependency { webkit, mpv, poppler }

enum LinuxDependencyStatus { unchecked, available, missing }

class LinuxDependencyState {
  const LinuxDependencyState({
    this.status = LinuxDependencyStatus.unchecked,
    this.registered = false,
    this.requiresRestart = false,
    this.reason = '',
  });
  final LinuxDependencyStatus status;
  final bool registered, requiresRestart;
  final String reason;
  bool get available => status == LinuxDependencyStatus.available;

  factory LinuxDependencyState.read(Object? value) {
    if (value is! Map) return const LinuxDependencyState();
    final status = switch (value['status']) {
      'available' when value['available'] == true =>
        LinuxDependencyStatus.available,
      'missing' => LinuxDependencyStatus.missing,
      _ => LinuxDependencyStatus.unchecked,
    };
    return LinuxDependencyState(
      status: status,
      registered: value['registered'] == true,
      requiresRestart: value['requiresRestart'] == true,
      reason: value['reason'] is String ? value['reason'] as String : '',
    );
  }
}

class LinuxDependencyMissing implements Exception {
  const LinuxDependencyMissing(this.feature, this.state);
  final LinuxDependency feature;
  final LinuxDependencyState state;
  @override
  String toString() => 'Linux dependency unavailable: ${feature.name}';
}

/// On-demand optional features. Construction performs no native work. Missing
/// results are never used to skip a later inspect/ensure request.
class LinuxDependencies extends ChangeNotifier {
  LinuxDependencies({
    this.channel = const MethodChannel('app.raft/linux_dependencies'),
    this.platformAvailable,
  });

  static LinuxDependencies instance = LinuxDependencies();
  final MethodChannel channel;
  final bool Function()? platformAvailable;
  bool get supported =>
      platformAvailable?.call() ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux);
  final _states = <LinuxDependency, LinuxDependencyState>{};
  final _revisions = <LinuxDependency, int>{};
  final _ensuring = <LinuxDependency, Future<void>>{};
  int _revision = 0;
  String distro = '', idLike = '';

  LinuxDependencyState state(LinuxDependency feature) =>
      _states[feature] ?? const LinuxDependencyState();

  Future<void> inspect([LinuxDependency? feature]) =>
      _request('inspect', feature);

  Future<void> ensure(LinuxDependency feature) {
    if (!supported) return Future<void>.value();
    return _ensuring[feature] ??= _ensure(feature).whenComplete(() {
      _ensuring.remove(feature);
    });
  }

  Future<void> _ensure(LinuxDependency feature) async {
    await _request('ensure', feature);
    final result = state(feature);
    if (!result.available ||
        (feature != LinuxDependency.poppler && !result.registered)) {
      throw LinuxDependencyMissing(feature, result);
    }
  }

  Future<void> checkAll() async {
    if (!supported) return;
    for (final feature in LinuxDependency.values) {
      await inspect(feature);
    }
  }

  Future<void> _request(String method, LinuxDependency? feature) async {
    if (!supported) return;
    final ticket = ++_revision;
    try {
      final response = await channel.invokeMapMethod<Object?, Object?>(
        method,
        feature == null ? null : {'feature': feature.name},
      );
      if (response?['protocol'] != 1 || response?['features'] is! Map) {
        throw const FormatException('Invalid Linux capability response.');
      }
      final distribution = response?['distro'];
      if (distribution is Map) {
        distro = distribution['id'] is String
            ? distribution['id'] as String
            : '';
        idLike = distribution['idLike'] is String
            ? distribution['idLike'] as String
            : '';
      }
      final features = response!['features'] as Map;
      for (final item in LinuxDependency.values) {
        if ((feature == null || feature == item) &&
            (_revisions[item] ?? 0) <= ticket) {
          _states[item] = LinuxDependencyState.read(features[item.name]);
          _revisions[item] = ticket;
        }
      }
    } catch (_) {
      // Keep native diagnostic paths and loader messages off global surfaces.
      // A later user action always asks the native service again.
      if (feature != null && (_revisions[feature] ?? 0) <= ticket) {
        _revisions[feature] = ticket;
        _states[feature] = const LinuxDependencyState(
          status: LinuxDependencyStatus.missing,
          reason: 'probe_unavailable',
        );
      }
    }
    notifyListeners();
  }

  String? installCommand(LinuxDependency feature) {
    final family = {distro, ...idLike.split(RegExp(r'\s+'))};
    if (family.any({'ubuntu', 'debian'}.contains)) {
      final package = switch (feature) {
        LinuxDependency.webkit => 'libwebkit2gtk-4.1-0',
        LinuxDependency.mpv => 'libmpv2',
        LinuxDependency.poppler => 'poppler-utils',
      };
      return 'sudo apt install $package';
    }
    if (family.contains('fedora')) {
      final package = switch (feature) {
        LinuxDependency.webkit => 'webkit2gtk4.1',
        LinuxDependency.mpv => 'mpv-libs',
        LinuxDependency.poppler => 'poppler-utils',
      };
      return 'sudo dnf install $package';
    }
    return null;
  }
}
