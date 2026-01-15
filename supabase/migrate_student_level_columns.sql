-- Migration Script: Add Student Level Columns
-- ================================================
-- Run this script in Supabase SQL Editor to add student level support
-- This is safe to run multiple times - it will only add columns that don't exist

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
    ADD COLUMN student_level text;
    
    -- Add check constraint after column is created
    ALTER TABLE public.users
    ADD CONSTRAINT users_student_level_check
    CHECK (student_level IS NULL OR student_level IN ('junior_high', 'senior_high', 'college'));
    
    RAISE NOTICE 'Added student_level column with constraint';
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

