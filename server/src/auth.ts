import { query, one } from "./db.ts";

export type Device = { id: string; entitlement: string };

export async function sha256Hex(value: string): Promise<string> {
  const encoded = new TextEncoder().encode(value);
  const hashBuffer = await crypto.subtle.digest("SHA-256", encoded);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function registerDevice(): Promise<{
  token: string;
  device: Device;
}> {
  const tokenBytes = new Uint8Array(32);
  crypto.getRandomValues(tokenBytes);
  const token = Array.from(tokenBytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  const tokenHash = await sha256Hex(token);

  const row = await one<{ id: string; entitlement: string }>(
    "INSERT INTO devices (token_hash, entitlement) VALUES ($1, $2) RETURNING id, entitlement",
    [tokenHash, "free"]
  );

  if (!row) throw new Error("Failed to register device");

  return {
    token,
    device: { id: row.id, entitlement: row.entitlement },
  };
}

export async function deviceForToken(
  authHeader: string | null
): Promise<Device | null> {
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;

  const token = authHeader.slice(7);
  const tokenHash = await sha256Hex(token);

  const row = await one<{ id: string; entitlement: string }>(
    "UPDATE devices SET last_seen_at = now() WHERE token_hash = $1 RETURNING id, entitlement",
    [tokenHash]
  );

  return row || null;
}
