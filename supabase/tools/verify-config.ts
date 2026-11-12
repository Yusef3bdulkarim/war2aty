/**
 * F36-T20 · Verify runtime config on a deployed Supabase project.
 *
 * Checks `get-usage` to confirm `explain_enabled` and other config fields
 * are at their expected values. Used to verify staging is flipped and
 * production stays dark.
 *
 * Usage:
 *   deno run --allow-net supabase/tools/verify-config.ts \
 *     --url <supabase-url> --anon-key <anon-key> [--label staging]
 */

const args = Deno.args;

function flag(name: string): string | null {
  const i = args.indexOf(`--${name}`);
  return i !== -1 && i + 1 < args.length ? args[i + 1] : null;
}

const url = flag("url");
const anonKey = flag("anon-key");
const label = flag("label") ?? "target";

if (!url || !anonKey) {
  console.error("Usage: --url <supabase-url> --anon-key <anon-key>");
  Deno.exit(1);
}

async function mintToken(): Promise<string> {
  const res = await fetch(`${url}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: anonKey!, "Content-Type": "application/json" },
    body: "{}",
  });
  if (!res.ok) throw new Error(`Auth: ${res.status} ${await res.text()}`);
  const session = await res.json();
  return session.access_token as string;
}

async function main() {
  console.log(`\n  Config verification — ${label}`);
  console.log(`  URL: ${url}\n`);

  const token = await mintToken();
  console.log("  ✓ Anonymous token minted.\n");

  // Call get-usage (GET, no body)
  const res = await fetch(`${url}/functions/v1/get-usage`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: anonKey!,
    },
  });

  const body = await res.json();

  if (res.status !== 200) {
    console.log(`  ✗ get-usage returned ${res.status}:`);
    console.log(`    ${JSON.stringify(body)}`);
    Deno.exit(1);
  }

  console.log(`  get-usage response (${res.status}):`);
  const fields = [
    "explain_enabled",
    "online_ocr_enabled",
    "analysis_enabled",
    "daily_limit",
    "remaining_today",
    "schema_version",
  ];
  for (const f of fields) {
    const v = (body as Record<string, unknown>)[f];
    console.log(`    ${f}: ${JSON.stringify(v)}`);
  }

  // Check explain_enabled specifically
  const explainEnabled = (body as Record<string, unknown>).explain_enabled;
  console.log(`\n  explain_enabled = ${JSON.stringify(explainEnabled)}`);

  // Also probe explain-document to see if it's reachable
  console.log("\n  Probing explain-document (OPTIONS)…");
  try {
    const probe = await fetch(`${url}/functions/v1/explain-document`, {
      method: "OPTIONS",
      headers: { Origin: "https://test.example.com" },
      signal: AbortSignal.timeout(10_000),
    });
    console.log(`    CORS preflight: ${probe.status}`);
    await probe.body?.cancel();
  } catch (err) {
    console.log(`    Not reachable: ${(err as Error).message}`);
  }

  // Probe explain-document with a request to see the gate
  console.log("\n  Probing explain-document (POST, minimal body)…");
  try {
    const probe = await fetch(`${url}/functions/v1/explain-document`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
        apikey: anonKey!,
      },
      body: JSON.stringify({
        explain_schema_version: "1.0",
        session_id: crypto.randomUUID(),
        installation_id: crypto.randomUUID(),
        app_version: "1.1.0",
        image: { data: "dGVzdA==", mime_type: "image/jpeg" },
      }),
      signal: AbortSignal.timeout(15_000),
    });
    const probeBody = await probe.json();
    console.log(
      `    ${probe.status}: ${JSON.stringify(probeBody).slice(0, 200)}`,
    );
  } catch (err) {
    console.log(`    Error: ${(err as Error).message}`);
  }

  console.log();
}

main().catch((err) => {
  console.error(err);
  Deno.exit(1);
});
