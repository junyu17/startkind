import { query, one } from "./db.ts";
import { Device } from "./auth.ts";

const FREE_DAILY_LIMIT = 5;
const PLUS_STATES = new Set(["plus_trial", "plus_active", "plus_grace_period"]);

const NEXT_STEP_SYSTEM_PROMPT = `You are StartKind, an execution assistant for adults who struggle to start tasks. Your job is to convert messy input into one small action the user can begin now.

Rules:
- Return exactly one next step unless the user explicitly asks for a plan.
- The step must be concrete, physical or screen-based, and startable in 5 to 15 minutes.
- Include a clear stop condition.
- Use neutral, kind, adult language.
- Do not diagnose, treat, or provide medication advice.
- Do not shame the user.
- Do not mention streaks, failure, discipline, laziness, or willpower.
- Avoid long explanations.
- "category" must be one of: bills, email, appointments, returns, insurance, banking, taxes, household, family_admin, medical, work_admin, school, cleaning, errands, other.
- "shrink_level" is 0 for a fresh first step (the user shrinks later).

Output JSON:

{
  "title": "",
  "step": "",
  "timer_minutes": 0,
  "stop_condition": "",
  "category": "",
  "shrink_level": 0,
  "why_this_step": ""
}`;

const ADMIN_PARSE_SYSTEM_PROMPT = `You are StartKind's Admin Task Reader. Extract only the information needed to help the user start one administrative task.

Rules:
- Prioritize one next step over full planning.
- If data is missing, ask for the smallest possible action to find it.
- Do not expose private information unnecessarily.
- Do not provide legal, medical, tax, or financial advice.
- Do not tell the user whether to pay, dispute, or ignore a bill. Help them find the relevant facts and next action.

Output JSON:

{
  "artifact_type": "",
  "due_date": null,
  "amount": null,
  "contact": null,
  "link_or_phone": null,
  "required_documents": [],
  "one_next_step": {
    "title": "",
    "step": "",
    "timer_minutes": 0,
    "stop_condition": ""
  },
  "confidence": 0,
  "missing_info": []
}`;

type ResponseBody =
  | { error: string }
  | Record<string, unknown>;

type Response<T> = {
  status: number;
  body: T;
};

async function callModel(
  system: string,
  user: string
): Promise<Record<string, unknown>> {
  const apiKey = Deno.env.get("AI_API_KEY");
  if (!apiKey) throw new Error("AI_API_KEY not set");

  const model = Deno.env.get("AI_MODEL") ?? "deepseek-chat";
  const endpoint =
    Deno.env.get("AI_ENDPOINT") ?? "https://api.deepseek.com/v1/chat/completions";

  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
      response_format: { type: "json_object" },
      temperature: 0.4,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`AI request failed: ${res.status} ${text}`);
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content ?? "{}";

  try {
    return JSON.parse(content);
  } catch {
    throw new Error(`AI returned non-JSON: ${content}`);
  }
}

export async function nextStep(
  device: Device,
  body: {
    input?: unknown;
    language?: unknown;
    calibrationMultiplier?: unknown;
  }
): Promise<Response<ResponseBody>> {
  // Validate input before counting usage
  if (!body.input || typeof body.input !== "string") {
    return { status: 400, body: { error: "bad_request" } };
  }

  const safeInput = (body.input as string).slice(0, 4000);

  // Check free tier usage
  if (!PLUS_STATES.has(device.entitlement)) {
    const today = new Date().toISOString().slice(0, 10);
    const rows = await query<{ count: number | bigint }>(
      "SELECT COUNT(*) as count FROM ai_usage WHERE device_id = $1 AND day = $2",
      [device.id, today]
    );
    // Postgres COUNT(*) is bigint; the driver may hand back a BigInt.
    const count = Number(rows[0]?.count ?? 0);

    if (count >= FREE_DAILY_LIMIT) {
      return { status: 402, body: { error: "limit_reached" } };
    }
  }

  // Check API key
  if (!Deno.env.get("AI_API_KEY")) {
    return { status: 503, body: { error: "ai_not_configured" } };
  }

  // Call model
  const userPrompt = `Language: ${body.language ?? "en"}\nCalibration multiplier: ${body.calibrationMultiplier ?? 1}\nUser input:\n${safeInput}`;
  const result = await callModel(NEXT_STEP_SYSTEM_PROMPT, userPrompt);

  // Record usage after successful call
  const today = new Date().toISOString().slice(0, 10);
  await query(
    "INSERT INTO ai_usage (device_id, day, endpoint) VALUES ($1, $2, $3)",
    [device.id, today, "one_next_step"]
  );

  return { status: 200, body: result };
}

export async function adminParse(
  device: Device,
  body: { text?: unknown; language?: unknown }
): Promise<Response<ResponseBody>> {
  // Plus only
  if (!PLUS_STATES.has(device.entitlement)) {
    return { status: 402, body: { error: "plus_required" } };
  }

  // Validate text
  if (!body.text || typeof body.text !== "string") {
    return { status: 400, body: { error: "bad_request" } };
  }

  const safeText = (body.text as string).slice(0, 4000);

  // Check API key
  if (!Deno.env.get("AI_API_KEY")) {
    return { status: 503, body: { error: "ai_not_configured" } };
  }

  // Call model with different temperature for admin parse
  const userPrompt = `Language: ${body.language ?? "en"}\nText to parse:\n${safeText}`;

  const apiKey = Deno.env.get("AI_API_KEY");
  if (!apiKey) throw new Error("AI_API_KEY not set");

  const model = Deno.env.get("AI_MODEL") ?? "deepseek-chat";
  const endpoint =
    Deno.env.get("AI_ENDPOINT") ?? "https://api.deepseek.com/v1/chat/completions";

  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: ADMIN_PARSE_SYSTEM_PROMPT },
        { role: "user", content: userPrompt },
      ],
      response_format: { type: "json_object" },
      temperature: 0.2,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`AI request failed: ${res.status} ${text}`);
  }

  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content ?? "{}";

  let result: Record<string, unknown>;
  try {
    result = JSON.parse(content);
  } catch {
    throw new Error(`AI returned non-JSON: ${content}`);
  }

  return { status: 200, body: result };
}
