-- ============================================
-- ANONYMOUS REPORTS SCHEMA
-- ============================================
-- This file adds support for anonymous reports
-- Run this AFTER reports_base_schema.sql
-- ============================================

-- ============================================
-- 1. ALTER REPORTS TABLE FOR ANONYMOUS REPORTS
-- ============================================

-- Make student_id nullable for anonymous reports
ALTER TABLE reports
ALTER COLUMN student_id DROP NOT NULL;

-- Add tracking_id column for anonymous reports
ALTER TABLE reports
ADD COLUMN IF NOT EXISTS tracking_id TEXT UNIQUE;

-- Add index for tracking_id lookups
CREATE INDEX IF NOT EXISTS idx_reports_tracking_id 
ON reports(tracking_id) 
WHERE tracking_id IS NOT NULL;

-- Add comment for tracking_id
COMMENT ON COLUMN reports.tracking_id IS 'Unique tracking ID for anonymous reports (format: ANON-XXXXXX)';

-- ============================================
-- 2. UPDATE REPORT ACTIVITY LOGS FOR ANONYMOUS
-- ============================================

-- Make actor_id nullable for anonymous reports (no user associated)
ALTER TABLE report_activity_logs
ALTER COLUMN actor_id DROP NOT NULL;

-- Update check constraint to allow null actor_id
ALTER TABLE report_activity_logs
DROP CONSTRAINT IF EXISTS report_activity_logs_actor_id_fkey;

-- Re-add foreign key constraint as nullable
ALTER TABLE report_activity_logs
ADD CONSTRAINT report_activity_logs_actor_id_fkey
FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ============================================
-- 3. FUNCTION TO GENERATE TRACKING ID
-- ============================================

CREATE OR REPLACE FUNCTION generate_tracking_id()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Excludes confusing chars
  result TEXT := 'ANON-';
  i INTEGER;
BEGIN
  -- Generate 6 random characters
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
  END LOOP;
  
  -- Check if tracking_id already exists, regenerate if needed
  WHILE EXISTS (SELECT 1 FROM reports WHERE tracking_id = result) LOOP
    result := 'ANON-';
    FOR i IN 1..6 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
    END LOOP;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. TRIGGER TO AUTO-GENERATE TRACKING ID FOR ANONYMOUS REPORTS
-- ============================================

CREATE OR REPLACE FUNCTION set_tracking_id_for_anonymous()
RETURNS TRIGGER AS $$
BEGIN
  -- If report is anonymous and tracking_id is not set, generate one
  IF NEW.is_anonymous = true AND (NEW.tracking_id IS NULL OR NEW.tracking_id = '') THEN
    NEW.tracking_id := generate_tracking_id();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_set_tracking_id ON reports;
CREATE TRIGGER trigger_set_tracking_id
  BEFORE INSERT ON reports
  FOR EACH ROW
  EXECUTE FUNCTION set_tracking_id_for_anonymous();

-- ============================================
-- 5. UPDATE STATUS CONSTRAINT FOR ANONYMOUS REPORTS
-- ============================================

-- Update status check to include 'pending' for anonymous reports
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_report_status'
  ) THEN
    ALTER TABLE reports DROP CONSTRAINT check_report_status;
  END IF;
  
  -- Add updated constraint with 'pending' status
  ALTER TABLE reports
  ADD CONSTRAINT check_report_status
  CHECK (
    status IN (
      'submitted',
      'pending',
      'teacher_reviewed',
      'forwarded',
      'counselor_reviewed',
      'counselor_confirmed',
      'approved_by_dean',
      'counseling_scheduled',
      'settled',
      'completed'
    )
  );
END $$;

-- ============================================
-- 6. RLS POLICIES FOR ANONYMOUS REPORTS
-- ============================================

-- Allow anonymous inserts (no authentication required)
-- Note: This requires RLS to be enabled but allows unauthenticated inserts
-- You may need to adjust based on your security requirements

-- Policy to allow anonymous report creation (if using service role or public access)
-- For production, consider using a Supabase Edge Function instead
COMMENT ON TABLE reports IS 'Student incident reports and concerns. Supports both authenticated and anonymous submissions.';

-- ============================================
-- 7. VERIFICATION QUERIES
-- ============================================

-- Check if tracking_id column was added
SELECT 
  'Tracking ID column added!' as status,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'reports' 
AND column_name = 'tracking_id';

-- Check if student_id is now nullable
SELECT 
  'Student ID is nullable!' as status,
  column_name,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'reports' 
AND column_name = 'student_id';

-- Check if tracking_id index was created
SELECT 
  'Tracking ID index created!' as status,
  indexname,
  tablename
FROM pg_indexes
WHERE tablename = 'reports'
AND indexname = 'idx_reports_tracking_id';

-- ============================================
-- ANONYMOUS REPORTS SCHEMA SETUP COMPLETE
-- ============================================
-- 
-- Next steps:
-- 1. Test anonymous report creation
-- 2. Verify tracking ID generation
-- 3. Test report lookup by tracking ID
-- 4. Ensure reports appear in counselor/admin dashboards
--
-- ============================================

-- 1. Update the status constraint to allow 'forwarded'
ALTER TABLE anonymous_reports 
DROP CONSTRAINT IF EXISTS check_anonymous_report_status;

ALTER TABLE anonymous_reports 
ADD CONSTRAINT check_anonymous_report_status 
CHECK (status IN ('pending', 'ongoing', 'forwarded', 'resolved'));

-- 2. Add counselor_id and teacher_note to the anonymous_reports table
ALTER TABLE anonymous_reports ADD COLUMN IF NOT EXISTS counselor_id UUID REFERENCES auth.users(id);
ALTER TABLE anonymous_reports ADD COLUMN IF NOT EXISTS teacher_note TEXT;