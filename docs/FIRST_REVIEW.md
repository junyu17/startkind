# First Review

Date: 2026-08-07

Scope: iOS-first market validation release. Android is deferred until after iOS validation.

## Result

The iOS app is not ready for App Store submission yet, but the core local execution loop is now in better shape after this review. I found and fixed issues that would have made the previous "70 tests pass" report misleading.

## Findings Fixed During Review

### P1: Timer "Make it smaller" did not actually shrink the step

`TimerView` returned `.paused`, but `StartView` only saved a recovery capsule and message. The current step was not downgraded before recovery. This violated the product promise that paused or avoided work is automatically reduced without shame.

Fixed in:

- `StartKind/UI/Start/StartView.swift`
- `StartKind/UI/Recover/RecoverView.swift`
- `StartKindTests/PersistenceServiceTests.swift`

### P1: SwiftData migration could crash after adding required fields

New model fields for recovery/admin metadata initially had no defaults. Existing local stores could not migrate and the app hit the storage `fatalError` path on launch.

Fixed in:

- `StartKind/Models/PersistenceModels.swift`

### P2: Recovery and Admin Task persistence lost important step metadata

`RecoveryCapsuleModel.resumeProposal` always rebuilt with `shrinkLevel: .zero`. `AdminArtifactModel.oneNextStep` always rebuilt with category `.other` and shrink level `.zero`. That would corrupt recovery behavior and personal execution data.

Fixed in:

- `StartKind/Models/PersistenceModels.swift`
- `StartKind/Services/PersistenceService.swift`

### P2: UI tests were not isolated from prior language/data state

The UI test run inherited a Simplified Chinese UI state from prior app usage and used persistent app data. One tab-switching test also passed without actually verifying localized tab labels.

Fixed in:

- `StartKind/App/StartKindApp.swift`
- `StartKindUITests/StartKindUITests.swift`

### P2: Project docs still described simultaneous iOS and Android delivery

This conflicted with the current launch plan: ship iOS first, validate market, then consider Android.

Fixed in:

- `README.md`
- `AGENTS.md`
- `PROJECT_BRIEF_FOR_AI.md`
- `docs/PRODUCT_REQUIREMENTS.md`
- `docs/TECHNICAL_ARCHITECTURE.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/SUBSCRIPTION_STRATEGY.md`
- `docs/TESTING_AND_DELIVERY.md`
- `docs/UX_DESIGN_SYSTEM.md`
- `docs/DATA_MODEL.md`

## Remaining App Store Blockers

1. Confirm App Store Connect bundle ID matches `com.startkind.app` for Apple App ID `6799113108`.
2. Sandbox-test StoreKit purchases, restore, expiry, grace period, and trial eligibility.
3. Complete App Store screenshots.
4. Run a real-device pass for microphone/speech permission and small-screen layout.
5. Decide whether Supabase/AI features stay stubbed for v1 or are implemented before submission.

Subscription products now recorded:

| Plan | Apple ID | Product ID | Price |
|---|---:|---|---:|
| StartKind Plus Monthly | 6799376244 | `StartKind_plus_monthly` | $9.99/month |
| StartKind Plus Annual | 6799377026 | `StartKind_plus_yearly` | $89.99/year |

## Verification

Current addendum, 2026-08-08:

- Non-StoreKit suite: 80 unit tests + 8 UI tests passed.
- StoreKit local suite: 5 tests executed; 1 free-state test passed; 4 product/purchase/restore test methods failed because `SKTestSession` could not activate `Products.storekit` (`SKInternalErrorDomain Code=3`).

Command:

```bash
xcodebuild test -project /Users/jun/Documents/project/startkind/StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /Users/jun/Documents/project/startkind/build
```

Result:

- Unit tests: 66 passed
- UI tests: 5 passed
- Total: 71 passed
- Final result: `** TEST SUCCEEDED **`

## Notes

The project directory is on a case-insensitive filesystem, so `/Users/jun/Documents/project/startkind` and `/Users/jun/Documents/Project/startkind` resolve to the same location. The canonical path in docs should be lowercase `project`.
