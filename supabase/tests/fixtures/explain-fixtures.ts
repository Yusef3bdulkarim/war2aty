/**
 * F36-T14 · Shared test fixtures for the explain-document request parser.
 *
 * Modelled on `analyze-fixtures.ts`. Reuses the same UUIDs and image payload
 * because they carry no per-endpoint semantics — they are just well-formed
 * values. The schema version is "1.0" (§33), deliberately different from the
 * analyze flow's "2.0".
 */

import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
import { DEFAULT_RUNTIME_CONFIG } from "../../functions/_shared/config/runtime-config.ts";

export const SESSION_ID = "3f2504e0-4f89-41d3-9a0c-0305e82c3301";
export const INSTALLATION_ID = "9c858901-8a57-4791-81fe-4c455b099bc9";

/** A tiny, genuinely valid 1×1 JPEG — the same one the analyze fixtures use. */
export const VALID_IMAGE_BASE64 =
  "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=";

export function testConfig(overrides: Partial<RuntimeConfig> = {}): RuntimeConfig {
  return { ...DEFAULT_RUNTIME_CONFIG, ...overrides };
}

/** A request body that must pass validation unchanged. */
export function validExplainBody(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    explain_schema_version: "1.0",
    session_id: SESSION_ID,
    installation_id: INSTALLATION_ID,
    app_version: "1.0.0",
    image: {
      data: VALID_IMAGE_BASE64,
      mime_type: "image/jpeg",
    },
    ...overrides,
  };
}
