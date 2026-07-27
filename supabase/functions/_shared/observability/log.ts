/**
 * F06-T13 · Structured logging.
 *
 * One line of JSON per event, so the Supabase log explorer can filter on the
 * fields instead of on a formatted sentence.
 *
 * ── What may be logged (§7, §51) ─────────────────────────────────────────
 * Envelope and outcome only: `request_id`, function name, HTTP status, §31
 * error code, durations, counts. NEVER `ocr_text`, a candidate value, a prompt,
 * an AI response, a field value, a token, a key, or a raw `installation_id` —
 * all of those either are, or can reveal, the contents of someone's document.
 *
 * Field NAMES from the contract (`amounts`, `dates`) are labels, not content,
 * and are safe. Their values are not.
 *
 * {@link MAX_VALUE_LENGTH} is a backstop, not a licence: a long string is the
 * shape a leak takes, so one is truncated rather than printed whole. It cannot
 * make a wrong field safe — the call site is still responsible for choosing
 * what to pass.
 */

export type LogValue = string | number | boolean | null | undefined;

/** Long enough for a uuid and an error code, far too short for a document. */
const MAX_VALUE_LENGTH = 120;

function sanitise(value: string | number | boolean): string | number | boolean {
  if (typeof value !== "string" || value.length <= MAX_VALUE_LENGTH) return value;
  return `${value.slice(0, MAX_VALUE_LENGTH)}…`;
}

/**
 * Emits one JSON log line. `undefined` fields are dropped so an absent value
 * does not produce a `null` that reads like a measured one.
 */
export function logEvent(
  event: string,
  fields: Readonly<Record<string, LogValue>> = {},
): void {
  const record: Record<string, string | number | boolean | null> = { event };

  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined) continue;
    record[key] = value === null ? null : sanitise(value);
  }

  console.log(JSON.stringify(record));
}
