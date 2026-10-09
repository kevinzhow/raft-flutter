# Shared rail identity, counts and conversation tabs

K09b's workspace identity now uses the existing mounted AvatarSlot frame.
Pinned Source `LeftRail.tsx:600–605` mounts a server `AvatarSlot` in the
`panel-header` context. `AvatarSlot.tsx:122` fixes its normal extent at 36px
and border at 2px; LeftRail's short-desktop override fixes the extent at 32px.
The identity retains the 14px initial independently of the extent. The RUI
Avatar recipe clips the Elegant image and fallback to a circle with a
transparent border. The earlier SDK rail used an opaque border and an 8px
rounded square. An explicit extent override in the shared frame preserves the
Source short-desktop size without scaling its text or changing other contexts.

K09c's explicit numeric rail-count API now paints the generated
`RaftAppRailRecipe.itemBadge` slot through `RaftRecipeBox`, replacing Material
Badge. RUI `dist/index.mjs:2133–2200` defines its theme-specific radius, border,
fill, ring and typography. The absolute -4px top/right offsets are relative to
the button padding box, inside its border. Zero counts remain absent and the
existing >99 label remains `99+`; keyboard/click and count semantics are retained.

This numeric slot is distinct from Source's actual product attention indicator.
`LeftRail.tsx:1062–1071` mounts `AppRailItemAttention` when the row has attention,
not a numeric count. This shared-component repair does not claim the product
attention mask/dot behavior is complete. The generic navigation row's historical
3px badge is also unchanged; mounted conversation counts already use their
Source SidebarItemCount override (`rounded-sm`, 16px high), which remains
covered by the existing Source-bound conversation navigation tests.

K09d's existing conversation tabs already match the inspected Source recipe.
RUI `conversationPanel` (`dist/index.mjs:4499–4567`) supplies the 40px Elegant
mobile list/tab override and 1px underline, with a 1px outer divider. Desktop
uses the underlying 48px list, product h-7 tab, and 2px underline. Dark desktop
tabs are transparent over ConversationPanelContent's actual card surface.
Brutal remains a 28px tab/list plus a 2px outer border. No product tab change was
needed.

`elegant_navigation_recipe_test.dart` adds nine mounted K09b/c/d checks across
Brutal light, Elegant light and Elegant dark. Identity checks both tall and
compact layouts; numeric counts exercise the actual rail and recipe slot;
conversation-tab checks assert actual layout and rasterized underline colors
at mobile/desktop widths, then select another tab by keyboard. The SDK preview
contains normal/compact identity, numeric counts and actual conversation tabs.

The selected SDK run passed 93 tests, including the existing black-flash,
rounded-full, avatar, conversation navigation and surface-override regressions.
SDK analysis was clean. An independently preserved actual-rail test fails on
all three original themes and passes after the repair; its private receipts are
`.local/k09-avatar-before-fail.log` and `.local/k09-avatar-after.log`.

A separate selected visual comparison retains the original Badge,
Avatar List Row and Mobile Tabbar case IDs, fixtures and thresholds in all
three themes. These nine pairs are regression evidence for those original
surfaces; they do not capture the desktop rail or ConversationPanelTabs.
The actual Source PNG bytes are checked against the frozen 297-case matrix.
Existing Elegant avatar-list-row and Mobile Tabbar DIFFs remain visible and
are not claimed repaired. This batch does not claim a full matrix rerun or
native Linux/Android acceptance.
