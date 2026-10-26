// Presentation of the Web EditProviderConnectionModal
// (packages/web/src/components/settings/EditProviderConnectionModal.tsx):
// DialogCard `Edit {name}` over a `space-y-4` form: Connection name, (gateway)
// Base URL, API key with the write-only hint, (gateway) the image-input
// checkbox, an error line and Cancel / Save changes. The app adapter owns the
// controllers and the PATCH.
import 'raft/checkbox.dart' show RaftCheckbox;
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'dialog_card.dart';
import 'form_presentation.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

class RaftEditProviderDialogView extends StatelessWidget {
  const RaftEditProviderDialogView({
    super.key,
    required this.connectionName,
    required this.gateway,
    required this.name,
    required this.endpoint,
    required this.apiKey,
    required this.supportsImageInput,
    required this.onSupportsImageInput,
    required this.canSubmit,
    required this.submitting,
    required this.onClose,
    required this.onSubmit,
    this.error,
  });

  final String connectionName;
  final bool gateway, supportsImageInput, canSubmit, submitting;
  final TextEditingController name, endpoint, apiKey;
  final ValueChanged<bool> onSupportsImageInput;
  final VoidCallback onClose, onSubmit;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    const gap = SizedBox(height: 16); // `space-y-4`
    return RaftModalBackdrop(
      child: RaftDialogCard(
        key: const ValueKey('provider-connection-edit-dialog'),
        title: raftFormat(context, 'Edit {name}', {'name': connectionName}),
        onClose: onClose,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftProductFormField(
              label: 'Connection name',
              child: RaftDialogTextInput(
                fieldKey: const ValueKey('provider-edit-name'),
                controller: name,
                autofocus: true,
              ),
            ),
            if (gateway) ...[
              gap,
              RaftProductFormField(
                label: 'Base URL',
                child: RaftDialogTextInput(
                  fieldKey: const ValueKey('provider-edit-endpoint'),
                  controller: endpoint,
                ),
              ),
            ],
            gap,
            RaftProductFormField(
              label: 'API key',
              hint: 'Leave blank to keep current key. Write-only; Raft encrypts this value and will not return it.',
              child: RaftDialogTextInput(
                fieldKey: const ValueKey('provider-edit-key'),
                controller: apiKey,
                obscure: true,
              ),
            ),
            if (gateway) ...[
              gap,
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSupportsImageInput(!supportsImageInput),
                child: Row(
                  spacing: 8, // gap-2
                  children: [
                    RaftCheckbox(
                      value: supportsImageInput,
                      onChanged: onSupportsImageInput,
                      semanticLabel: raftText(
                        context,
                        'This gateway supports image input',
                      ),
                    ),
                    Flexible(
                      child: Text(
                        raftText(context, 'This gateway supports image input'),
                        style: raftCssTextStyle(
                          family: t.headingFont,
                          step: RaftTextSteps.sm,
                          weight: FontWeight.w500,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (error != null) ...[
              gap,
              Text(
                raftText(context, error!),
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.sm,
                  weight: FontWeight.w500,
                  color: const Color(0xFFB91C1C), // text-red-700
                ),
              ),
            ],
          ],
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8, // gap-2
          children: [
            RaftRecipeButton(
              key: const ValueKey('provider-edit-cancel'),
              label: 'Cancel',
              onPressed: raftExplicitClose(context, onClose),
            ),
            RaftRecipeButton(
              key: const ValueKey('provider-edit-save'),
              label: 'Save changes',
              glyph: submitting ? null : RaftGlyph.pencil,
              child: submitting
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [RaftSpinner()],
                    )
                  : null,
              variant: RaftButtonRecipeVariant.default_,
              disabled: !canSubmit || submitting,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
