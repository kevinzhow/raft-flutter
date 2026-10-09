# Product unread attention and Sidebar count

Pinned Source is `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`; its product
and installed raft-ui 0.5.27 recipes remain unchanged.

Source LeftRail.tsx:129–143,224–244 owns two independent signals. Chat follows
unread in joined channels and DMs; public discovery rows do not light it.
Activity follows the accepted inbox window's server-wide `totalUnreadCount`,
independently of the active filter. `serverUnreadSummary.ts:75–84` preserves
that accepted authority instead of resurrecting an older preload summary.

LeftRail.tsx:1035,1062–1071 suppresses attention on the selected Chat/Activity
entry. AppRailItemAttention (`dist/index.mjs:2268–2288`) paints an
AppRailItemIndicator and, in Elegant, a duplicate of the real icon through an
attention tint, drop shadow and radial alpha mask. The nested product
AttentionDot is hidden; rendering its 10px dot would be incorrect here.
AppRailItemIndicator (`:2320`) composes Status `size=sm`, `attention=true`:
an 8px circle at right -4px/top -2px relative to the icon. Brutal uses the accent
variant; Elegant uses primary and the rail's resolved linear-sRGB mixed fill.
The generated mask fixes its centre at 96%/12%, uses CSS farthest-corner radius
and alpha stops at 0/24/38/58/74%. The shared renderer consumes those generated
CSS values without changing colour calibration or the global recipe engine.
The existing global mixed-colour projection falls back to oklab for srgb-linear;
this new slot resolves its generated linear-sRGB expression locally. Chromium147
readback of the actual compiled Source expression is Br [254,125,168],
Elegant-light [239,199,61], dark [254,218,116]. The local mix of already-quantized
theme token bytes preserves a one-byte light-green difference (198); dark and
Brutal bytes match. This difference remains explicit and is not patched with
theme-specific colours. Private input/readback files are
`.local/k09e-indicator-oracle-input.json` and
`.local/k09e-indicator-chrome-readback.json`.

WorkspaceView now supplies binary attention separately from the existing
numeric library API. ResourceView exposes an optional accepted-total callback
only after its existing authority/request fence. The host retains that accepted
total across section changes, fences it by controller/principal/generation/
server/role, and retires it after explicit denial. A late old-server response
cannot light a new scope. No sum of conversation counts is used for Activity.

Source AgentRow (`Sidebar.tsx:1097–1101`), DMRow (:1012–1014) and loud ChannelRow
(:901–903) all use SidebarItemCount accent. The generic pinned-Agent row had a
3px radius, bold Elegant text and a different fill. It now shares the existing
Source Sidebar count: height16, radius4, theme-specific border/fill and
Brutal-bold/Elegant-normal 10px type. Existing conversation count wrappers
retain their public API; zero counts remain absent and >99 labels remain 99+.

`workspace_unread_attention_test.dart` contains six actual WorkspaceView
checks tagged K09e across all three themes. Held inbox responses verify accepted
data, active suppression, retained totals, accepted zero and late old-server
rejection; actual pinned Agent rows verify the rendered count recipe.
`rail_attention_test.dart` adds three mounted paint/input checks: actual 8px
indicator pixels, radial icon tint below the dot, drop-shadow rendering,
position and active selection suppression. The SDK preview exercises real
selection and attention.

Private original-product receipt `.local/k09e-original-product-fail.log`
retains all six failures. The identical private assertions pass after repair in
`.local/k09e-original-product-after.log`. Focused application regression checks
pass39, including existing ResourceView authority/page and Activity activation
checks. The shared SDK run passes43, including existing navigation and all
three-theme black-flash checks; a stricter radial-mask raster run passes3.
Application and SDK analysis are clean; the design-system audit has no growth.

This is bounded mounted-product evidence, not native Linux/Android acceptance
or a 297-case visual rerun. The earlier selected9 visual receipt remains the
frozen current evidence, with its existing Elegant Avatar List Row and Mobile
Tabbar differences. Cross-server/preload Activity summaries and background inbox
count reconciliation are still data-parity gaps; the implementation invents
neither a hint nor a count when the required authority is unavailable. Computer,
server-switcher and feedback attention signals are outside this batch. K09 as
a whole remains partial until those product/data and broader visual limits are
resolved.
