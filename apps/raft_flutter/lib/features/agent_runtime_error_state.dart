// What the agent panel's runtime error banner says, and to whom.
// Pure logic; agent_runtime_error_banner_view.dart formats and draws it.
//
// Source: Web v1.24.0 packages/web/src/features/agent/AgentDetailPanel.tsx
// (the `hasRuntimeError` block), features/agent/AgentRuntimeErrorNotice.tsx,
// utils/classifyRuntimeError.ts, packages/shared/src/runtimeErrorVisibility.ts.
import '../data/runtime_error.dart';
import 'agent_metadata_projection.dart';

/// One banner: its headline, the manager's scrubbed detail, and the billing
/// variant's pieces. Texts are catalog descriptors (English source + values).
class RuntimeErrorBannerSpec {
  const RuntimeErrorBannerSpec({
    required this.headline,
    required this.kind,
    required this.code,
    required this.canViewDetails,
    this.detail,
    this.billingBody,
    this.showAskAdmin = false,
    this.showModelSettings = false,
  });

  /// The classified catalog copy, the code's sentence, or the generic line.
  final AgentActivityDescriptor headline;
  final RuntimeErrorKind? kind;

  /// The error's code (a known one), or null.
  final String? code;
  final bool canViewDetails;

  /// A manager's scrubbed error text under a coded headline.
  final String? detail;

  /// Non-null: the billing banner ("Model service balance too low"), shown to
  /// every viewer; its body names the agent.
  final AgentActivityDescriptor? billingBody;

  /// Billing without an action: say who can fix it.
  final bool showAskAdmin;

  /// Billing: "View model settings" for whoever may open them.
  final bool showModelSettings;

  bool get billing => kind == RuntimeErrorKind.billingExhausted;

  /// Copy info: viewers who see details, the billing banner too (the raw
  /// provider reply stays in the copied info only).
  bool get showCopy => canViewDetails;

  /// View logs: viewers who see details, never on the billing banner (it
  /// keeps one action).
  bool get showViewLogs => canViewDetails && !billing;
}

/// Web's `hasRuntimeError` block of `AgentDetailPanel`. Null when the agent
/// has no runtime error to show.
///
/// [activity], [activityDetail] and [errorCode] are the live activity;
/// [lastRuntimeError] is the stored error; [spawnLookupReason] the start
/// failure's lookup reason.
RuntimeErrorBannerSpec? resolveRuntimeErrorBanner({
  required String activity,
  required String activityDetail,
  required String? errorCode,
  required Object? lastRuntimeError,
  required bool canViewDetails,
  required bool canOpenModelSettings,
  required String agentTitle,
  required String runtimeName,
  String? spawnLookupReason,
}) {
  final stored = lastRuntimeError is Map ? lastRuntimeError : null;
  final hasError = activity == 'error' || stored != null;
  if (!hasError) return null;
  AgentActivityDescriptor key(String s, [Map<String, Object?> v = const {}]) =>
      (source: s, values: v, raw: false);
  final raw = activity == 'error'
      ? activityDetail
      : '${stored?['message'] ?? ''}';
  // The authoritative typed diagnostic, when both parts are present.
  final typed =
      stored != null &&
          '${stored['errorClass'] ?? ''}'.isNotEmpty &&
          '${stored['errorReason'] ?? ''}'.isNotEmpty
      ? stored
      : null;
  // The server sends every viewer the error's code, from the same source as
  // the text (the error activity's, else the stored error's).
  final code =
      isRuntimeErrorCode(activity == 'error' ? errorCode : stored?['code'])
      ? (activity == 'error' ? errorCode : stored?['code']) as String
      : null;
  // Text patterns only for a viewer the server sends the text to, and only when
  // the error has no code.
  final kind =
      classifyTypedRuntimeError(typed) ??
      (raw.isNotEmpty && code == null && canViewDetails
          ? classifyRuntimeError(raw)
          : null);
  // A "not installed" classification only keeps the install copy when the
  // start failure's typed carrier confirms the miss.
  final lookup = kind == RuntimeErrorKind.notInstalled
      ? runtimeLookupDisplayForReason(spawnLookupReason)
      : null;
  final errorText = lookup != null
      ? key(runtimeLookupBannerText(lookup), {'runtimeName': runtimeName})
      : kind != null
      ? key(runtimeErrorText(kind))
      : agentActivityDescriptor('error', raw);
  final copy = runtimeErrorCodeCopy(code);
  final headline = canViewDetails
      ? (copy != null ? key(copy.manager) : errorText)
      : (copy != null ? key(copy.member) : key(genericRuntimeErrorMessage));
  // A manager's detail goes under the code's headline; without a code the
  // headline is the detail already.
  final detail = canViewDetails ? agentActivityErrorDetail(raw).trim() : '';
  final billing = kind == RuntimeErrorKind.billingExhausted;
  return RuntimeErrorBannerSpec(
    headline: billing ? errorText : headline,
    kind: kind,
    code: code,
    canViewDetails: canViewDetails,
    detail: copy != null && detail.isNotEmpty ? detail : null,
    billingBody: billing
        ? key(
            "{agent} can't reply right now. Check the balance and billing for the model service this agent uses, then start it again.",
            {'agent': agentTitle},
          )
        : null,
    showModelSettings: billing && canOpenModelSettings,
    showAskAdmin: billing && !canOpenModelSettings,
  );
}
