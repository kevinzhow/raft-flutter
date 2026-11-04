import 'package:flutter/widgets.dart';

import '../data/workspace_controller.dart';
import 'model_label_catalog.dart';

/// Borrows the session catalog for a surface that displays model choices.
/// The session owns fetching, authority fencing and disposal; the surface
/// owns only its repaint listener.
mixin ModelLabelCatalogListener<T extends StatefulWidget> on State<T> {
  WorkspaceController? get modelLabelWorkspace;
  WorkspaceController? _modelLabelOwner;
  ModelLabelCatalogStore? _modelLabels;

  @override
  void initState() {
    super.initState();
    _watchModelLabels();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _watchModelLabels();
  }

  void _watchModelLabels() {
    final owner = modelLabelWorkspace;
    if (identical(owner, _modelLabelOwner)) {
      _modelLabels?.load();
      return;
    }
    _modelLabels?.removeListener(_modelLabelsChanged);
    _modelLabelOwner = owner;
    _modelLabels = owner == null ? null : ModelLabelCatalogStore.of(owner);
    _modelLabels
      ?..addListener(_modelLabelsChanged)
      ..load();
  }

  void _modelLabelsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _modelLabels?.removeListener(_modelLabelsChanged);
    super.dispose();
  }
}
