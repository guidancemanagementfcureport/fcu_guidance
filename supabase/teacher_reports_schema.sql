-- ============================================
-- TEACHER REPORTS SCHEMA
-- ============================================
-- Schema for Teacher Student Reports & Incidents functionality
-- This file contains views and functions specific to teachers
-- Note: RLS is NOT enabled - access control handled in application layer
-- ============================================

-- ============================================
-- 1. TEACHER REPORTS VIEW
-- ============================================
-- A view that shows reports with teacher-friendly information

CREATE OR REPLACE VIEW teacher_reports_view AS
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
  -- Teacher information
  u_teacher.full_name as teacher_name,
  u_teacher.gmail as teacher_email,
  -- Counselor information
  u_counselor.full_name as counselor_name,
  u_counselor.gmail as counselor_email,
  -- Activity information
  (SELECT COUNT(*) FROM report_activity_logs WHERE report_id = r.id) as activity_count,
  (SELECT MAX(timestamp) FROM report_activity_logs WHERE report_id = r.id) as last_activity,
  -- Check if teacher has reviewed
  EXISTS (
    SELECT 1 FROM report_activity_logs 
    WHERE report_id = r.id 
    AND actor_id = r.teacher_id 
    AND action = 'reviewed'
  ) as is_reviewed,
  -- Check if forwarded to counselor
  EXISTS (
    SELECT 1 FROM report_activity_logs 
    WHERE report_id = r.id 
    AND actor_id = r.teacher_id 
    AND action = 'forwarded'
  ) as is_forwarded
FROM reports r
LEFT JOIN users u_student ON r.student_id = u_student.id
LEFT JOIN users u_teacher ON r.teacher_id = u_teacher.id
LEFT JOIN users u_counselor ON r.counselor_id = u_counselor.id;

-- Grant access to authenticated users
GRANT SELECT ON teacher_reports_view TO authenticated;

-- ============================================
-- 2. HELPER FUNCTIONS FOR TEACHER ACTIONS
-- ============================================

-- Function to mark report as reviewed by teacher
CREATE OR REPLACE FUNCTION teacher_mark_reviewed(
  report_uuid UUID,
  teacher_id_param UUID,
  teacher_note TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Update report status
  UPDATE reports
  SET 
    status = 'teacher_reviewed',
    teacher_id = teacher_id_param,
    updated_at = NOW()
  WHERE id = report_uuid;
  
  -- Create activity log
  INSERT INTO report_activity_logs (report_id, actor_id, role, action, note)
  VALUES (report_uuid, teacher_id_param, 'teacher', 'reviewed', teacher_note);
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to forward report to counselor
CREATE OR REPLACE FUNCTION teacher_forward_to_counselor(
  report_uuid UUID,
  teacher_id_param UUID,
  counselor_uuid UUID,
  forward_note TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Update report status
  UPDATE reports
  SET 
    status = 'forwarded',
    teacher_id = teacher_id_param,
    counselor_id = counselor_uuid,
    updated_at = NOW()
  WHERE id = report_uuid;
  
  -- Create activity log
  INSERT INTO report_activity_logs (report_id, actor_id, role, action, note)
  VALUES (report_uuid, teacher_id_param, 'teacher', 'forwarded', forward_note);
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION teacher_mark_reviewed(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION teacher_forward_to_counselor(UUID, UUID, UUID, TEXT) TO authenticated;

-- ============================================
-- 3. VERIFICATION QUERIES
-- ============================================

-- Check if teacher view exists
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_name = 'teacher_reports_view';

-- Check if teacher functions exist
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_name IN ('teacher_mark_reviewed', 'teacher_forward_to_counselor');

-- ============================================
-- TEACHER REPORTS SCHEMA COMPLETE
-- ============================================
-- This schema provides:
-- 1. Teacher reports view with student/teacher/counselor information
-- 2. Helper functions for marking reviewed and forwarding to counselor
-- 
-- Note: Access control is handled in the application layer
-- RLS is NOT enabled on tables
-- Storage policies are NOT configured - handled in application layer
-- ============================================

