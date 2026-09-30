-- F20-T14 · A provider-neutral switch for the online reading.
--
-- F13's `azure_ocr_enabled` named the provider behind `ocr-document`. F20
-- replaces Azure with Gemini, so the key is replaced with `online_ocr_enabled`,
-- read as `RuntimeConfig.onlineOcrEnabled` and reported on get-usage as
-- `online_ocr_enabled`.
--
-- Seeded OFF, whatever the old key said. `azure_ocr_enabled = true` approved
-- sending photos to Azure; it did not approve Gemini, a different provider
-- with different data terms (F20 context §3). The owner switches the new key
-- on after F20-T27's end-to-end verification:
--
--   update public.app_runtime_config set value = 'true'::jsonb
--    where key = 'online_ocr_enabled';
--
-- ON CONFLICT DO NOTHING keeps a value an operator has already set.

insert into public.app_runtime_config (key, value) values
  ('online_ocr_enabled', 'false'::jsonb)
on conflict (key) do nothing;

-- Nothing reads the old key any more. Removed so it cannot mislead an
-- operator into thinking it still switches anything.
delete from public.app_runtime_config
 where key = 'azure_ocr_enabled';
