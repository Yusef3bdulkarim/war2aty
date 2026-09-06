/**
 * F06-T13 · Hashing `installation_id` before it is stored.
 *
 * `analysis_attempts.installation_hash` exists so repeated abuse can be spotted
 * across re-installs. That does not require knowing WHICH install it was, so
 * the raw identifier is never written down (F06-T02, §7).
 *
 * The salt is what makes the hash worth anything. `installation_id` is a uuid
 * drawn from a space small enough to be searched if you already hold a
 * candidate list, so an unsalted SHA-256 would be reversible by anyone who
 * could read the table AND had the app's identifiers. With a secret salt they
 * would also need the salt, which lives only in Supabase Secrets.
 *
 * SHA-256 rather than a password hash: this is a per-request lookup key over a
 * high-entropy uuid, not a guessable secret, so the cost of bcrypt/argon buys
 * nothing and would be paid on the hot path of every analysis.
 */

export type InstallationHasher = (installationId: string) => Promise<string>;

/** Rejects a placeholder or an obviously truncated salt. */
const MIN_SALT_LENGTH = 32;

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Salted SHA-256, hex-encoded.
 *
 * The separator matters: without it `salt="ab" + id="cd"` and
 * `salt="a" + id="bcd"` would hash identically, and a `:` cannot occur in a
 * uuid, so no two distinct inputs can collide through it.
 */
export async function hashInstallationId(
  installationId: string,
  salt: string,
): Promise<string> {
  const bytes = new TextEncoder().encode(`${salt}:${installationId}`);
  return toHex(await crypto.subtle.digest("SHA-256", bytes));
}

/**
 * Binds a hasher to `INSTALLATION_HASH_SALT`.
 *
 * @throws if the salt is missing or too short. A deploy fault, surfaced at
 * startup: falling back to an empty salt would silently make every hash
 * reversible, which is the exact failure this module exists to prevent.
 */
export function installationHasherFromEnv(): InstallationHasher {
  const salt = Deno.env.get("INSTALLATION_HASH_SALT")?.trim();

  if (!salt || salt.length < MIN_SALT_LENGTH) {
    throw new Error(
      `INSTALLATION_HASH_SALT must be set to at least ${MIN_SALT_LENGTH} characters.`,
    );
  }

  return (installationId: string) => hashInstallationId(installationId, salt);
}
