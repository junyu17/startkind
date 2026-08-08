# Privacy Requirements

Last updated: 2026-08-07

Public contact email: billy.yu@me.com

## Principles

- Collect the minimum data needed.
- Free mode should work without account creation.
- Explain cloud features before uploading sensitive content.
- Do not use shame-sensitive task content for advertising.
- Provide delete account and data export.

## Data Categories

Possible data:

- Task text
- Voice transcription
- Timer history
- Completion state
- Calendar metadata if connected
- Email/pasted text/screenshot/photo content if user invokes Admin Task Reader
- Subscription entitlement
- Device diagnostics

## User Controls

Required:

- Delete local data
- Delete cloud account
- Export user data
- Disconnect calendar
- Disconnect email
- Disable AI cloud processing where possible

## Sensitive Content Handling

Administrative tasks may contain financial, medical, family, school, and account information.

Rules:

- Do not log raw sensitive content in production.
- Redact diagnostics.
- Use secure transport.
- Keep service-role keys server-side only.
- Avoid broad third-party analytics on raw task content.

