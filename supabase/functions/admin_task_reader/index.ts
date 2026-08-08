import { corsHeaders, handleOptions, json } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// System prompt mirrors prompts/admin_task_reader_system.md
const SYSTEM_PROMPT = `You are StartKind's Admin Task Reader. Extract only the information needed to help the user start one administrative task.

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

const PLUS_STATES = new Set(["plus_trial", "plus_active", "plus_grace_period"]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return handleOptions();
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    // Admin Task Reader is a Plus feature.
    const { data: ent } = await supabase
      .from("entitlements").select("state").eq("user_id", user.id).maybeSingle();
    const state = ent?.state ?? "free";
    if (!PLUS_STATES.has(state)) {
      return json({ error: "plus_required" }, 402);
    }

    const body = await req.json().catch(() => ({}));
    const { text, language } = body ?? {};
    if (!text || typeof text !== "string") return json({ error: "bad_request" }, 400);

    const aiKey = Deno.env.get("OPENAI_API_KEY");
    if (!aiKey) return json({ error: "ai_not_configured" }, 503);

    const userPrompt = `Language: ${language ?? "en"}\nText to parse:\n${text}`;
    const result = await callAI(aiKey, SYSTEM_PROMPT, userPrompt);
    return json(result, 200);
  } catch (e) {
    return json({ error: "server_error", detail: String(e) }, 500);
  }
});

async function callAI(apiKey: string, system: string, user: string): Promise<Record<string, unknown>> {
  const model = Deno.env.get("AI_MODEL") ?? "gpt-4o-mini";
  const endpoint = Deno.env.get("AI_ENDPOINT") ?? "https://api.openai.com/v1/chat/completions";
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
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
  try {
    return JSON.parse(content);
  } catch {
    throw new Error(`AI returned non-JSON: ${content}`);
  }
}
