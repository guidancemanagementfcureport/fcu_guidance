-- ============================================
-- ANONYMOUS REPORT COUNSELORS SCHEMA
-- ============================================
-- Description: Creates a dedicated table for linking anonymous reports 
-- specifically to counselors, allowing for cleaner separation from 
-- teacher assignments.
-- ============================================

-- 1. Create the anonymous_report_counselors table
CREATE TABLE IF NOT EXISTS anonymous_report_counselors (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  report_id UUID REFERENCES anonymous_reports(id) ON DELETE CASCADE NOT NULL,
  counselor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate assignments for the same report/counselor pair
  UNIQUE(report_id, counselor_id)
);

-- 2. Add RLS Policies
ALTER TABLE anonymous_report_counselors ENABLE ROW LEVEL SECURITY;

-- Policy: Counselors can view their own assignments
CREATE POLICY "Counselors can view their own assignments"
  ON anonymous_report_counselors
  FOR SELECT
  USING (auth.uid() = counselor_id);

-- Policy: Allow system/service role to insert assignments
-- (This relies on the service role bypassing RLS, or you can add a specific policy 
-- if inserts happen from authenticated contexts)
CREATE POLICY "Enable insert for authenticated users" 
  ON anonymous_report_counselors 
  FOR INSERT 
  WITH CHECK (true);

-- 3. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_anon_report_counselors_report_id 
  ON anonymous_report_counselors(report_id);

CREATE INDEX IF NOT EXISTS idx_anon_report_counselors_counselor_id 
  ON anonymous_report_counselors(counselor_id);

-- 4. Add comment
COMMENT ON TABLE anonymous_report_counselors IS 'Links anonymous reports directly to guidance counselors for immediate attention.';
