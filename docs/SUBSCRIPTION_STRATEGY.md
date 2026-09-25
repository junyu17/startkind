# Subscription Strategy

Last updated: 2026-08-08

## Final Pricing

- Free: $0
- StartKind Plus Monthly: $9.99/month
- StartKind Plus Annual: $89.99/year
- Trial: 7 days
- Lifetime: not offered

## Why Free + Plus Only

The target user already struggles with planning and decision load. Three pricing tiers create avoidable friction and overlap. A two-tier model is clearer:

- Free: daily useful execution support.
- Plus: complete personal execution system.

## Free Strategy

Free should increase retention without increasing server costs materially.

Free should rely on:

- Local templates
- Local timers
- Local history
- Private iCloud sync through the user's private CloudKit database
- Local quiet co-start
- Basic Start Profile
- Saved starts (stored locally by `PersonalVaultStore`)
- Local OS speech-to-text where available
- Limited daily AI calls

Free limits:

- 5 One Next Step generations per day
- One Admin Quick Start per day
- One Friend co-start invite per rolling 7 days
- 14 days local history
- One active Recovery Capsule

Free limits and exclusions:

- Additional Admin Quick Starts beyond the daily allowance; the daily Free Admin Quick Start includes photo OCR
- Advanced execution insights and history beyond 14 days
- Unlimited AI calls
- Unlimited Friend co-start room creation (1 per rolling 7 days)

## Plus Strategy

Plus sells the complete system:

- Unlimited daily starts
- Unlimited Admin Quick Start, including photo OCR
- Unlimited active Recovery Capsules
- Unlimited Friend co-start room creation
- Advanced execution insights and history beyond 14 days

## Paywall Moments

Good paywall moments:

- User reaches daily One Next Step limit.
- User reaches the daily Admin Quick Start allowance and wants another Admin Quick Start or photo scan.
- User wants unlimited recovery capsules.
- User wants to invite a friend to co-start.
- User asks for personal patterns or advanced insights.

Bad paywall moments:

- Before first useful step.
- When user is emotionally overwhelmed.
- Immediately after a missed task.
- On basic language selection.
- On basic timer usage.

## Store Copy

Short description:

StartKind helps adults with ADHD turn overwhelm into one small next step.

Long positioning:

StartKind is an execution assistant for adults who know what needs to be done but struggle to begin. Speak your messy thoughts, get one small step, start a timer, and recover without shame if you get stuck.

## Subscription Product IDs

Use these for App Store Connect. Future Play Console product IDs should mirror them unless Google Play constraints require changes:

| Plan | Apple ID | Product ID | Price | Billing Period |
|---|---:|---|---:|---|
| StartKind Plus Monthly | 6799376244 | `StartKind_plus_monthly` | $9.99 | Monthly |
| StartKind Plus Annual | 6799377026 | `StartKind_plus_yearly` | $89.99 | Annual |
