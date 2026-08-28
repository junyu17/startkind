# StartKind Project Brief for AI Implementers

Read this first, then read every file in `docs/` before writing code.

## Identity

Project name: StartKind

StartKind is an iOS-first execution assistant for adults with ADHD-style executive function challenges. It helps users start one small action, recover after avoidance, calibrate real task time, and co-start with AI or a friend.

This is not a generic todo app, habit tracker, or medical treatment product.

## Fixed Business Decisions

- Default language: US English
- Optional language: Simplified Chinese
- Platform strategy: ship native iOS first, validate market demand, then consider Android
- iOS stack: Swift, SwiftUI, StoreKit 2
- Future Android stack: Kotlin, Jetpack Compose, BillingClient. Do not start until explicitly requested.
- Sync: CloudKit (the user's own iCloud)
- Backend: self-hosted Deno service at startk.livepet.ren (AI proxy, co-start rooms, entitlement verification only)
- App name: StartKind
- Apple App ID: 6799113108
- Apple Developer ID: Jun.yu@live.com
- Apple Team ID: 255R6QQR97
- Public contact email: billy.yu@me.com
- Legal contact: Jun Yu
- Subscription: Free + StartKind Plus only
- Monthly Plus: $9.99
- Annual Plus: $89.99

## Product Rule

The app should almost always show one next step, not a long list.

If the user says:

"I'm a mess today."

StartKind should return something like:

"Open your email and search for 'bill.' Stop when you find one bill, even if you do not pay it yet."

## Free Scope

Free must be genuinely useful and low operating cost:

- 5 One Next Step generations per day
- Text capture
- Voice input through local OS capability where possible
- Local task shrinker templates
- Start timers: 5, 10, 15, 25 minutes
- No-Shame Rescheduler
- Local 14-day actual-time history
- One active Recovery Capsule
- One Admin Quick Start per day
- English and Simplified Chinese

## Plus Scope

StartKind Plus unlocks the full execution system:

- Unlimited One Next Step
- Deep AI task parsing
- Calendar sync
- Email, pasted text, screenshot, and photo parsing
- Admin Task Reader
- Personal Time Calibration
- Personal Execution Model
- Unlimited Recovery Capsules
- AI quiet co-start
- Friend 25-minute co-start links
- Cross-device sync
- Advanced insights

## UX Requirements

- Interface must be extremely simple.
- First screen must be Start, not a dashboard.
- Avoid long task lists by default.
- Avoid punitive streaks.
- Avoid hostile overdue UI.
- Avoid red failure states.
- Use language like "Make it smaller" and "Continue from here."

## Required Core Loop

Capture -> One Next Step -> Timer -> Done/Partial/Skipped -> Calibrate -> Reschedule or Recover.

This loop must work before adding secondary features.

## Delivery Rule

Never say a coding task is complete after only editing files.

Every delivery must include:

- Requirement match check
- Same-class scan
- Build command
- Relevant tests
- Manual UX smoke test if UI changed
- What passed
- What was not tested and why

See `docs/TESTING_AND_DELIVERY.md`.

## Safety Boundaries

Do not submit to App Store, change paid settings, deploy production backend changes, or perform irreversible account operations without explicit user confirmation.
