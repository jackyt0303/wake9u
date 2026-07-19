# 06 — Dashboard, mascot, and handoff

## Screens

The signed-in dashboard shows today's occurrence/attempt state, next alarm in the stored timezone, streak summary with provisional labeling, schedule status, and a primary action appropriate to state. History lists immutable dated outcomes and corrections; it does not imply unscheduled dates are failures. Settings covers weekly time/days/timezone, Spotify playlist curation, Shortcut preference, notification/alarm/motion/Watch permission status, privacy, sign out, and account deletion.

Use a clear configuration-status hierarchy: `Armed and counting`, `Armed locally—awaiting sync`, `Draft—sign in required`, `Alarm permission needed`, and `Disabled by service`. Do not claim a streak result final while evidence is queued or cloud outcome provisional. All destructive preference actions require deliberate confirmation and use the local/cloud outbox rules in [01](01_foundation_and_app_contract.md).

## Mascot state machine

Production Lottie JSON is supplied by design and included as bundled assets: `Hostile`, `Coach`, and `Defeated`. The app chooses a semantic mascot state, not an arbitrary animation:

| Product state | Mascot |
| --- | --- |
| active attempt, alarm dismissed/incomplete | Hostile |
| progress toward threshold, local success, final success | Coach |
| provisional or final failure, sensor unavailable | Defeated |

Use a `MascotRenderer` protocol that loads a named Lottie asset and has a static SwiftUI image/illustration fallback if loading fails. With Reduce Motion, display the same semantic static state without looping animation; never encode essential information solely in motion or color. Provide VoiceOver labels such as `Coach: 7 of 10 steps recorded, 3 minutes remaining`; limit announcements to state changes and meaningful progress boundaries.

## History and availability

The local dashboard renders cached schedule/history immediately and marks freshness. The GraphQL repository then refreshes views and merges them by server version/outcome event sequence. Never overwrite a locally captured terminal evidence envelope; present `Syncing`, `Saved on this phone`, `Accepted`, or typed rejection status. A late correction should visually explain that it restored/recomputed the streak, with its audit timestamp.

## Shortcut handoff

Users choose a supported Shortcut name in settings; validate it against the remote-config policy and persist it through `saveShortcutPreference`. After a final/local trusted success, compose `shortcuts://run-shortcut?name=` with correct URL-component encoding and call the system URL opener. Record only a generic local result (`opened`, `unavailable`, `cancelled`); never assume the Shortcut performed its task or upload its contents.

If no preference exists, the URL is rejected, the Shortcut app is unavailable, or opening fails, remain on the success screen and show a quiet optional message. Return to Wake9u naturally when the user comes back; do not block success, loop URL opens, or request broader automation privileges.

## Acceptance tests

Snapshot/UI-test all main state combinations, static fallback, large Dynamic Type, high contrast, VoiceOver labels/order, and Reduce Motion. Test cached/offline dashboard, queued evidence, provisional correction, malformed/missing Lottie assets, and every Shortcut outcome. Product QA must approve copy that distinguishes actual system alarm authorization from ordinary notification permission.

