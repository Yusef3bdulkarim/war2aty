-- F13-T09 · Analysis contract v2.
--
-- Bumps the server's advertised schema_version so analyze-document starts
-- rejecting v1 request bodies with 400 UNSUPPORTED_SCHEMA. This is a real
-- breaking change, not a seed: the app must ship the v2 request shape
-- (input_type, and — once T11 wires it — the image-intake path) before this
-- takes effect in production, same coordination any schema_version bump needs.
--
-- Also seeds max_image_bytes (F13-T09), the size cap analyze-document applies
-- to a decoded image-intake payload. Absent entirely until now because no
-- request shape carried image bytes before this contract version.

insert into public.app_runtime_config (key, value) values
  ('schema_version', '"2.0"'::jsonb)
on conflict (key) do update
   set value = excluded.value;

insert into public.app_runtime_config (key, value) values
  -- Upper bound on a decoded image.data payload; requests above it are
  -- rejected 400 before reaching Azure.
  ('max_image_bytes', '8000000'::jsonb)
on conflict (key) do nothing;
