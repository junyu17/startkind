# StartKind Supabase Backend (Milestone 3)

Cloud sync, AI proxy, and entitlement mirroring for StartKind Plus.

> **Status (2026-08-07):** Deployed to project `yekmovuqakbekfmgtuvj`.
> - DB migrations applied (`supabase db push`) - 11 tables + RLS live.
> - Edge Functions `one_next_step` and `admin_task_reader` deployed; JWT auth
>   enforced (verified: 401 without token), CORS working.
> - `SUPABASE_URL`/`SUPABASE_ANON_KEY` auto-injected by the platform.
> - **AI provider: DeepSeek** (`deepseek-chat`) via OpenAI-compatible endpoint.
>   Secrets set: `OPENAI_API_KEY`, `AI_ENDPOINT`, `AI_MODEL`. Email OTP
>   confirmation disabled (sign-up returns a session immediately).
> - **End-to-end verified (backend + in-app):** real user JWT -> `one_next_step`
>   -> DeepSeek -> valid next-step JSON, ~2.7–4.7s/call (Supabase West-US <->
>   DeepSeek). English + Simplified Chinese both return correct, low-shame steps
>   with valid `category` and `shrink_level=0`.
> - **iOS auth complete:** `AuthView` (sign in / sign up / skip-local) + token
>   persistence + Settings account section. UI test `testCloudSignUpAndStep`
>   verifies the full in-app cloud loop (sign-up -> capture -> DeepSeek step).
> - iOS `Secrets.plist` wired (URL + publishable key in bundle, git-ignored).
>
> **Cloud AI is fully usable from the app.** Token auto-refresh is implemented
> (persistent login). `verify_receipt` Edge Function is deployed (server-side
> Apple receipt verification -> `entitlements`); `APPLE_SHARED_SECRET` is set.
> Full bidirectional sync (8 entities, LWW; `next_steps` status syncs via
> `updated_at` - migration 0003) runs after login. Co-Start guest join uses
> anonymous auth (migration 0004 RLS; room members see each other) + 3s polling.
> Migrations 0001-0004 applied. Remaining: websocket realtime (vs polling),
> incremental sync, and StoreKit sandbox verification on a real device (user-gated).

## Contents

- `migrations/0001_startkind_init.sql` - 10 tables + `entitlements`, RLS policies, triggers.
- `migrations/0002_ai_usage.sql` - daily AI usage counter (server-side Free limit).
- `functions/one_next_step/index.ts` - AI proxy: messy input -> one next step JSON.
- `functions/admin_task_reader/index.ts` - Plus: extract bill/email/appointment facts.
- `functions/_shared/cors.ts` - CORS + JSON helpers.
- `config.toml` - function config (JWT verification enforced).

## What you need to do (requires your confirmation)

These steps touch a live Supabase project and paid AI keys, so they need you:

1. **Create/link a Supabase project**
   ```bash
   npm i -g supabase          # if not installed
   supabase login
   supabase link --project-ref <YOUR_PROJECT_REF>
   ```
2. **Apply the database schema** (production DB migration - needs your OK)
   ```bash
   supabase db push
   ```
3. **Deploy Edge Functions**
   ```bash
   supabase functions deploy one_next_step
   supabase functions deploy admin_task_reader
   ```
4. **Set secrets** (never commit these)
   ```bash
   supabase secrets set SUPABASE_URL=https://<ref>.supabase.co \
                  SUPABASE_ANON_KEY=<anon_key> \
                  OPENAI_API_KEY=<your_openai_key> \
                  AI_MODEL=gpt-4o-mini
   ```
   Optional: `AI_ENDPOINT` to point to an OpenAI-compatible provider.
5. **Wire the iOS app** - put your project URL + anon key into `SupabaseConfig`
   (see `StartKind/Services/SupabaseConfig.swift`). The app activates cloud sync/AI
   only when these are set; otherwise it stays local.
6. **Entitlement mirroring** - after StoreKit/Play validation, write the user's
   `entitlements` row (via a secure webhook or the receipt-validation Edge Function).
   This is the cross-device source of truth the Edge Functions check.

## Security notes (per docs/PRIVACY_REQUIREMENTS.md)

- RLS is enabled on every table; users can only read/write their own rows.
- `ai_usage` and `entitlements` writes happen server-side (service role), not from the app.
- The app never holds the service-role key. AI keys live only in Edge Function secrets.
- Sensitive task content is scoped to the user's account; screenshots/photos are
  uploaded only for active parsing with explicit user acceptance.

## Local development

```bash
supabase start                 # local Supabase stack
supabase db reset              # apply migrations locally
supabase functions serve       # serve Edge Functions locally
```

## Not yet implemented (follow-ups)

- iOS sign-in UI (email/password or anonymous) + session storage.
- Bi-directional change sync (conflict resolution) beyond basic upsert/fetch.
- Receipt-validation Edge Function for App Store / Play entitlement verification.
- Co-Start real-time room transport (Milestone 6).
