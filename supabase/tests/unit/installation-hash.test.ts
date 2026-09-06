/**
 * F06-T13 · Tests for the installation hash.
 *
 * The property that matters is that the stored value cannot be reversed to an
 * `installation_id` by anyone who reads the table without also holding the
 * salt (F06-T02, §7).
 */

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  hashInstallationId,
  installationHasherFromEnv,
} from "../../functions/_shared/usage/installation-hash.ts";
import { INSTALLATION_ID } from "../fixtures/analyze-fixtures.ts";

const SALT = "0123456789abcdef0123456789abcdef";

Deno.test("hashing is deterministic for the same salt", async () => {
  // Idempotency depends on it: the same install must produce the same row key.
  const first = await hashInstallationId(INSTALLATION_ID, SALT);
  const second = await hashInstallationId(INSTALLATION_ID, SALT);
  assertEquals(first, second);
});

Deno.test("the hash is a 64-character hex sha-256 and never the id itself", async () => {
  const hash = await hashInstallationId(INSTALLATION_ID, SALT);

  assertEquals(hash.length, 64);
  assert(/^[0-9a-f]{64}$/.test(hash));
  assert(!hash.includes(INSTALLATION_ID.replaceAll("-", "")));
});

Deno.test("a different salt yields a different hash", async () => {
  // Otherwise the salt would be decorative and the hash reversible by anyone
  // holding a list of candidate uuids.
  const a = await hashInstallationId(INSTALLATION_ID, SALT);
  const b = await hashInstallationId(INSTALLATION_ID, `${SALT}x`);
  assert(a !== b);
});

Deno.test("distinct installs never collide through the separator", async () => {
  // Without the ":" these two inputs would concatenate identically.
  const a = await hashInstallationId("cd", "ab");
  const b = await hashInstallationId("bcd", "a");
  assert(a !== b);
});

Deno.test("a missing or short salt is a startup failure, not a silent fallback", () => {
  const original = Deno.env.get("INSTALLATION_HASH_SALT");
  try {
    Deno.env.delete("INSTALLATION_HASH_SALT");
    assertThrows(() => installationHasherFromEnv(), Error, "INSTALLATION_HASH_SALT");

    // A placeholder left in .env would otherwise make every hash guessable.
    Deno.env.set("INSTALLATION_HASH_SALT", "changeme");
    assertThrows(() => installationHasherFromEnv(), Error, "INSTALLATION_HASH_SALT");
  } finally {
    if (original === undefined) Deno.env.delete("INSTALLATION_HASH_SALT");
    else Deno.env.set("INSTALLATION_HASH_SALT", original);
  }
});

Deno.test("a bound hasher uses the environment salt", async () => {
  const original = Deno.env.get("INSTALLATION_HASH_SALT");
  try {
    Deno.env.set("INSTALLATION_HASH_SALT", SALT);
    const hasher = installationHasherFromEnv();

    assertEquals(
      await hasher(INSTALLATION_ID),
      await hashInstallationId(INSTALLATION_ID, SALT),
    );
  } finally {
    if (original === undefined) Deno.env.delete("INSTALLATION_HASH_SALT");
    else Deno.env.set("INSTALLATION_HASH_SALT", original);
  }
});

Deno.test("hashing never throws for an unexpected id shape", async () => {
  // Validating the id is the request parser's job. This must not become a
  // second gate that fails an analysis for a reason nobody can see in a log.
  assertEquals((await hashInstallationId("", SALT)).length, 64);
  assertEquals((await hashInstallationId("not-a-uuid", SALT)).length, 64);
});
