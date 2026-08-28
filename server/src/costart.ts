import { query, one } from "./db.ts";
import { Device } from "./auth.ts";

type Room = {
  id: string;
  host_device_id: string;
  code: string;
  duration_minutes: number;
  status: string;
  starts_at: string;
  ended_at: string | null;
};

type Participant = {
  id: string;
  display_name: string;
  stated_step: string;
  outcome: string | null;
};

type ResponseBody =
  | { error: string }
  | { room: Room }
  | { participants: Participant[] }
  | { success: boolean }
  | Record<string, unknown>;

type Response<T> = {
  status: number;
  body: T;
};

function generateCode(): string {
  // Crypto-random, not Math.random: this code is the only thing standing
  // between a stranger and someone else's room.
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return (bytes[0] % 1_000_000).toString().padStart(6, "0");
}

export async function createRoom(
  device: Device
): Promise<Response<ResponseBody>> {
  let room: Room | null = null;

  // Try up to 5 times to generate a unique code
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateCode();

    try {
      const result = await one<Room>(
        "INSERT INTO costart_rooms (host_device_id, code) VALUES ($1, $2) RETURNING id, host_device_id, code, duration_minutes, status, starts_at, ended_at",
        [device.id, code]
      );

      if (result) {
        room = result;

        // Insert host as participant
        await query(
          "INSERT INTO costart_participants (room_id, device_id) VALUES ($1, $2)",
          [room.id, device.id]
        );

        return { status: 201, body: { room } };
      }
    } catch (e) {
      // 23505 = unique_violation: this code is taken, try another.
      const code = (e as { fields?: { code?: string } })?.fields?.code;
      if (code !== "23505") throw e;
    }
  }

  return { status: 503, body: { error: "code_unavailable" } };
}

export async function joinRoom(
  device: Device,
  body: {
    code?: unknown;
    step_text?: unknown;
    display_name?: unknown;
  }
): Promise<Response<ResponseBody>> {
  // Normalize code to 6 digits
  if (typeof body.code !== "string") {
    return { status: 400, body: { error: "bad_request" } };
  }

  const normalizedCode = body.code.replace(/\D/g, "");
  if (normalizedCode.length !== 6) {
    return { status: 400, body: { error: "bad_request" } };
  }

  // Find active room
  const room = await one<Room>(
    "SELECT id, host_device_id, code, duration_minutes, status, starts_at, ended_at FROM costart_rooms WHERE code = $1 AND status = 'active'",
    [normalizedCode]
  );

  if (!room) {
    return { status: 404, body: { error: "room_not_found" } };
  }

  // Clamp display_name and step_text
  const displayName =
    typeof body.display_name === "string"
      ? body.display_name.slice(0, 40)
      : "";
  const stepText =
    typeof body.step_text === "string" ? body.step_text.slice(0, 180) : "";

  // Upsert participant
  await query(
    "INSERT INTO costart_participants (room_id, device_id, display_name, stated_step) VALUES ($1, $2, $3, $4) ON CONFLICT (room_id, device_id) DO UPDATE SET display_name = $3, stated_step = $4",
    [room.id, device.id, displayName, stepText]
  );

  return { status: 200, body: { room } };
}

export async function participants(
  device: Device,
  roomId: string
): Promise<Response<ResponseBody>> {
  // Only someone already in the room may see who else is in it.
  const member = await one<{ id: string }>(
    "SELECT id FROM costart_participants WHERE room_id = $1 AND device_id = $2",
    [roomId, device.id]
  );
  if (!member) return { status: 403, body: { error: "not_a_participant" } };

  const rows = await query<Participant>(
    "SELECT id, display_name, stated_step, outcome FROM costart_participants WHERE room_id = $1",
    [roomId]
  );

  return { status: 200, body: { participants: rows } };
}

export async function endRoom(
  device: Device,
  roomId: string
): Promise<Response<ResponseBody>> {
  // Only host may end it
  const result = await query(
    "UPDATE costart_rooms SET status = 'ended', ended_at = now() WHERE id = $1 AND host_device_id = $2 RETURNING id",
    [roomId, device.id]
  );

  if (result.length === 0) {
    return { status: 403, body: { error: "not_host" } };
  }

  return { status: 200, body: { room: result[0] as Room } };
}

const OUTCOMES = new Set(["completed", "partial", "paused", "abandoned"]);

export async function setOutcome(
  device: Device,
  roomId: string,
  outcome: string
): Promise<Response<ResponseBody>> {
  // Only the app's own outcome vocabulary, so arbitrary strings cannot be stored.
  if (!OUTCOMES.has(outcome)) {
    return { status: 400, body: { error: "bad_request" } };
  }

  await query(
    "UPDATE costart_participants SET outcome = $1, left_at = now() WHERE room_id = $2 AND device_id = $3",
    [outcome, roomId, device.id]
  );

  return { status: 200, body: { success: true } };
}
