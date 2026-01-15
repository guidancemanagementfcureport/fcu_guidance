-- ============================================
-- COUNSELING REQUESTS SCHEMA
-- ============================================
-- This file creates the tables for the counseling request workflow
-- Run this AFTER reports_base_schema.sql
-- ============================================

-- ============================================
-- 1. CREATE COUNSELING_REQUESTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS counseling_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  counselor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  dean_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reason TEXT,
  preferred_time TEXT,
  request_details TEXT,
  counselor_note TEXT,
  status TEXT NOT NULL DEFAULT 'Pending Counseling Review',
  -- Counseling Session Scheduling (set by Student during request)
  session_date DATE,
  session_time TIME,
  session_type TEXT CHECK (session_type IN ('Individual', 'Group', NULL)),
  location_mode TEXT CHECK (location_mode IN ('In-person', 'Online', NULL)),
  participants JSONB, -- Array of participant user IDs and roles (selected by student: facilitator, adviser, parent)
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add comments for documentation
COMMENT ON TABLE counseling_requests IS 'Student counseling requests linked to reports approved by Dean. Students schedule sessions and select participants during request submission.';
COMMENT ON COLUMN counseling_requests.report_id IS 'Reference to the report approved by Dean that this counseling request is for';
COMMENT ON COLUMN counseling_requests.student_id IS 'Student who requested counseling and scheduled the session';
COMMENT ON COLUMN counseling_requests.counselor_id IS 'Counselor assigned to handle the request';
COMMENT ON COLUMN counseling_requests.dean_id IS 'Dean who approved the report (allows student to request counseling)';
COMMENT ON COLUMN counseling_requests.reason IS 'Student reason for requesting counseling';
COMMENT ON COLUMN counseling_requests.preferred_time IS 'Student preferred time/schedule for counseling (legacy field, now using session_date and session_time)';
COMMENT ON COLUMN counseling_requests.request_details IS 'Additional details from student';
COMMENT ON COLUMN counseling_requests.counselor_note IS 'Counselor notes and assessment';
COMMENT ON COLUMN counseling_requests.status IS 'Status: Pending Counseling Review, Counseling Confirmed, Settled';
COMMENT ON COLUMN counseling_requests.session_date IS 'Scheduled date for counseling session (selected by student during request)';
COMMENT ON COLUMN counseling_requests.session_time IS 'Scheduled time for counseling session (selected by student during request)';
COMMENT ON COLUMN counseling_requests.session_type IS 'Type of session: Individual or Group (selected by student)';
COMMENT ON COLUMN counseling_requests.location_mode IS 'Location mode: In-person or Online (selected by student)';
COMMENT ON COLUMN counseling_requests.participants IS 'JSON array of participant user IDs and their roles (selected by student: facilitator, adviser, parent). For parents/guardians, userId may be omitted and only role=\"parent\" stored.';

-- ============================================
-- 2. CREATE COUNSELING_ACTIVITY_LOGS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS counseling_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  counseling_id UUID NOT NULL REFERENCES counseling_requests(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  note TEXT,
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add comments for documentation
COMMENT ON TABLE counseling_activity_logs IS 'Tracks all actions performed on counseling requests';
COMMENT ON COLUMN counseling_activity_logs.counseling_id IS 'Reference to the counseling request this activity log belongs to';
COMMENT ON COLUMN counseling_activity_logs.actor_id IS 'User ID who performed the action';
COMMENT ON COLUMN counseling_activity_logs.action IS 'Action performed: requested, confirmed, settled';
COMMENT ON COLUMN counseling_activity_logs.note IS 'Optional comment or note from the actor';

-- ============================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- Index for counseling_requests by report_id
CREATE INDEX IF NOT EXISTS idx_counseling_requests_report_id 
ON counseling_requests(report_id);

-- Index for counseling_requests by student_id
CREATE INDEX IF NOT EXISTS idx_counseling_requests_student_id 
ON counseling_requests(student_id);

-- Index for counseling_requests by counselor_id
CREATE INDEX IF NOT EXISTS idx_counseling_requests_counselor_id 
ON counseling_requests(counselor_id);

-- Index for counseling_requests by dean_id
CREATE INDEX IF NOT EXISTS idx_counseling_requests_dean_id 
ON counseling_requests(dean_id);

-- Index for counseling_requests by status
CREATE INDEX IF NOT EXISTS idx_counseling_requests_status 
ON counseling_requests(status);

-- Index for counseling_activity_logs by counseling_id
CREATE INDEX IF NOT EXISTS idx_counseling_activity_logs_counseling_id 
ON counseling_activity_logs(counseling_id);

-- Index for counseling_activity_logs by timestamp
CREATE INDEX IF NOT EXISTS idx_counseling_activity_logs_timestamp 
ON counseling_activity_logs(timestamp DESC);

-- Index for counseling_activity_logs by actor_id
CREATE INDEX IF NOT EXISTS idx_counseling_activity_logs_actor_id 
ON counseling_activity_logs(actor_id);

-- ============================================
-- 4. CREATE TRIGGER FOR UPDATED_AT
-- ============================================

-- Function to automatically update updated_at timestamp on counseling_requests
CREATE OR REPLACE FUNCTION update_counseling_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at when counseling request is modified
DROP TRIGGER IF EXISTS trigger_update_counseling_requests_updated_at ON counseling_requests;
CREATE TRIGGER trigger_update_counseling_requests_updated_at
  BEFORE UPDATE ON counseling_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_counseling_requests_updated_at();

-- ============================================
-- 5. ADD DATA VALIDATION CONSTRAINTS
-- ============================================

-- Add check constraint for counseling request status
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_counseling_request_status'
  ) THEN
    ALTER TABLE counseling_requests
    ADD CONSTRAINT check_counseling_request_status
    CHECK (
      status IN (
        'Pending Counseling Review',
        'Counseling Confirmed',
        'Settled'
      )
    );
  END IF;
END $$;

-- ============================================
-- 6. CREATE HELPER FUNCTIONS
-- ============================================

-- Function to get counseling request timeline
CREATE OR REPLACE FUNCTION get_counseling_request_timeline(
  p_counseling_id UUID
)
RETURNS TABLE (
  id UUID,
  action TEXT,
  note TEXT,
  "timestamp" TIMESTAMP,
  actor_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cal.id,
    cal.action,
    cal.note,
    cal.timestamp,
    COALESCE(u.full_name, 'Unknown') as actor_name
  FROM counseling_activity_logs cal
  LEFT JOIN auth.users u ON cal.actor_id = u.id
  WHERE cal.counseling_id = p_counseling_id
  ORDER BY cal.timestamp ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. VERIFICATION QUERIES
-- ============================================

-- Check if counseling_requests table was created
SELECT 
  'Counseling requests table created!' as status,
  COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name = 'counseling_requests';

-- Check if counseling_activity_logs table was created
SELECT 
  'Counseling activity logs table created!' as status,
  COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name = 'counseling_activity_logs';

-- Check if indexes were created
SELECT 
  'Indexes created!' as status,
  indexname,
  tablename
FROM pg_indexes
WHERE tablename IN ('counseling_requests', 'counseling_activity_logs')
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ============================================
-- COUNSELING REQUESTS SCHEMA SETUP COMPLETE
-- ============================================

