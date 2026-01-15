-- ============================================
-- ADMIN REPORT ANALYTICS & RECORDS MODULE
-- ============================================

-- This schema provides the necessary views and functions for the admin dashboard
-- to get a comprehensive overview of all guidance-related cases.

-- ============================================
-- 1. COMPREHENSIVE CASE VIEW FOR ADMINS
-- ============================================

CREATE OR REPLACE VIEW public.admin_all_cases_view AS
SELECT
    ac.id AS case_id,
    ac.case_code,
    ac.title AS report_category,
    ac.details AS report_details,
    ac.created_at AS date_submitted,
    ac.status,
    ac.is_anonymous,
    (SELECT COUNT(*) FROM public.case_messages cm WHERE cm.case_id = ac.id) AS message_count,
    (SELECT MAX(cm.created_at) FROM public.case_messages cm WHERE cm.case_id = ac.id) AS last_message_timestamp,

    -- Assigned Teacher
    (SELECT p.full_name FROM public.profiles p JOIN public.case_participants cp ON p.id = cp.user_id WHERE cp.case_id = ac.id AND cp.role = 'teacher' LIMIT 1) AS teacher_name,
    (SELECT p.id FROM public.profiles p JOIN public.case_participants cp ON p.id = cp.user_id WHERE cp.case_id = ac.id AND cp.role = 'teacher' LIMIT 1) AS teacher_id,

    -- Assigned Counselor
    (SELECT p.full_name FROM public.profiles p JOIN public.case_participants cp ON p.id = cp.user_id WHERE cp.case_id = ac.id AND cp.role = 'counselor' LIMIT 1) AS counselor_name,
    (SELECT p.id FROM public.profiles p JOIN public.case_participants cp ON p.id = cp.user_id WHERE cp.case_id = ac.id AND cp.role = 'counselor' LIMIT 1) AS counselor_id,

    -- Assigned Dean
    (SELECT p.full_name FROM public.profiles p JOIN public.case_participants cp ON p.id = cp.user_id WHERE cp.case_id = ac.id AND cp.role = 'dean' LIMIT 1) AS dean_name,
    (SELECT p.id FROM public.profiles p JOIN public.case_participants cp ON p.id = cp.user_id WHERE cp.case_id = ac.id AND cp.role = 'dean' LIMIT 1) AS dean_id

FROM
    public.anonymous_cases ac;

-- ============================================
-- 2. ROW LEVEL SECURITY (RLS) FOR THE VIEW
-- ============================================

-- First, ensure the view owner is secure (e.g., postgres or a dedicated admin role)
-- ALTER VIEW public.admin_all_cases_view OWNER TO postgres;

-- Enable RLS on the view
ALTER VIEW public.admin_all_cases_view ENABLE ROW LEVEL SECURITY;

-- Grant access to admins
CREATE POLICY "Allow admins to view all case records" ON public.admin_all_cases_view
FOR SELECT
TO authenticated
USING (
  (SELECT public.is_admin()) -- is_admin() is a function that should check if the user has an 'admin' role.
);

-- ============================================
-- 3. HELPER FUNCTION TO CHECK FOR ADMIN ROLE
-- ============================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function to authenticated users
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
