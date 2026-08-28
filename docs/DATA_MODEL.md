# Data Model

Last updated: 2026-08-07

This model is implemented locally on iOS with SwiftData. The eight personal
entities sync across the user's own devices via CloudKit; co-start rooms are
server state and stay in a separate local-only store. Nothing personal is held
on our backend. Future Android should mirror this model after iOS market
validation.

## Core Entities

### UserProfile

- id
- locale
- timezone
- entitlement_state
- preferred_tone
- created_at
- updated_at

### Capture

- id
- user_id
- source_type: voice, text, screenshot, photo, email, calendar, manual
- raw_text
- language
- created_at

### TaskItem

- id
- user_id
- capture_id
- title
- category
- emotional_load: low, medium, high
- status: active, completed, paused, deferred, archived
- created_at
- updated_at

### NextStep

- id
- task_id
- text
- estimated_minutes
- target_minutes
- shrink_level
- status: suggested, started, completed, skipped, paused
- generated_by: local_template, cloud_ai, user
- created_at
- started_at
- completed_at

### TimerSession

- id
- next_step_id
- planned_minutes
- actual_seconds
- outcome: completed, partial, paused, abandoned
- co_start_mode: none, ai, friend, quiet_room
- created_at
- ended_at

### TimeCalibrationProfile

- id
- user_id
- category
- estimate_multiplier
- median_actual_minutes
- completion_rate
- best_start_window
- sample_count
- updated_at

### RecoveryCapsule

- id
- user_id
- task_id
- last_step_id
- state_summary
- resume_step_text
- related_link
- related_draft
- active
- created_at
- updated_at

### AdminArtifact

- id
- user_id
- task_id
- artifact_type: bill, email, appointment, return, insurance, banking, school, household, medical, other
- extracted_due_date
- extracted_amount
- extracted_contact
- extracted_url
- required_documents
- confidence
- created_at

### CoStartRoom

- id
- host_user_id
- room_type: friend_link, ai_quiet, quiet_room
- duration_minutes
- status: scheduled, active, ended, cancelled
- invite_token_hash
- created_at
- starts_at
- ended_at

### CoStartParticipant

- id
- room_id
- user_id_nullable
- display_name
- stated_step
- outcome
- joined_at
- left_at

## Categories

Use stable internal category IDs:

- bills
- email
- appointments
- returns
- insurance
- banking
- taxes
- household
- family_admin
- medical
- work_admin
- school
- cleaning
- errands
- other

## Sync Rules

Free:

- Local-only by default.
- No account required.

Plus:

- Sync UserProfile, TaskItem, NextStep, TimerSession, TimeCalibrationProfile, RecoveryCapsule, AdminArtifact, and CoStart metadata.
- Do not sync raw screenshots/photos unless required for active parsing and accepted by the user.
