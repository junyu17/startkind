# Technical Architecture

Last updated: 2026-08-09

## Platform Requirement

Build native iOS first:

- iOS: Swift + SwiftUI

Future Android, after iOS market validation:

- Kotlin + Jetpack Compose

Do not use React Native, Flutter, Ionic, or web wrappers unless explicitly approved later.

## Shared Product Architecture

The iOS app should implement these domain modules. Future Android should mirror them after validation:

- Capture
- NextStepEngine
- Timer
- Rescheduler
- RecoveryCapsule
- TimeCalibration
- AdminTaskReader
- CoStart
- Subscription
- Localization
- Sync

## iOS Stack

- Swift 6 or latest stable supported by installed Xcode
- SwiftUI for UI
- SwiftData for local persistence where appropriate
- StoreKit 2 for subscriptions
- Speech framework or OS dictation path for voice input
- WidgetKit for Home Screen restart entry points
- ActivityKit for timer Live Activities where available
- UserNotifications for local no-shame rescue reminders
- XCTest for unit tests
- XCUITest for core flows

## Future Android Stack

- Kotlin
- Jetpack Compose
- Room for local persistence
- DataStore for settings
- BillingClient for subscriptions
- JUnit for unit tests
- Compose UI tests for core flows

Do not start Android implementation during the iOS-first release phase unless explicitly requested.

## Backend Stack

Use the self-hosted backend for:

- Auth
- User profile
- Cross-device sync
- Subscription entitlement mirror
- AI proxy Edge Functions
- Secure file metadata for screenshots/photos where needed

Use backend endpoints for:

- AI request routing
- Prompt assembly
- Usage limits
- Plus entitlement checks
- Admin Task Reader parsing

## Privacy Model

Default:

- Store basic Free history locally.
- Do not upload task text unless a Plus cloud feature requires it.
- Make cloud features explicit.

Plus:

- Sync task and calibration data after user sign-in.
- Keep sensitive administrative text scoped to the user's account.
- Avoid training claims unless legally reviewed.

## Offline Behavior

Free core features should work offline:

- Local templates
- Local micro-templates
- Timers
- Local history
- Recovery Capsule
- Saved starts (`PersonalVaultStore`)
- Basic manual task shrinking

Plus cloud-only features should degrade gracefully:

- Show cached next step where available.
- Allow manual timer start.
- Queue sync.

## Entitlements

The iOS release must treat StoreKit as the source signal. Future Android should use Play Billing after market validation. The backend verifies Apple's signed StoreKit 2 transaction locally so it can gate the AI proxy; it never takes the client's word for the tier.

Entitlement states:

- free
- plus_trial
- plus_active
- plus_grace_period
- plus_expired

## AI Cost Control

Use AI only when it produces clear value:

- Overwhelm parsing
- Admin Task Reader
- Personal Execution Model
- complex rescheduling

Use deterministic local templates for common Free actions.

## iOS Extensions and Local Retention Surfaces

StartKind has two iOS extension targets:

- `StartKindShareExtension`: accepts shared text or URLs and opens `startkind://capture?text=...`.
- `StartKindWidgetExtension`: provides a WidgetKit quick-start surface that deep-links to `startkind://start`.

The retention surfaces are intentionally local-first:

- `MicroTemplateLibrary` generates common adult-admin next steps without network calls.
- `AutopilotPlanner` chooses one local start from active recovery, vault items, and time-aware templates.
- `FrictionMap` derives local blocker/category insights from recovery capsules and calibration snapshots.
- `PersonalVaultStore` stores reusable tiny-start snippets in `UserDefaults`.
- `RetentionFeatureKit` contains Energy Match, Friction Presets, Proof of Start, Tiny Admin Inbox, and Yesterday Rescue helpers.
- `ProofOfStartStore` and `TinyAdminInboxStore` persist lightweight local JSON in `UserDefaults` to avoid adding migration risk before the first iOS release.
- Blocker reasons and Return Notes are encoded into existing recovery-capsule metadata to avoid a SwiftData schema migration for this release pass.
- `LiveTimerActivityService` starts/ends an ActivityKit timer and silently no-ops when unavailable.
- `RescueNotificationService` schedules one local rescue notification after interrupted/paused/abandoned starts and deep-links to `startkind://rescue`.

OpenCode note: for this repo, `opencode run --pure --dir /Users/jun/Documents/project/startkind --model opencode/deepseek-v4-flash-free --auto ...` is the reliable invocation. Non-pure mode can stall in plugin/context exploration.

If the extension targets are archived for App Store upload, the signing setup must include `ren.startkind.share` and `ren.startkind.widget` bundle identifiers. Live Activities and notification tap-through still need real-device verification because simulator builds do not prove Lock Screen behavior.

## Security

- Never ship a provider API key in the app binary; the backend holds it.
- Never send Apple or future Google shared secrets directly from clients except through official billing flows.
- Do not log user task content in production logs.
- Redact emails, phone numbers, and payment amounts in diagnostics unless explicit debugging mode is enabled.
