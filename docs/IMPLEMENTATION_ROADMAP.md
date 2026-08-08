# Implementation Roadmap

Last updated: 2026-08-07

The project should be built as a complete iOS first release, but implementation should still happen in verifiable milestones. Android is deferred until after iOS market validation.

## Milestone 0: Project Setup

Deliverables:

- iOS native project
- Supabase project configuration
- Shared product docs
- Local build scripts
- CI plan

Acceptance:

- iOS builds in simulator.
- App opens to a simple Start screen on iOS.

## Milestone 1: Free Core Loop

Deliverables:

- Text capture
- Local voice input path
- One Next Step local templates
- Timer
- Make Smaller
- No-Shame Rescheduler
- Local 14-day history
- One active Recovery Capsule
- English and Simplified Chinese UI

Acceptance:

- User can go from messy input to one started timer in under 15 seconds.
- Skipped task produces smaller next step.
- No long list appears by default.

## Milestone 2: Plus Subscription

Deliverables:

- StoreKit 2 subscriptions
- Product IDs:
  - `StartKind_plus_monthly`
  - `StartKind_plus_yearly`
- Paywall
- Restore purchases
- Entitlement state

Acceptance:

- Monthly shows $9.99.
- Annual shows $89.99.
- Free limits work.
- Plus unlocks gated features.

## Milestone 3: Supabase Sync and AI Proxy

Deliverables:

- Auth
- User profile sync
- Task and timer sync
- Edge Function for AI
- Usage limits
- Entitlement checks

Acceptance:

- Free local use works without account.
- Plus sync works after sign-in.
- AI calls are blocked when entitlement or usage limit does not allow them.

## Milestone 4: Admin Task Reader

Deliverables:

- Pasted text parser
- Screenshot/photo parser
- Bill/email/appointment extraction
- One next step generation
- Confidence and missing info handling

Acceptance:

- A bill screenshot returns due date, amount where visible, and one next step.
- Missing info produces a small step to find it.

## Milestone 5: Personal Execution Model

Deliverables:

- Estimate multiplier by category
- Best start window insight
- Co-start impact
- Shrink-level personalization
- Tone preference

Acceptance:

- Repeated actual-time data changes future estimates.
- Insights are useful and non-shaming.

## Milestone 6: Co-Start

Deliverables:

- AI quiet co-start
- Friend invite link
- 25-minute room
- End check-in
- Guest flow without forced registration before joining

Acceptance:

- Host can invite friend from a task.
- Friend can join, state one step, and complete room flow.

## Milestone 7: Release Readiness

Deliverables:

- Privacy page
- Support/homepage page
- App Store metadata
- Screenshots
- Accessibility pass
- Subscription review pass

Acceptance:

- All mandatory tests pass.
- Privacy text matches actual data use.
- App Review subscription requirements are satisfied.

## Deferred: Android Expansion

Start only after explicit approval following iOS market validation.

Deliverables:

- Android native project
- Jetpack Compose implementation of the validated iOS core loop
- Google Play Billing subscriptions
- Play Store metadata
- Android emulator and device QA
