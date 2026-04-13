-- ============================================
-- SQL PATCH: ALLOW PERSONAL COUNSELING REQUESTS
-- ============================================
-- This patch drops the NOT NULL constraint on `report_id` in the `counseling_requests` table,
-- allowing students to create personal requests that are not attached to an incident report.

DO $$
BEGIN
  -- Check if the column exists before trying to alter it
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'counseling_requests' AND column_name = 'report_id'
  ) THEN
    -- Drop the NOT NULL constraint on report_id
    ALTER TABLE counseling_requests ALTER COLUMN report_id DROP NOT NULL;
  END IF;
END $$;
