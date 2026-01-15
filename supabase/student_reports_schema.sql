-- ============================================
-- STUDENT REPORTS SCHEMA
-- ============================================
-- Schema for Student Submit Report functionality
-- This file contains views and functions specific to students
-- Note: RLS is NOT enabled - access control handled in application layer
-- ============================================

-- ============================================
-- 1. STUDENT REPORTS VIEW
-- ============================================
-- A view that shows reports with student-friendly information

CREATE OR REPLACE VIEW student_reports_view AS
SELECT 
  r.id,
  r.student_id,
  r.title,
  r.type,
  r.details,
  r.attachment_url,
  r.incident_date,
  r.status,
  r.is_anonymous,
  r.created_at,
  r.updated_at,
  -- Count activity logs
  (SELECT COUNT(*) FROM report_activity_logs WHERE report_id = r.id) as activity_count,
  -- Get latest activity timestamp
  (SELECT MAX(timestamp) FROM report_activity_logs WHERE report_id = r.id) as last_activity
FROM reports r
WHERE EXISTS (
  SELECT 1 FROM users
  WHERE users.id = r.student_id
  AND users.role = 'student'
);

-- Grant access to authenticated users
GRANT SELECT ON student_reports_view TO authenticated;

-- ============================================
-- 2. HELPER FUNCTION FOR STUDENT REPORT STATUS
-- ============================================
-- Function to get report status timeline for students

CREATE OR REPLACE FUNCTION get_student_report_timeline(report_uuid UUID)
RETURNS TABLE (
  action TEXT,
  role TEXT,
  note TEXT,
  "timestamp" TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ral.action,
    ral.role,
    ral.note,
    ral.timestamp
  FROM report_activity_logs ral
  WHERE ral.report_id = report_uuid
  ORDER BY ral.timestamp ASC;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_student_report_timeline(UUID) TO authenticated;

-- ============================================
-- 3. VERIFICATION QUERIES
-- ============================================

-- Check if student view exists
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_name = 'student_reports_view';

-- ============================================
-- STUDENT REPORTS SCHEMA COMPLETE
-- ============================================
-- This schema provides:
-- 1. Student reports view with activity information
-- 2. Helper function for report timeline
-- 
-- Note: Access control is handled in the application layer
-- RLS is NOT enabled on tables
-- Storage policies are NOT configured - handled in application layer
-- ============================================

