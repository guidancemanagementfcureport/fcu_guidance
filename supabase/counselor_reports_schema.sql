-- ============================================
-- COUNSELOR REPORTS SCHEMA
-- ============================================
-- Schema for Counselor Case Records functionality
-- This file contains views and functions specific to counselors
-- Note: RLS is NOT enabled - access control handled in application layer
-- ============================================

-- ============================================
-- 1. COUNSELOR CASE RECORDS VIEW
-- ============================================
-- A view that shows case records with counselor-friendly information

CREATE OR REPLACE VIEW counselor_case_records_view AS
SELECT 
  r.id,
  r.student_id,
  r.teacher_id,
  r.counselor_id,
  r.title,
  r.type,
  r.details,
  r.attachment_url,
  r.incident_date,
  r.status,
  r.is_anonymous,
  r.created_at,
  r.updated_at,
  -- Student information
  u_student.full_name as student_name,
  u_student.gmail as student_email,
  u_student.course as student_course,
  u_student.grade_level as student_grade_level,
  -- Teacher information
  u_teacher.full_name as teacher_name,
  u_teacher.gmail as teacher_email,
  u_teacher.department as teacher_department,
  -- Counselor information
  u_counselor.full_name as counselor_name,
  u_counselor.gmail as counselor_email,
  -- Activity information
  (SELECT COUNT(*) FROM report_activity_logs WHERE report_id = r.id) as activity_count,
  (SELECT MAX(timestamp) FROM report_activity_logs WHERE report_id = r.id) as last_activity,
  -- Get teacher's review note
  (SELECT note FROM report_activity_logs 
   WHERE report_id = r.id 
   AND role = 'teacher' 
   AND action = 'reviewed' 
   ORDER BY timestamp DESC 
   LIMIT 1) as teacher_review_note,
  -- Get forward note
  (SELECT note FROM report_activity_logs 
   WHERE report_id = r.id 
   AND role = 'teacher' 
   AND action = 'forwarded' 
   ORDER BY timestamp DESC 
   LIMIT 1) as forward_note,
  -- Check if accepted
  EXISTS (
    SELECT 1 FROM report_activity_logs 
    WHERE report_id = r.id 
    AND actor_id = r.counselor_id 
    AND action = 'confirmed'
  ) as is_accepted,
  -- Check if settled
  EXISTS (
    SELECT 1 FROM report_activity_logs 
    WHERE report_id = r.id 
    AND actor_id = r.counselor_id 
    AND action = 'confirmed'
    AND r.status = 'settled'
  ) as is_settled
FROM reports r
LEFT JOIN users u_student ON r.student_id = u_student.id
LEFT JOIN users u_teacher ON r.teacher_id = u_teacher.id
LEFT JOIN users u_counselor ON r.counselor_id = u_counselor.id
WHERE r.status IN ('forwarded', 'counselor_confirmed', 'settled')
OR r.counselor_id IS NOT NULL;

-- Grant access to authenticated users
GRANT SELECT ON counselor_case_records_view TO authenticated;

-- ============================================
-- 2. HELPER FUNCTIONS FOR COUNSELOR ACTIONS
-- ============================================

-- Function to accept report (counselor confirms)
CREATE OR REPLACE FUNCTION counselor_accept_report(
  report_uuid UUID,
  counselor_id_param UUID,
  counselor_note TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Update report status
  UPDATE reports
  SET 
    status = 'counselor_confirmed',
    counselor_id = counselor_id_param,
    updated_at = NOW()
  WHERE id = report_uuid;
  
  -- Create activity log
  INSERT INTO report_activity_logs (report_id, actor_id, role, action, note)
  VALUES (report_uuid, counselor_id_param, 'counselor', 'confirmed', counselor_note);
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to confirm and settle report
CREATE OR REPLACE FUNCTION counselor_confirm_settle(
  report_uuid UUID,
  counselor_id_param UUID,
  settlement_note TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Update report status
  UPDATE reports
  SET 
    status = 'settled',
    updated_at = NOW()
  WHERE id = report_uuid;
  
  -- Create activity log
  INSERT INTO report_activity_logs (report_id, actor_id, role, action, note)
  VALUES (
    report_uuid, 
    counselor_id_param, 
    'counselor', 
    'confirmed', 
    COALESCE(settlement_note, 'Report confirmed and settled')
  );
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to get case record details with full timeline
CREATE OR REPLACE FUNCTION get_case_record_timeline(report_uuid UUID)
RETURNS TABLE (
  action TEXT,
  role TEXT,
  actor_name TEXT,
  note TEXT,
  "timestamp" TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ral.action,
    ral.role,
    u.full_name as actor_name,
    ral.note,
    ral.timestamp
  FROM report_activity_logs ral
  LEFT JOIN users u ON ral.actor_id = u.id
  WHERE ral.report_id = report_uuid
  ORDER BY ral.timestamp ASC;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION counselor_accept_report(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION counselor_confirm_settle(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_case_record_timeline(UUID) TO authenticated;

-- ============================================
-- 3. VERIFICATION QUERIES
-- ============================================

-- Check if counselor view exists
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_name = 'counselor_case_records_view';

-- Check if counselor functions exist
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_name IN (
  'counselor_accept_report', 
  'counselor_confirm_settle',
  'get_case_record_timeline'
);

-- ============================================
-- COUNSELOR REPORTS SCHEMA COMPLETE
-- ============================================
-- This schema provides:
-- 1. Counselor case records view with full case information
-- 2. Helper functions for accepting and confirming/settling reports
-- 3. Function to get case record timeline
-- 
-- Note: Access control is handled in the application layer
-- RLS is NOT enabled on tables
-- Storage policies are NOT configured - handled in application layer
-- ============================================

