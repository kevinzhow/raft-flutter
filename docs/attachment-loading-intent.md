# K11: image preview intent during loading

The actual Linux `df59ac2` workflow passed Follow, Unfollow and Done removal,
then failed while clicking an attachment preview before its render object had
painted. That first failure is retained at
`.local/cody-full-native-linux-df59ac2`; it does not prove that ordinary user
input is safe during loading.

Further real mounted pointer tests found a separate product defect in all three
themes. The already painted loading image card receives the pointer, but
`openCurrent` calls `loadImage` while it is already loading. That call returns
immediately and the absent image causes preview opening to return too. The
first user click is lost. All three pre-fix failures remain in
`.local/cody-attachment-early-click-before.log`.

Pinned Source `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6` separates these lifetimes:

| Source path, relative to `packages/web/src` | Behavior inspected |
| --- | --- |
| `components/message/MessageItem.tsx:4683–4691,4720–4724` | The real attachment preview action opens the lightbox store independently of thumbnail image loading. |
| `store/imageLightboxStore.ts:61–66` | Opening immediately publishes the lightbox identity and open state. |
| `components/ImageLightbox.tsx:150,324–327` | The open lightbox can display its loading indicator before the image is ready. |

Flutter now immediately opens the existing scoped lightbox and observes the
existing attachment image owner. Completion replaces its spinner with the
decoded image; failure displays the existing unavailable-image fallback. It
does not issue a second image request or fabricate an image. Close, attachment
replacement and authority retirement retain their existing ownership fences;
late completion cannot reopen a closed preview or publish private media after
revocation.

`attachment_open_intent_test.dart` adds 15 actual mounted cases across the three
themes. They click the painted loading card, close/revoke while bytes are held,
deliver a decoded image without painting a new thumbnail frame and click at the
previously painted position, and handle a failed load. The 36-case combined
attachment scope/repository/intent regression passes in
`.local/cody-attachment-loading-intent-regression-v1.log`. These component cases
do not substitute for native process replay or matched Source browser input.

The native workflow additionally holds only its own real signed-image-URL
response, clicks the real painted loading card, checks immediate preview
presence, captures `attachment-loading-intent`, releases that unchanged
response, checks the real decoded image, closes and reopens it. The original
pointer hit check remains fatal. A bounded paint-ready wait covers the
subsequent already loaded card; it cannot hide a lost click on the already
painted loading card.

Current native outcomes are reported separately by their exact source hash and
run receipt. The first Linux failure, the pre-fix mounted failures and the
earlier compile failure are retained. Source rendering, fixture data, image
baselines, comparison thresholds and calibration are unchanged.

The checklist adds K11 as a separate discovery; its original 47-item audit and
the previous K10 discovery remain immutable. Current parent count is 49.
Whenever a native wait or click fails, first replay real input on the visible
control and determine whether the product loses input or delays feedback.
Change a test readiness condition only after that distinction is established.
