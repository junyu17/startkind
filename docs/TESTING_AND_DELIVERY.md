# Testing and Delivery Rules

Last updated: 2026-08-07

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
xcodebuild -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme StartKind -destination 'platform=iOS Simulator,name=iPhone 16' test
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

## Completion Report Format

Every delivery should include:

- Files changed
- Behavior implemented
- Tests run
- Tests not run and why
- Known risks or follow-ups
