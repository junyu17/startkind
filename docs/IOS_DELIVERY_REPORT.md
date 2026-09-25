# StartKind iOS - Delivery & QA Report

**Date:** 2026-08-10
**Platform:** iOS native, Swift 6, SwiftUI, SwiftData, StoreKit 2, Speech, WidgetKit, ActivityKit, UserNotifications
**Toolchain:** Xcode 26.6, Swift 6.3.3, iPhone 17 Simulator
**Status:** Core product plus 19 retention/differentiation features are implemented and simulator-tested. StoreKit purchase/restore still requires sandbox/device or TestFlight verification before App Store submission.

---

## 1. Summary

StartKind implements the adult ADHD execution loop:

**Capture -> One Next Step -> Timer -> Done/Partial/Skipped/Interrupted -> Calibrate -> Reschedule/Recover**

The app is local-first, native SwiftUI, English by default with Simplified Chinese available, and uses StoreKit 2 for Plus subscriptions. The first screen remains the Start flow, not a dashboard. The product still avoids punitive streaks, overdue stacks, and long generated task lists.

The latest pass adds the third retention set: Global Stuck Button, Yesterday Rescue, Energy Match, Friction Presets, Proof of Start, and Tiny Admin Inbox.

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
| Tests | 104 unit tests executed with 4 StoreKit simulator skips; 22 UI tests passed |
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
| Global Stuck Button | Done; persistent tab-shell button routes to smaller restart |
| Yesterday Rescue | Done; active recovery or yesterday unfinished step returns as a 3-minute restart |
| Energy Match | Done; low/medium/wired/overwhelmed adjusts step framing |
| Friction Presets | Done; common blockers produce immediate micro-steps |
| Proof of Start | Done; local "I started" store and counter without completion pressure |
| Tiny Admin Inbox | Done; pasted admin text is stored as one next-step card |

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
| Saved starts | Local reusable tiny-start snippets saved in UserDefaults by `PersonalVaultStore`, managed from Start and Settings | Unit and UI tests cover save/pick/delete flows and empty-state guidance |

## 5. Build & Test Results

Commands run after implementation:

```bash
cd /Users/jun/Documents/project/startkind
xcodegen generate
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:StartKindTests -parallel-testing-enabled NO
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:StartKindUITests -parallel-testing-enabled NO
```

Results:

| Check | Result |
|---|---|
| XcodeGen project generation | Passed |
| Debug simulator build | Passed |
| Focused new-feature unit + UI suite | Passed |
| Full unit suite | 104 tests executed, 4 StoreKit simulator skips, 0 failures |
| Full UI suite | 22 tests executed, 0 failures |

Latest unit `.xcresult`:
`/Users/jun/Library/Developer/Xcode/DerivedData/StartKind-hhzoqshjiqpuazedynrbbteaucjv/Logs/Test/Test-StartKind-2026.08.10_20-19-55--0700.xcresult`.

Latest UI `.xcresult`:
`/Users/jun/Library/Developer/Xcode/DerivedData/StartKind-hhzoqshjiqpuazedynrbbteaucjv/Logs/Test/Test-StartKind-2026.08.10_20-20-36--0700.xcresult`.

## 5.1 The 5 Added Features From This Pass

| Feature | Implementation | Verification |
|---|---|---|
| Autopilot Mode | Start page has "Tell me what to start now"; planner chooses active recovery first, then vault, then time-aware templates | Unit tests for priority rules; UI test `testAutopilotCreatesOneNextStep` |
| Return Note | Blocker picker includes an optional note; persisted with blocker in recovery metadata without adding a SwiftData field | Unit tests for metadata and legacy decode; UI test `testInterruptedReturnNoteAppearsInRecovery` |
| Friction Map | Patterns shows local blocker/category friction insights and suggested smaller doorway steps | Unit test `testFrictionMapReportsCommonBlocker`; UI renders under Patterns |
| Live Activity | Timer start/end routes through `LiveTimerActivityService`; `NSSupportsLiveActivities` is true | Debug build passes with ActivityKit |
| One-Tap Rescue Notification | Paused/interrupted/abandoned steps schedule no-shame local rescue notification with `startkind://rescue` | Unit test for rescue deep link; Debug build passes with UserNotifications delegate |

Agent delegation audit: per `/Users/jun/.codex/AGENTS.md`, code agents were tried in order. `opencode/deepseek-v4-flash-free` only read files and produced no edits; Pi `volc-coding/glm-5.2` produced no output before interruption; Reasonix `deepseek/deepseek-v4-flash` only read/analyzed and produced no edits. Final implementation and verification were completed here by Codex.

## 5.2 The 6 Added Features From This Pass

| Feature | Implementation | Verification |
|---|---|---|
| Global Stuck Button | Floating button in `RootView` sets a pending stuck restart and returns to Start | UI test `testRetentionControlsCreateStartableStep` |
| Yesterday Rescue | `YesterdayRescuePlanner` creates a 3-minute restart from active recovery or yesterday's unfinished step | Unit test `testYesterdayRescuePrefersActiveCapsule` |
| Energy Match | `EnergyMatcher` adapts proposals for low, medium, wired, and overwhelmed states | Unit test `testEnergyMatcherOverwhelmedShrinksToFrictionOnly` |
| Friction Presets | `FrictionPresetPlanner` maps common blockers to micro-steps | Unit + UI tests |
| Proof of Start | `ProofOfStartStore` records starts in local JSON and Start UI shows count | Unit + UI tests |
| Tiny Admin Inbox | `TinyAdminInboxStore` keeps pasted admin text plus one proposal card | Unit test; Start UI entry present |

OpenCode audit for this pass: standard OpenCode mode was configured correctly but stalled in repo plugin/context exploration. `--pure` mode was verified with a repo write probe and then used to create `RetentionFeatureKit.swift` and `RetentionFeatureTests.swift`; Codex performed integration, review, and testing.

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
| 9 Third retention set | Done: all 6 features implemented and tested |
| 10 Release readiness | Code is simulator-tested; signed device StoreKit/share-extension/Live Activity/notification verification still pending |
