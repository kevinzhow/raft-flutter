import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/auth_second_factor_page.dart';
import 'src/form_controls.dart';

@RaftPreviews('Page Sign-in two-step verification', size: Size(390, 844))
Widget authSecondFactorPreview() => const _SecondFactor();

@RaftPreviews(
  'Page Sign-in two-step verification wrong code',
  size: Size(390, 844),
)
Widget authSecondFactorWrongCodePreview() => const _SecondFactor(
  fieldError:
      "That code didn't work. Check your authenticator app and try again.",
);

@RaftPreviews(
  'Page Sign-in two-step verification expired',
  size: Size(390, 844),
)
Widget authSecondFactorExpiredPreview() =>
    const _SecondFactor(ended: 'This sign-in has expired. Sign in again.');

class _SecondFactor extends StatefulWidget {
  const _SecondFactor({this.fieldError, this.ended});
  final String? fieldError, ended;
  @override
  State<_SecondFactor> createState() => _SecondFactorState();
}

class _SecondFactorState extends State<_SecondFactor> {
  final code = TextEditingController();
  var method = RaftSecondFactorCodeMethod.totp;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totp = method == RaftSecondFactorCodeMethod.totp;
    final other = totp
        ? RaftSecondFactorCodeMethod.backupCode
        : RaftSecondFactorCodeMethod.totp;
    return RaftAuthSecondFactorPage(
      maskedEmail: 'p***@example.invalid',
      expiresAt: '14:05',
      method: method,
      ended: widget.ended,
      fieldError: widget.fieldError,
      canVerify: code.text.trim().isNotEmpty,
      onVerify: () {},
      onBack: () {},
      codeField: RaftTextInput(
        key: ValueKey(method),
        controller: code,
        mono: true,
        invalid: widget.fieldError != null,
        hintText: totp ? '123456' : 'xxxxx-xxxxx',
        onChanged: (_) => setState(() {}),
      ),
      switches: [
        RaftSecondFactorSwitch(other, () => setState(() => method = other)),
      ],
    );
  }
}
