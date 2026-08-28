import { Pool } from "https://deno.land/x/postgres@v0.19.3/mod.ts";

let pool: Pool | null = null;

function getPool(): Pool {
  if (!pool) {
    const databaseUrl = Deno.env.get("DATABASE_URL");
    if (!databaseUrl) throw new Error("DATABASE_URL not set");
    pool = new Pool(databaseUrl, 4, true);
  }
  return pool;
}

export async function query<T = Record<string, unknown>>(
  sql: string,
  args?: unknown[]
): Promise<T[]> {
  const client = await getPool().connect();
  try {
    const result = await client.queryObject<T>(sql, args);
    return result.rows;
  } finally {
    client.release();
  }
}

export async function one<T = Record<string, unknown>>(
  sql: string,
  args?: unknown[]
): Promise<T | null> {
  const rows = await query<T>(sql, args);
  return rows.length > 0 ? rows[0] : null;
}
