-- ============================================
-- REPORTS BASE SCHEMA
-- ============================================
-- This file creates the base tables for the report workflow
-- Run this FIRST before running role-specific schemas
-- ============================================

-- ============================================
-- 1. CREATE REPORTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  counselor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  dean_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'other',
  details TEXT NOT NULL,
  attachment_url TEXT,
  incident_date TIMESTAMP,
  status TEXT NOT NULL DEFAULT 'submitted',
  is_anonymous BOOLEAN NOT NULL DEFAULT false,
  -- Internal notes (not visible to students)
  teacher_note TEXT,
  counselor_note TEXT,
  dean_note TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add comments for documentation
COMMENT ON TABLE reports IS 'Student incident reports and concerns. Student level (College, Senior High, Junior High) is automatically identified from the users table via student_id foreign key.';
COMMENT ON COLUMN reports.student_id IS 'Student who submitted the report. Links to users table to access student_level, course, grade_level, strand, section, and year_level for role-based routing.';
COMMENT ON COLUMN reports.teacher_id IS 'Teacher assigned to review the report';
COMMENT ON COLUMN reports.counselor_id IS 'Counselor assigned to handle the case. For College students, counselor must forward to Dean. For SHS/JHS, counselor can finalize.';
COMMENT ON COLUMN reports.dean_id IS 'Dean who approved the report for counseling. Required for College-level reports.';
COMMENT ON COLUMN reports.title IS 'Title of the incident report';
COMMENT ON COLUMN reports.type IS 'Type of report: Bullying, Academic Concern, Personal Issue, Behavioral Issue, Safety Concern, Other';
COMMENT ON COLUMN reports.details IS 'Detailed description of the incident';
COMMENT ON COLUMN reports.attachment_url IS 'URL to uploaded file attachment (stored in Supabase Storage)';
COMMENT ON COLUMN reports.incident_date IS 'Date and time when the incident occurred';
COMMENT ON COLUMN reports.status IS 'Current status: submitted, teacher_reviewed, forwarded, counselor_reviewed, counselor_confirmed, approved_by_dean, counseling_scheduled, settled, completed. Workflow: Submitted → Teacher Reviewed → Counselor Reviewed (College must forward to Dean) → Approved by Dean → Counseling Scheduled → Completed';
COMMENT ON COLUMN reports.is_anonymous IS 'Whether the report was submitted anonymously';
COMMENT ON COLUMN reports.teacher_note IS 'Internal notes from teacher (not visible to student)';
COMMENT ON COLUMN reports.counselor_note IS 'Internal notes from counselor (not visible to student). Includes forwarding reason for College reports.';
COMMENT ON COLUMN reports.dean_note IS 'Internal notes from dean (not visible to student)';

-- ============================================
-- 2. CREATE REPORT ACTIVITY LOGS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS report_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'counselor', 'dean', 'admin')),
  action TEXT NOT NULL,
  note TEXT,
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add comments for documentation
COMMENT ON TABLE report_activity_logs IS 'Tracks all actions performed on reports (submitted, reviewed, forwarded, reviewed_and_forwarded_to_dean, accepted, confirmed)';
COMMENT ON COLUMN report_activity_logs.report_id IS 'Reference to the report this activity log belongs to';
COMMENT ON COLUMN report_activity_logs.actor_id IS 'User ID who performed the action';
COMMENT ON COLUMN report_activity_logs.role IS 'Role of the user who performed the action: student, teacher, counselor, dean, admin';
COMMENT ON COLUMN report_activity_logs.action IS 'Action performed: submitted, reviewed, forwarded, reviewed_and_forwarded_to_dean (for College reports forwarded to Dean), accepted, confirmed';
COMMENT ON COLUMN report_activity_logs.note IS 'Optional comment or note from the actor';

-- ============================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- Index for report_activity_logs by report_id (for fetching activity history)
CREATE INDEX IF NOT EXISTS idx_report_activity_logs_report_id 
ON report_activity_logs(report_id);

-- Index for report_activity_logs by timestamp (for chronological ordering)
CREATE INDEX IF NOT EXISTS idx_report_activity_logs_timestamp 
ON report_activity_logs(timestamp DESC);

-- Index for report_activity_logs by actor_id (for user activity tracking)
CREATE INDEX IF NOT EXISTS idx_report_activity_logs_actor_id 
ON report_activity_logs(actor_id);

-- Index for reports by type (for filtering)
CREATE INDEX IF NOT EXISTS idx_reports_type 
ON reports(type);

-- Index for reports by status (for filtering)
CREATE INDEX IF NOT EXISTS idx_reports_status 
ON reports(status);

-- Index for reports by incident_date (for date-based queries)
CREATE INDEX IF NOT EXISTS idx_reports_incident_date 
ON reports(incident_date);

-- Index for reports by student_id (for student queries)
CREATE INDEX IF NOT EXISTS idx_reports_student_id 
ON reports(student_id);

-- Index for reports by teacher_id (for teacher queries)
CREATE INDEX IF NOT EXISTS idx_reports_teacher_id 
ON reports(teacher_id);

-- Index for reports by counselor_id (for counselor queries)
CREATE INDEX IF NOT EXISTS idx_reports_counselor_id 
ON reports(counselor_id);

-- Index for reports by dean_id (for dean queries)
CREATE INDEX IF NOT EXISTS idx_reports_dean_id 
ON reports(dean_id);

-- Index for reports by status and student_id (for filtering by student level via JOIN)
CREATE INDEX IF NOT EXISTS idx_reports_status_student_id 
ON reports(status, student_id);

-- ============================================
-- 4. CREATE STORAGE BUCKET FOR FILE ATTACHMENTS
-- ============================================

-- Create storage bucket for report attachments
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'reports',
  'reports',
  false,
  10485760, -- 10MB file size limit
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/jpg', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 5. CREATE TRIGGER FOR UPDATED_AT
-- ============================================

-- Function to automatically update updated_at timestamp on reports
CREATE OR REPLACE FUNCTION update_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at when report is modified
DROP TRIGGER IF EXISTS trigger_update_reports_updated_at ON reports;
CREATE TRIGGER trigger_update_reports_updated_at
  BEFORE UPDATE ON reports
  FOR EACH ROW
  EXECUTE FUNCTION update_reports_updated_at();

-- ============================================
-- 6. ADD DATA VALIDATION CONSTRAINTS
-- ============================================

-- Add check constraint for report type
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_report_type'
  ) THEN
    ALTER TABLE reports
    ADD CONSTRAINT check_report_type
    CHECK (
      type IN (
        'Bullying',
        'Academic Concern',
        'Personal Issue',
        'Behavioral Issue',
        'Safety Concern',
        'Other'
      )
    );
  END IF;
END $$;

-- Add check constraint for report status
DO $$
BEGIN
  -- Drop existing constraint if it exists (to update it)
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
-- 7. VERIFICATION QUERIES
-- ============================================

-- Check if reports table was created
SELECT 
  'Reports table created!' as status,
  COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name = 'reports';

-- Check if report_activity_logs table was created
SELECT 
  'Activity logs table created!' as status,
  COUNT(*) as column_count
FROM information_schema.columns
WHERE table_name = 'report_activity_logs';

-- Check if storage bucket exists
SELECT 
  'Storage bucket created!' as status,
  id,
  name,
  file_size_limit
FROM storage.buckets
WHERE id = 'reports';

-- Check if indexes were created
SELECT 
  'Indexes created!' as status,
  indexname,
  tablename
FROM pg_indexes
WHERE tablename IN ('reports', 'report_activity_logs')
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ============================================
-- MIGRATION: Update report_activity_logs to support Dean role
-- ============================================
-- Run this section if the report_activity_logs table already exists

-- Update role check constraint to include Dean
DO $$
BEGIN
  -- Drop existing constraint if it exists (to update it)
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'report_activity_logs_role_check'
  ) THEN
    ALTER TABLE report_activity_logs DROP CONSTRAINT report_activity_logs_role_check;
  END IF;
  
  -- Add updated constraint with Dean role
  ALTER TABLE report_activity_logs
  ADD CONSTRAINT report_activity_logs_role_check
  CHECK (role IN ('student', 'teacher', 'counselor', 'dean', 'admin'));
END $$;

-- ============================================
-- BASE SCHEMA SETUP COMPLETE
-- ============================================
-- 
-- Next steps:
-- 1. Run student_reports_schema.sql
-- 2. Run teacher_reports_schema.sql
-- 3. Run counselor_reports_schema.sql
--
-- ============================================

