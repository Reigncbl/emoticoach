-- Migration script to remove max_turns column from scenarios_with_config table
-- Run this after updating the backend code

BEGIN;

-- Remove the max_turns column from the scenarios_with_config table
ALTER TABLE "public"."scenarios_with_config" DROP COLUMN IF EXISTS "max_turns";

COMMIT;

-- Verification query (run this to confirm the column was removed)
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'scenarios_with_config'
-- ORDER BY ordinal_position;