-- MVP User Management Schema (No RLS/Policies)
-- ================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Users Table
-- Note: If table already exists, run the MIGRATION section below instead
create table if not exists public.users (
    id uuid primary key,
    gmail text unique not null,
    full_name text not null,
    role text not null,
    course text,
    grade_level text,
    department text,
    status text default 'active',
    created_at timestamptz default now(),
    last_login timestamptz
);

-- Add comments for documentation
COMMENT ON TABLE public.users IS 'User accounts for FCU Guidance Management System. Student level information is automatically used in the report workflow for conditional routing (College reports must go to Dean, SHS/JHS can be finalized by Counselor).';
COMMENT ON COLUMN public.users.role IS 'User role: student, teacher, counselor, dean, or admin';
COMMENT ON COLUMN public.users.status IS 'Account status: active or inactive';
COMMENT ON COLUMN public.users.department IS 'Department for teachers, counselors, deans, and admins';
COMMENT ON COLUMN public.users.student_level IS 'Student academic level: junior_high, senior_high, or college. Used for conditional routing in report workflow - College reports require Dean approval, SHS/JHS can be finalized by Counselor.';
COMMENT ON COLUMN public.users.course IS 'Course/Program for college students. Displayed in reports and used for filtering.';
COMMENT ON COLUMN public.users.grade_level IS 'Grade level for junior high (7-10) or senior high (11-12) students. Displayed in reports and used for filtering.';
COMMENT ON COLUMN public.users.strand IS 'Strand for senior high students (e.g., STEM, HUMSS, ABM, GAS). Displayed in reports and used for filtering.';
COMMENT ON COLUMN public.users.section IS 'Section for junior high students (optional). Displayed in reports.';
COMMENT ON COLUMN public.users.year_level IS 'Year level for college students (1st-4th Year). Displayed in reports and used for filtering.';

-- Activity Logs Table
create table if not exists public.activity_logs (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references public.users(id) on delete cascade,
    action text not null,
    timestamp timestamptz default now()
);

-- Add comments for documentation
COMMENT ON TABLE public.activity_logs IS 'Activity logs for user actions';
COMMENT ON COLUMN public.activity_logs.action IS 'Action performed by the user';
COMMENT ON COLUMN public.activity_logs.timestamp IS 'When the action occurred';

-- ============================================
-- MIGRATION: Update existing tables to support Dean role and student levels
-- ============================================
-- IMPORTANT: Run this entire MIGRATION section if the users table already exists
-- This will safely add all missing columns and constraints

-- Add role check constraint if it doesn't exist
DO $$
BEGIN
  -- Drop existing constraint if it exists (to update it)
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_role_check'
  ) THEN
    ALTER TABLE public.users DROP CONSTRAINT users_role_check;
  END IF;
  
  -- Add updated constraint with Dean role
  ALTER TABLE public.users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('student', 'teacher', 'counselor', 'dean', 'admin'));
  RAISE NOTICE 'Updated role check constraint';
END $$;

-- Add status check constraint if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_status_check'
  ) THEN
    ALTER TABLE public.users
    ADD CONSTRAINT users_status_check
    CHECK (status IN ('active', 'inactive'));
    RAISE NOTICE 'Added status check constraint';
  ELSE
    RAISE NOTICE 'Status check constraint already exists';
  END IF;
END $$;

-- ============================================
-- MIGRATION: Add student level fields
-- ============================================
-- Run this section to add student level support to existing tables
-- IMPORTANT: Run this entire section in Supabase SQL Editor if you get
-- errors about missing 'student_level', 'strand', 'section', or 'year_level' columns

-- Add student_level column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'student_level'
  ) THEN
    ALTER TABLE public.users
    ADD COLUMN student_level text CHECK (student_level IN ('junior_high', 'senior_high', 'college'));
    RAISE NOTICE 'Added student_level column';
  ELSE
    RAISE NOTICE 'student_level column already exists';
  END IF;
END $$;

-- Add strand column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'strand'
  ) THEN
    ALTER TABLE public.users
    ADD COLUMN strand text;
    RAISE NOTICE 'Added strand column';
  ELSE
    RAISE NOTICE 'strand column already exists';
  END IF;
END $$;

-- Add section column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'section'
  ) THEN
    ALTER TABLE public.users
    ADD COLUMN section text;
    RAISE NOTICE 'Added section column';
  ELSE
    RAISE NOTICE 'section column already exists';
  END IF;
END $$;

-- Add year_level column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'year_level'
  ) THEN
    ALTER TABLE public.users
    ADD COLUMN year_level text;
    RAISE NOTICE 'Added year_level column';
  ELSE
    RAISE NOTICE 'year_level column already exists';
  END IF;
END $$;

-- ============================================
-- VERIFICATION: Check if columns were added successfully
-- ============================================
-- Run this query to verify all student level columns exist
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name IN ('student_level', 'strand', 'section', 'year_level')
ORDER BY column_name;

-- Expected output: 4 rows showing student_level, strand, section, and year_level columns

