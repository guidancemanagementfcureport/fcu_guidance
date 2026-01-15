-- ============================================
-- MIGRATION: Guided Report Escalation & Counseling Workflow
-- ============================================
-- This migration updates the database schema to support the new
-- report escalation workflow: Teacher → Counselor → Dean → Counseling Scheduled
-- ============================================

-- ============================================
-- 1. UPDATE REPORTS TABLE
-- ============================================

-- Add dean_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reports' AND column_name = 'dean_id'
  ) THEN
    ALTER TABLE reports ADD COLUMN dean_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add internal notes columns if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reports' AND column_name = 'teacher_note'
  ) THEN
    ALTER TABLE reports ADD COLUMN teacher_note TEXT;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reports' AND column_name = 'counselor_note'
  ) THEN
    ALTER TABLE reports ADD COLUMN counselor_note TEXT;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reports' AND column_name = 'dean_note'
  ) THEN
    ALTER TABLE reports ADD COLUMN dean_note TEXT;
  END IF;
END $$;

-- Create index for dean_id if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_reports_dean_id ON reports(dean_id);

-- Update status constraint to include new workflow statuses
DO $$
BEGIN
  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_report_status'
  ) THEN
    ALTER TABLE reports DROP CONSTRAINT check_report_status;
  END IF;
  
  -- Add updated constraint with new workflow statuses
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
-- 2. UPDATE COUNSELING_REQUESTS TABLE
-- ============================================

-- Add dean_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'counseling_requests' AND column_name = 'dean_id'
  ) THEN
    ALTER TABLE counseling_requests ADD COLUMN dean_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add session scheduling columns if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'counseling_requests' AND column_name = 'session_date'
  ) THEN
    ALTER TABLE counseling_requests ADD COLUMN session_date DATE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'counseling_requests' AND column_name = 'session_time'
  ) THEN
    ALTER TABLE counseling_requests ADD COLUMN session_time TIME;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'counseling_requests' AND column_name = 'session_type'
  ) THEN
    ALTER TABLE counseling_requests ADD COLUMN session_type TEXT CHECK (session_type IN ('Individual', 'Group', NULL));
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'counseling_requests' AND column_name = 'location_mode'
  ) THEN
    ALTER TABLE counseling_requests ADD COLUMN location_mode TEXT CHECK (location_mode IN ('In-person', 'Online', NULL));
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'counseling_requests' AND column_name = 'participants'
  ) THEN
    ALTER TABLE counseling_requests ADD COLUMN participants JSONB;
  END IF;
END $$;

-- Create index for dean_id if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_counseling_requests_dean_id ON counseling_requests(dean_id);

-- ============================================
-- 3. UPDATE COMMENTS
-- ============================================

COMMENT ON COLUMN reports.dean_id IS 'Dean who approved the report for counseling';
COMMENT ON COLUMN reports.teacher_note IS 'Internal notes from teacher (not visible to student)';
COMMENT ON COLUMN reports.counselor_note IS 'Internal notes from counselor (not visible to student)';
COMMENT ON COLUMN reports.dean_note IS 'Internal notes from dean (not visible to student)';
COMMENT ON COLUMN reports.status IS 'Current status: submitted, teacher_reviewed, counselor_reviewed, approved_by_dean, counseling_scheduled, completed';

COMMENT ON COLUMN counseling_requests.dean_id IS 'Dean who approved and scheduled the counseling session';
COMMENT ON COLUMN counseling_requests.session_date IS 'Scheduled date for counseling session (set by Dean)';
COMMENT ON COLUMN counseling_requests.session_time IS 'Scheduled time for counseling session (set by Dean)';
COMMENT ON COLUMN counseling_requests.session_type IS 'Type of session: Individual or Group';
COMMENT ON COLUMN counseling_requests.location_mode IS 'Location mode: In-person or Online';
COMMENT ON COLUMN counseling_requests.participants IS 'JSON array of participant user IDs and their roles (counselor, facilitator, adviser, parent)';

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
-- 
-- The database schema has been updated to support:
-- 1. New report statuses: counselor_reviewed, approved_by_dean, counseling_scheduled, completed
-- 2. Dean assignment and notes in reports
-- 3. Internal notes (teacher, counselor, dean) not visible to students
-- 4. Counseling session scheduling by Dean
-- 5. Participant selection for counseling sessions
--
-- Next steps:
-- 1. Update application code to use new statuses
-- 2. Implement Dean approval workflow
-- 3. Implement counseling session scheduling UI
--
-- ============================================

