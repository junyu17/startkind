# StartKind Product Requirements

Last updated: 2026-08-09

## Problem

Many adults with ADHD or executive function difficulties know what they should do but cannot reliably start, restart, or finish life admin tasks. Traditional task apps often increase pressure by showing long lists, overdue states, streak loss, and planning demands.

StartKind exists to reduce the distance between overwhelm and action.

## Platform Strategy

StartKind should launch on iOS first. Android is intentionally deferred until iOS market validation. Do not spend first-release scope on Android implementation, Google Play Billing, Play Store metadata, or Android-specific QA unless explicitly requested later.

## Target Users

Primary:

- Adults in the United States with diagnosed ADHD, suspected ADHD, or recurring executive function problems.
- Users overwhelmed by bills, email, appointments, returns, insurance, banking, household chores, family admin, work follow-ups, and paperwork.

Secondary:

- Partners, caregivers, coaches, therapists, or friends who support someone with execution difficulty.

## Core Promise

When a user says, "I am a mess today," StartKind gives one small action they can begin in 5 to 15 minutes.

## Product Principles

1. One step first.
2. Startability beats priority.
3. Shrink tasks after avoidance.
4. Calibrate time from reality, not guesses.
5. Restart without shame.
6. Co-start when alone is too hard.
7. Hide complexity until requested.

## Must-Have Feature Set

### 1. Overwhelm Capture

Input modes:

- Voice
- Text
- Quick category button
- Screenshot/photo for Plus

Output:

- One next step
- Estimated start time
- Timer button
- Optional "make smaller" button
- Optional "show plan" expansion

The default output must never be a long list.

### 2. One Next Step Engine

The engine converts messy user input into a concrete action:

- Starts with a verb
- Can be done in 5 to 15 minutes
- Requires minimal decisions
- Avoids vague language such as "organize," "handle," "deal with," or "catch up"
- Includes a stop condition

Example:

User: "I need to deal with my insurance bill and I have been avoiding it."
Bad: "Review your insurance bill and make a payment plan."
Good: "Open the insurance email and find the due date. Stop there."

### 3. No-Shame Rescheduler

When a user skips, delays, or misses a step:

- Do not say "failed."
- Do not show broken streaks.
- Do not stack missed tasks.
- Offer a smaller step.

Example:

"This step may be too large right now. Try the 3-minute version: search your inbox for 'insurance' and stop."

### 4. Time Calibration

The app records:

- User estimate
- Actual elapsed time
- Completion status
- Task category
- Time of day
- Whether co-start was used

The app learns personal multipliers:

- Email multiplier
- Bill multiplier
- Appointment multiplier
- Household multiplier
- Work admin multiplier

### 5. Recovery Capsule

When a user returns after interruption, the app shows:

- Last active task
- Last completed substep
- One next step to resume
- Relevant notes, links, or draft text

Free: one active recovery capsule.
Plus: unlimited recovery history.

### 6. Admin Task Reader

Plus feature. Turns email, screenshots, pasted text, or photos into:

- Due date
- Amount
- phone number or URL
- Documents needed
- First step
- Suggested time block

Categories:

- Bills
- Appointments
- Insurance
- Banking
- Returns
- School or child admin
- Rent and utilities
- Medical forms
- Household repair

### 7. Co-Start

Modes:

- AI quiet co-start
- Friend invite link for 25 minutes
- Optional quiet room with minimal status

Room flow:

1. Each person states one small step.
2. Timer starts.
3. Room stays quiet.
4. End check-in asks: done, continue, or make smaller.

Friend invite must work from a link without forcing registration before joining.

### 8. Personal Execution Model

Plus feature. Builds a private profile of how the user starts work:

- Best start windows
- Task categories with high avoidance
- Typical estimate error
- Preferred step size
- Helpful tone
- Co-start impact
- Interruption patterns
- Restart success patterns

This model should improve outputs over time.

## Free Feature Scope

Free is not a crippled demo. It must be useful every day with low operating cost.

Free includes:

- 5 One Next Step generations per day
- Text input
- Voice input where local OS dictation can be used
- Local task shrinker templates
- Local micro-templates for bills, email, appointments, documents, home reset, and bad-day reset
- Bad Day Mode for overwhelm phrases such as "I'm overwhelmed" or "我今天一团乱"
- 5, 10, 15, and 25 minute start timers
- "I got interrupted" timer action
- Blocker capture after interruption, partial completion, or pause
- No-Shame Rescheduler
- Local actual-time history for 14 days
- One active Recovery Capsule
- Local Personal Vault for reusable tiny-start snippets
- Shareable Start Card
- Start widget and iOS share extension entry points
- One Admin Quick Start per day
- Default English and optional Simplified Chinese

Free excludes:

- Unlimited AI usage
- Screenshot/photo analysis
- Email or calendar integration
- Cross-device cloud sync
- Unlimited recovery history
- Friend co-start links
- Advanced Personal Execution Model

## Plus Feature Scope

StartKind Plus includes:

- Unlimited One Next Step
- Deep AI task parsing
- Voice-first overwhelm capture
- Calendar sync
- Email, pasted text, screenshot, and photo parsing
- Admin Task Reader
- Personal Time Calibration
- Personal Execution Model
- Unlimited Recovery Capsules
- AI quiet co-start
- Friend co-start links
- Cross-device sync
- Advanced insights
- Family or partner shared support controls

## MVP Avoidance

This project should not stop at a minimal MVP. The first public release should feel complete around the core execution loop:

Capture -> One Step -> Timer -> Done/Not Done -> Calibrate -> Reschedule or Recover.

Do not add broad project management until this loop is excellent.

## Retention and Differentiation Set

The first iOS release includes these non-MVP retention features:

1. I Got Interrupted: a timer exit that preserves context without shame.
2. Blocker Picker: records why the start broke down so future recovery can improve.
3. Bad Day Mode: overwhelm phrases immediately produce one tiny 5-minute reset step.
4. Share Extension: capture text or URLs into StartKind from other iOS apps.
5. Micro-Templates: local, no-cost tiny-start flows for recurring adult-admin tasks.
6. Widget: quick return to Start from the Home Screen.
7. Shareable Start Card: natural encouragement sharing without exposing private history.
8. Personal Vault: local reusable next-step snippets that help repeat users start faster.
9. Autopilot Mode: one button chooses a locally sensible next start without planning.
10. Return Note: interrupted users can leave one short clue for resuming.
11. Friction Map: blocker and timing history become non-shaming restart insights.
12. Live Activity: the active timer can stay visible on the Lock Screen where supported.
13. One-Tap Rescue Notification: a no-shame notification opens the smallest restart.
