import { deviceForToken, registerDevice } from "./auth.ts";
import { nextStep, adminParse } from "./ai.ts";
import { createRoom, joinRoom, participants, endRoom, setOutcome } from "./costart.ts";
import { verifyTransaction } from "./transaction.ts";

type JsonValue = string | number | boolean | null | unknown[] | { [key: string]: unknown };

function json(body: JsonValue, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function parseJson<T = Record<string, unknown>>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch {
    return {} as T;
  }
}

function parseUrl(url: string): { pathname: string; method: string } {
  return {
    pathname: new URL(url).pathname,
    method: url.split(" ")[0],
  };
}

Deno.serve(
  { port: Number(Deno.env.get("PORT") ?? 8080) },
  async (req: Request): Promise<Response> => {
    const url = new URL(req.url);
    const pathname = url.pathname;
    const method = req.method;

    try {
      // Health check
      if (pathname === "/health" && method === "GET") {
        return json({ ok: true }, 200);
      }

      // Register device (no auth required)
      if (pathname === "/v1/device/register" && method === "POST") {
        const { token, device } = await registerDevice();
        return json({ token, entitlement: device.entitlement }, 200);
      }

      // All other routes require auth
      const device = await deviceForToken(req.headers.get("Authorization"));
      if (!device) {
        return json({ error: "unauthorized" }, 401);
      }

      // Next step
      if (pathname === "/v1/next-step" && method === "POST") {
        const body = await parseJson(req);
        const result = await nextStep(device, body);
        return json(result.body, result.status);
      }

      // Admin parse
      if (pathname === "/v1/admin-parse" && method === "POST") {
        const body = await parseJson(req);
        const result = await adminParse(device, body);
        return json(result.body, result.status);
      }

      // Receipt verification
      if (pathname === "/v1/transaction" && method === "POST") {
        const body = await parseJson(req);
        const result = await verifyTransaction(device, body);
        return json(result.body, result.status);
      }

      // Co-start: create room
      if (pathname === "/v1/costart/rooms" && method === "POST") {
        const result = await createRoom(device);
        return json(result.body, result.status);
      }

      // Co-start: join room
      if (pathname === "/v1/costart/rooms/join" && method === "POST") {
        const body = await parseJson(req);
        const result = await joinRoom(device, body);
        return json(result.body, result.status);
      }

      // Co-start: get participants
      const participantsMatch = pathname.match(/^\/v1\/costart\/rooms\/([^/]+)\/participants$/);
      if (participantsMatch && method === "GET") {
        const roomId = participantsMatch[1];
        const result = await participants(device, roomId);
        return json(result.body, result.status);
      }

      // Co-start: end room
      const endRoomMatch = pathname.match(/^\/v1\/costart\/rooms\/([^/]+)\/end$/);
      if (endRoomMatch && method === "POST") {
        const roomId = endRoomMatch[1];
        const result = await endRoom(device, roomId);
        return json(result.body, result.status);
      }

      // Co-start: set outcome
      const outcomeMatch = pathname.match(/^\/v1\/costart\/rooms\/([^/]+)\/outcome$/);
      if (outcomeMatch && method === "POST") {
        const roomId = outcomeMatch[1];
        const body = await parseJson<{ outcome?: unknown }>(req);
        const outcome = typeof body.outcome === "string" ? body.outcome : "";
        const result = await setOutcome(device, roomId, outcome);
        return json(result.body, result.status);
      }

      // Not found
      return json({ error: "not_found" }, 404);
    } catch (e) {
      console.error(e);
      return json({ error: "server_error" }, 500);
    }
  }
);
