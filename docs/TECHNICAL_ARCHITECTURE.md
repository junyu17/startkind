# Technical Architecture

Last updated: 2026-08-07

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

Use Supabase for:

- Auth
- User profile
- Cross-device sync
- Subscription entitlement mirror
- AI proxy Edge Functions
- Secure file metadata for screenshots/photos where needed

Use Supabase Edge Functions for:

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
- Timers
- Local history
- Recovery Capsule
- Basic manual task shrinking

Plus cloud-only features should degrade gracefully:

- Show cached next step where available.
- Allow manual timer start.
- Queue sync.

## Entitlements

The iOS release must treat StoreKit as the source signal. Future Android should use Play Billing after market validation. Backend entitlements should be mirrored in Supabase for cross-device features.

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

## Security

- Never hardcode service-role Supabase keys in app binaries.
- Never send Apple or future Google shared secrets directly from clients except through official billing flows.
- Do not log user task content in production logs.
- Redact emails, phone numbers, and payment amounts in diagnostics unless explicit debugging mode is enabled.
