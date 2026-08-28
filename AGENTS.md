# StartKind Development Instructions

This file is binding for any AI or developer working inside this project.

## Product North Star

StartKind helps adults move from "I know what I need to do" to "I have started one small step." Optimize for task initiation, restart after avoidance, and low-shame execution.

## Required Behavior

- Default all user-facing copy to US English.
- Provide Simplified Chinese as an optional language.
- Build and ship native iOS first. Defer Android until iOS market validation.
- Keep the interface extremely simple.
- Never default to long task lists.
- Never use punitive streaks, red overdue shame, or failure language.
- Prefer one visible next step over comprehensive planning.
- Treat bills, email, appointments, returns, insurance, banking, household chores, and family admin as first-class task categories.

## Development Stack

- iOS: Swift, SwiftUI, SwiftData where appropriate, StoreKit 2, XCTest.
- Future Android: Kotlin, Jetpack Compose, Room, BillingClient, JUnit. Do not start Android work until explicitly requested.
- Sync: CloudKit. Personal history lives in the user's own iCloud and never reaches our server. There are no accounts, emails or passwords.
- Backend: a small self-hosted Deno service (startk.livepet.ren) doing only what CloudKit cannot — AI proxy, co-start rooms, entitlement verification. Identity is an anonymous device token; only its hash is stored.
- AI: DeepSeek behind that proxy for Plus features; deterministic local templates for Free features where possible.

## Delivery Gate

Before saying a task is complete, run this checklist:

1. Requirement match: confirm the implemented behavior matches the user's latest request.
2. Same-class scan: check nearby files and flows for the same class of issue.
3. Build check: run the relevant iOS or backend build command. Android checks apply only after Android work is explicitly started.
4. Test check: run unit tests or focused manual tests for the changed behavior.
5. UX check: verify no new UI overlap, confusing empty states, or punitive language.
6. Regression note: state what was tested and what was not tested.

If any check cannot be run, say exactly why and do not imply the feature is fully verified.

## Safety Boundaries

Do not perform App Store submission, paid API activation, production database migration, public email sending, or irreversible account changes without explicit user confirmation.
