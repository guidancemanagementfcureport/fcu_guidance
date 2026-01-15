-- ============================================
-- ANONYMOUS REPORT CHATBOX SCHEMA
-- ============================================
-- This file adds support for anonymous chat messaging
-- Run this AFTER anonymous_reports_schema.sql
-- ============================================

-- ============================================
-- 1. CREATE ANONYMOUS REPORTS TABLE (if not exists)
-- ============================================
-- This table stores anonymous reports with case codes
CREATE TABLE IF NOT EXISTS anonymous_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_code TEXT UNIQUE NOT NULL,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add index for case_code lookups
CREATE INDEX IF NOT EXISTS idx_anonymous_reports_case_code 
ON anonymous_reports(case_code);

-- Add status check constraint
ALTER TABLE anonymous_reports
DROP CONSTRAINT IF EXISTS check_anonymous_report_status;

ALTER TABLE anonymous_reports
ADD CONSTRAINT check_anonymous_report_status
CHECK (status IN ('pending', 'ongoing', 'resolved'));

-- ============================================
-- 2. CREATE ANONYMOUS REPORT TEACHERS TABLE
-- ============================================
-- Links anonymous reports to selected teachers
CREATE TABLE IF NOT EXISTS anonymous_report_teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES anonymous_reports(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(report_id, teacher_id)
);

-- Add index for teacher lookups
CREATE INDEX IF NOT EXISTS idx_anonymous_report_teachers_report_id 
ON anonymous_report_teachers(report_id);

CREATE INDEX IF NOT EXISTS idx_anonymous_report_teachers_teacher_id 
ON anonymous_report_teachers(teacher_id);

-- ============================================
-- 3. CREATE ANONYMOUS MESSAGES TABLE
-- ============================================
-- Stores all chat messages between anonymous users and teachers
CREATE TABLE IF NOT EXISTS anonymous_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES anonymous_reports(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('anonymous', 'teacher', 'counselor', 'dean', 'admin')),
  sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Only for teachers
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_anonymous_messages_report_id 
ON anonymous_messages(report_id);

CREATE INDEX IF NOT EXISTS idx_anonymous_messages_created_at 
ON anonymous_messages(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_anonymous_messages_sender_type 
ON anonymous_messages(sender_type);

CREATE INDEX IF NOT EXISTS idx_anonymous_messages_is_read 
ON anonymous_messages(is_read) WHERE is_read = false;

-- ============================================
-- 4. FUNCTION TO GENERATE CASE CODE
-- ============================================
-- Generates unique case codes in format: AR-XXXXXX
CREATE OR REPLACE FUNCTION generate_case_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Excludes confusing chars
  result TEXT := 'AR-';
  i INTEGER;
BEGIN
  -- Generate 6 random characters
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
  END LOOP;
  
  -- Check if case_code already exists, regenerate if needed
  WHILE EXISTS (SELECT 1 FROM anonymous_reports WHERE case_code = result) LOOP
    result := 'AR-';
    FOR i IN 1..6 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
    END LOOP;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. TRIGGER TO UPDATE UPDATED_AT
-- ============================================
CREATE OR REPLACE FUNCTION update_anonymous_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_anonymous_reports_updated_at
  BEFORE UPDATE ON anonymous_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_anonymous_reports_updated_at();

-- ============================================
-- 6. FUNCTION TO GET UNREAD MESSAGE COUNT FOR TEACHER
-- ============================================
CREATE OR REPLACE FUNCTION get_teacher_unread_count(p_teacher_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM anonymous_messages am
    INNER JOIN anonymous_report_teachers art ON am.report_id = art.report_id
    WHERE art.teacher_id = p_teacher_id
      AND am.sender_type = 'anonymous'
      AND am.is_read = false
  );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. RLS POLICIES (if RLS is enabled)
-- ============================================
-- Note: Adjust these based on your security requirements
-- For anonymous access, you may need to use service role or Edge Functions

-- Allow anonymous users to create reports (if using service role)
COMMENT ON TABLE anonymous_reports IS 'Anonymous reports with case codes for chat system. No personal information stored.';

COMMENT ON TABLE anonymous_messages IS 'Chat messages between anonymous users and teachers. Preserves strict anonymity.';

-- ============================================
-- 8. VERIFICATION QUERIES
-- ============================================

-- Check if tables were created
SELECT 
  'Tables created!' as status,
  table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('anonymous_reports', 'anonymous_report_teachers', 'anonymous_messages')
ORDER BY table_name;

-- Check if indexes were created
SELECT 
  'Indexes created!' as status,
  indexname,
  tablename
FROM pg_indexes
WHERE tablename IN ('anonymous_reports', 'anonymous_report_teachers', 'anonymous_messages')
ORDER BY tablename, indexname;

-- ============================================
-- 9. FUNCTION TO CREATE ANONYMOUS REPORT AND ASSIGN TEACHERS
-- ============================================
CREATE OR REPLACE FUNCTION create_anonymous_report_with_teachers(
  p_category TEXT,
  p_description TEXT,
  p_teacher_ids UUID[]
)
RETURNS json AS $$
DECLARE
  new_report_id UUID;
  new_case_code TEXT;
  teacher_id UUID;
BEGIN
  -- 1. Generate a case code
  new_case_code := generate_case_code();
  
  -- 2. Insert the new anonymous report
  INSERT INTO public.anonymous_reports (case_code, category, description, status)
  VALUES (new_case_code, p_category, p_description, 'pending')
  RETURNING id INTO new_report_id;
  
  -- 3. Assign the selected teachers to the report
  IF array_length(p_teacher_ids, 1) > 0 THEN
    FOREACH teacher_id IN ARRAY p_teacher_ids
    LOOP
      INSERT INTO public.anonymous_report_teachers (report_id, teacher_id)
      VALUES (new_report_id, teacher_id);
    END LOOP;
  END IF;
  
  -- 4. Return the new report's ID and case code
  RETURN json_build_object('id', new_report_id, 'case_code', new_case_code);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 10. FUNCTION TO GET ANONYMOUS REPORT (BYPASS RLS)
-- ============================================
CREATE OR REPLACE FUNCTION get_anonymous_report_by_case_code_public(p_case_code TEXT)
RETURNS json AS $$
DECLARE
  report_data json;
BEGIN
  SELECT json_build_object(
    'id', id,
    'case_code', case_code,
    'category', category,
    'description', description,
    'status', status,
    'created_at', created_at,
    'updated_at', updated_at
  )
  INTO report_data
  FROM public.anonymous_reports
  WHERE case_code = p_case_code;
  
  RETURN report_data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ANONYMOUS CHAT SCHEMA SETUP COMPLETE
-- ============================================
-- 
-- Next steps:
-- 1. Test case code generation
-- 2. Test anonymous report creation
-- 3. Test message sending/receiving
-- 4. Test teacher message inbox
-- 5. Ensure RLS policies are configured correctly
--
-- ============================================

