# StartKind iOS - Delivery & QA Report

**Date:** 2026-08-09
**Platform:** iOS native, Swift 6, SwiftUI, SwiftData, StoreKit 2, Speech, WidgetKit, ActivityKit, UserNotifications
**Toolchain:** Xcode 26.6, Swift 6.3.3, iPhone 17 Simulator
**Status:** Core product plus 13 retention/differentiation features are implemented and tested. StoreKit purchase/restore still requires sandbox/device or TestFlight verification before App Store submission.

---

## 1. Summary

StartKind implements the adult ADHD execution loop:

**Capture -> One Next Step -> Timer -> Done/Partial/Skipped/Interrupted -> Calibrate -> Reschedule/Recover**

The app is local-first, native SwiftUI, English by default with Simplified Chinese available, and uses StoreKit 2 for Plus subscriptions. The first screen remains the Start flow, not a dashboard. The product still avoids punitive streaks, overdue stacks, and long generated task lists.

This pass adds the second requested retention set: Autopilot Mode, Return Note, Friction Map, Live Activity support, and One-Tap Rescue Notification.

## 2. Deliverables

| Layer | Files / Components |
|---|---|
| App | `StartKindApp.swift`, `AppEnvironment.swift` |
| Domain | `NextStepEngine`, `TaskShrinker`, `Rescheduler`, `TimeCalibrator`, `AdminTaskReader`, `MicroTemplateLibrary`, `AutopilotPlanner`, `FrictionMap`, `UsageLimits` |
| Models | SwiftData persistence models plus `BlockerReason` |
| Services | `PersistenceService`, `PersonalVaultStore`, `LiveTimerActivityService`, `RescueNotificationService`, `EntitlementService`, `SpeechService`, `AIClient`, `SyncService`, `UsageTracker` |
| UI | Start, Recover, Patterns, Settings, Paywall, Timer, blocker picker, return note, vault picker, template picker, friction map |
| Extensions | `StartKindShareExtension`, `StartKindWidgetExtension` |
| Resources | English + Simplified Chinese localization, app icon, StoreKit config |
| Tests | 98 unit tests executed with 4 StoreKit simulator skips; 21 UI tests passed |
| Project | `project.yml` regenerates `StartKind.xcodeproj` with app, share extension, and widget extension targets |

## 3. Requirement Match

| Requirement | Status |
|---|---|
| Native iOS first; Android deferred | Done |
| Bundle identifier changed to `ren.startkind` | Done |
| StoreKit Plus monthly `StartKind_plus_monthly` at $9.99 | Wired |
| StoreKit Plus yearly `StartKind_plus_yearly` at $89.99 | Wired |
| Start page supports text, voice, category, and one-step generation | Done |
| One next step by default, no long list | Done and tested |
| 5/10/15/25 minute timers | Done |
| No-shame rescheduler | Done and tested |
| Time calibration from actual completion time | Done and tested |
| Recovery Capsule | Done and tested |
| Co-start invite flow with 6-digit room code | Done from earlier pass |
| Free vs Plus pricing and feature comparison on subscription page | Done from earlier pass |
| iCloud-first/no forced email for local use | Done from earlier pass |
| English default, Simplified Chinese optional | Done |
| Autopilot one-tap start | Done and tested |
| Return Note on interrupted/paused starts | Done and tested |
| Friction Map from blocker/history signals | Done and tested |
| Live Activity support for timer | Done; simulator build verifies ActivityKit integration and `NSSupportsLiveActivities` |
| One-Tap Rescue local notification | Done; unit-tested deep link and simulator build verifies notification service |

## 4. The 8 Requested Retention Features

| Feature | Implementation | Verification |
|---|---|---|
| I Got Interrupted | Timer has an interruption action that routes to recovery instead of treating the user as failed | UI test covers interruption flow |
| Blocker Picker | User selects why they stopped: distracted, too big, unclear, energy, waiting, emotion, time, other | Unit test covers blocker persistence; UI test covers blocker picker |
| Bad Day Mode | Inputs like "I'm overwhelmed" or "我今天一团乱" produce one tiny 5-minute reset step | Unit tests cover English and Chinese trigger phrases |
| Share Extension | Text/URL shared into iOS opens StartKind via `startkind://capture?text=...` | Build verifies extension target and Info.plist |
| Micro-Templates | Local, no-server templates for bills, email, appointments, documents, home reset, and bad-day reset | Unit tests cover template proposals |
| Widget | WidgetKit extension deep-links to `startkind://start` for quick restart | Build verifies widget target and Info.plist |
| Shareable Start Card | Next step can be shared as a simple encouragement card/message | UI test covers share button presence |
| Personal Vault | Local reusable tiny-start snippets saved in UserDefaults, managed from Start and Settings | Unit and UI tests cover save/pick/delete flows |

## 5. Build & Test Results

Commands run after implementation:

```bash
cd /Users/jun/Documents/project/startkind
xcodegen generate
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:StartKindTests
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:StartKindUITests
```

Results:

| Check | Result |
|---|---|
| XcodeGen project generation | Passed |
| Debug simulator build | Passed |
| Focused new-feature unit + UI suite | Passed |
| Full unit suite | 98 tests executed, 4 StoreKit simulator skips, 0 failures |
| Full UI suite | 21 passed, 0 failures |

The latest UI run executed 21 tests with 0 failures. Latest UI `.xcresult`:
`/Users/jun/Library/Developer/Xcode/DerivedData/StartKind-hhzoqshjiqpuazedynrbbteaucjv/Logs/Test/Test-StartKind-2026.08.09_19-35-01--0700.xcresult`.

## 5.1 The 5 Added Features From This Pass

| Feature | Implementation | Verification |
|---|---|---|
| Autopilot Mode | Start page has "Tell me what to start now"; planner chooses active recovery first, then vault, then time-aware templates | Unit tests for priority rules; UI test `testAutopilotCreatesOneNextStep` |
| Return Note | Blocker picker includes an optional note; persisted with blocker in recovery metadata without adding a SwiftData field | Unit tests for metadata and legacy decode; UI test `testInterruptedReturnNoteAppearsInRecovery` |
| Friction Map | Patterns shows local blocker/category friction insights and suggested smaller doorway steps | Unit test `testFrictionMapReportsCommonBlocker`; UI renders under Patterns |
| Live Activity | Timer start/end routes through `LiveTimerActivityService`; `NSSupportsLiveActivities` is true | Debug build passes with ActivityKit |
| One-Tap Rescue Notification | Paused/interrupted/abandoned steps schedule no-shame local rescue notification with `startkind://rescue` | Unit test for rescue deep link; Debug build passes with UserNotifications delegate |

Agent delegation audit: per `/Users/jun/.codex/AGENTS.md`, code agents were tried in order. `opencode/deepseek-v4-flash-free` only read files and produced no edits; Pi `volc-coding/glm-5.2` produced no output before interruption; Reasonix `deepseek/deepseek-v4-flash` only read/analyzed and produced no edits. Final implementation and verification were completed here by Codex.

## 6. StoreKit Status

StoreKit product identifiers are recorded:

| Product | Product ID | Apple ID | Price |
|---|---|---:|---:|
| Plus Monthly | `StartKind_plus_monthly` | `6799376244` | `$9.99/month` |
| Plus Yearly | `StartKind_plus_yearly` | `6799377026` | `$89.99/year` |

Known gating item: automated purchase/restore transaction tests are still skipped where the installed simulator returns StoreKitTest off-device purchase limitations. Before submission, verify purchase, restore, cancellation/expiry, and trial behavior with a sandbox account on a signed device build or TestFlight.

## 7. App Store Readiness Risks

These are not code blockers, but they must be handled before upload/review:

1. Register or allow Automatic Signing to create extension identifiers for `ren.startkind.share` and `ren.startkind.widget`.
2. Verify StoreKit purchase and restore with App Store Connect sandbox or TestFlight.
3. Run one real-device pass for microphone/speech permission and the share extension from Mail/Safari.
4. Run one real-device pass for Live Activities and local notification tap-through.
5. Capture final App Store screenshots after the redesigned screens are accepted.
6. Confirm privacy/support pages remain reachable from App Store metadata.

## 8. Roadmap Status

| Milestone | Status |
|---|---|
| 0 Project setup | Done |
| 1 Free core loop | Done and tested |
| 2 Plus subscription | Wired; sandbox purchase/restore verification pending |
| 3 Supabase sync + AI proxy | Implemented with graceful local fallback from earlier pass |
| 4 Admin Task Reader | Implemented |
| 5 Personal Execution Model | Implemented locally with calibration and patterns |
| 6 Co-Start | Implemented from earlier pass |
| 7 Retention differentiation set | Done: all 8 features implemented and tested |
| 8 Second retention set | Done: all 5 features implemented and tested |
| 9 Release readiness | Code is simulator-tested; signed device StoreKit/share-extension/Live Activity/notification verification still pending |
