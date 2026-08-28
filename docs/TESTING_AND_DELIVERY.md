# Testing and Delivery Rules

Last updated: 2026-08-09

Every code change must be self-reviewed and tested before delivery.

## Universal Delivery Checklist

Before reporting completion:

1. Re-read the latest user request.
2. Confirm the implementation matches the requested behavior.
3. Scan nearby code for the same class of issue.
4. Run formatter/linter where configured.
5. Run relevant unit tests.
6. Run relevant build command.
7. Manually verify the changed user flow when UI is affected.
8. Report what passed and what was not run.

## iOS Required Checks

Use the actual scheme name once the Xcode project exists.

Minimum:

```bash
xcodebuild -list
xcodegen generate
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:StartKindTests
xcodebuild -project StartKind.xcodeproj -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:StartKindUITests
```

For subscription work:

- Test StoreKit configuration locally.
- Verify monthly and annual product IDs.
- Verify restore purchases.
- Verify expired entitlement UI.

For UI work:

- Test small iPhone.
- Test large iPhone.
- Test Dynamic Type.
- Check VoiceOver labels for primary buttons.

For extension work:

- Run `xcodegen generate` before building.
- Confirm extension `Info.plist` files contain `NSExtension`.
- Build the main app scheme so embedded extensions are installed.
- Test the share extension from at least Safari or Mail on a signed device before submission.
- Confirm the widget opens `startkind://start`.

For Live Activity and rescue notification work:

- Confirm `NSSupportsLiveActivities` is true in the generated app `Info.plist`.
- Build on simulator to verify ActivityKit/UserNotifications compile.
- Test timer Live Activity start/end on a signed physical device.
- Test local notification authorization and `startkind://rescue` tap-through on a signed physical device.

## Future Android Required Checks

Android is deferred until after iOS market validation. Use these actual Gradle tasks once Android work is explicitly started and the Android project exists.

Minimum:

```bash
./gradlew tasks
./gradlew ktlintCheck
./gradlew testDebugUnitTest
./gradlew assembleDebug
```

For subscription work:

- Verify BillingClient product IDs.
- Verify purchase restore.
- Verify expired entitlement UI.

For UI work:

- Test compact phone emulator.
- Test large phone emulator.
- Test font scaling.
- Check TalkBack labels for primary buttons.

## Backend Required Checks

For Supabase Edge Functions:

```bash
supabase functions serve
supabase db diff
supabase db lint
```

Before production deploy:

- Inspect environment variables.
- Confirm no service-role key is in client code.
- Run a remote smoke test after deploy.
- Confirm AI usage limits and entitlement checks.

## AI Behavior Tests

Every AI prompt or NextStepEngine change must test:

- Messy overwhelm input
- Bill task
- Email task
- Appointment task
- Household task
- Skipped task shrink flow
- Chinese locale response
- Medical boundary response

Expected:

- One next step by default.
- No long list unless explicitly requested.
- No shame language.
- Includes stop condition.
- Estimated time is 5 to 15 minutes unless shrink level requires less.

## Retention Feature Tests

The iOS suite should cover:

- Energy Match shrinks overwhelmed/low-energy starts.
- Friction Presets create startable 5-minute or smaller steps.
- Proof of Start persists and counts starts without completion.
- Tiny Admin Inbox stores only one next-step card from pasted admin text.
- Yesterday Rescue returns a 3-minute restart.
- Start Ladder creates 2-, 5-, and 15-minute versions without mutating the source step.
- Action Prep recognizes email, telephone, and website destinations without performing an action automatically.
- Daily One Thing persists one selection for the day and can be replaced or dismissed.
- Start Profile only uses observed timer samples and does not output a score or diagnosis.
- Urgent Admin Mode stays neutral and directs the user to the original sender or provider.
- Co-Start Continuity persists only an optional local display label and room code.
- Stuck button remains in the Start screen's first viewport, above the More ways to start disclosure.
- Free friend co-start invite path is one successful invite per rolling 7-day window; Plus is unlimited.
- Joining by six-digit room code remains free and does not require registration.

### Co-Start Boundary Manual Checks

- Open Start with an existing generated step and create one friend co-start in free mode.
- Confirm second free attempt presents paywall without creating a room.
- Fast-forward the stored co-start window start by 8+ days and confirm another free create is allowed.

## Manual Smoke Test Script

Run this before any milestone delivery:

1. Open app fresh.
2. Enter: "I'm a mess today and I need to deal with bills."
3. Confirm app returns one next step.
4. Start 5-minute timer.
5. Mark partial.
6. Confirm app offers smaller restart, not failure.
7. Leave and reopen app.
8. Confirm Recovery Capsule appears.
9. Switch language to Simplified Chinese.
10. Repeat one text capture.
11. Confirm UI remains readable and uncluttered.
12. Tap "I'm stuck" in the Start first viewport and confirm a smaller start is ready.
13. Tap a friction preset and confirm one startable step appears.
14. Tap "I started" and confirm the proof counter updates without requiring completion.

## Completion Report Format

Every delivery should include:

- Files changed
- Behavior implemented
- Tests run
- Tests not run and why
- Known risks or follow-ups
