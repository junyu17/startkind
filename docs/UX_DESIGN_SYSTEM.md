# UX and Design System

Last updated: 2026-08-07

## Design Goal

StartKind should feel quiet, clear, and immediately usable. It should not look like a project management dashboard, habit tracker, or gamified productivity app.

## First Screen

The first screen must center one action:

- Voice capture button
- Text capture field
- Current suggested next step, if any
- Start timer button

Avoid:

- Long task list as first screen
- Calendar grid as first screen
- Productivity score as first screen
- Streaks
- Red overdue warnings

## Navigation

Use simple bottom tabs:

1. Start
2. Recover
3. Patterns
4. Settings

The Start tab is the default.

## Core Screens

### Start

Purpose: turn current overwhelm into one next step.

Required elements:

- Large voice button
- Text input
- Category chips for Bills, Email, Appointment, Household, Work Admin
- One next step card
- Start timer button
- Make Smaller button

### Timer

Purpose: reduce initiation friction.

Required elements:

- Current step text
- Time remaining
- Pause
- Done
- Make Smaller
- Continue 5 minutes

Do not show unrelated tasks during a timer session.

### Recover

Purpose: restart after interruption.

Required elements:

- Last active capsule
- Resume one next step
- Related link or note
- Start timer button

### Patterns

Purpose: show useful insights without shame.

Allowed insights:

- "Email steps usually take longer than expected."
- "You start household tasks more often before noon."
- "Friend co-start helped you finish 3 of 4 recent admin steps."

Avoid:

- Percent failure labels
- "You are behind"
- Ranking the user
- Harsh progress charts

### Settings

Required:

- Language: English, Simplified Chinese
- Subscription status
- Privacy controls
- Data export
- Delete account
- Contact email: billy.yu@me.com

## Visual Style

Recommended:

- White or near-white background
- High-contrast text
- One calm accent color
- Large tap targets
- 8px radius or less for cards and controls unless platform conventions differ
- Clear iconography

Avoid:

- Heavy gradients
- Decorative blobs
- Overly cute mascot UI
- Dense dashboards
- Tiny text
- Red as default urgency color

## Copy Rules

Use:

- "Make it smaller"
- "Start 5 minutes"
- "Continue from here"
- "Try this version"
- "Stop after you find it"

Avoid:

- "Failed"
- "You missed"
- "You broke your streak"
- "Overdue"
- "No excuses"
- "Be disciplined"
- "Catch up"

## Accessibility

Required:

- Dynamic Type on iOS
- Font scaling on future Android
- VoiceOver and TalkBack labels
- Minimum 44pt iOS tap targets
- Minimum 48dp future Android tap targets
- Color contrast WCAG AA minimum
- No information conveyed by color alone

## Localization

Default strings must be authored in US English first.

Simplified Chinese should be natural and concise. Do not translate "ADHD" as a moral problem. Preferred Chinese term:

- ADHD: 注意缺陷多动障碍
- execution assistant: 执行助手
- next step: 下一步
- make smaller: 缩小一步
