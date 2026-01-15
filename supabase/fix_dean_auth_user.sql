-- Fix Dean User Authentication Issue
-- ================================================
-- This script checks and fixes the auth user for dean@gmail.com
-- Run this in Supabase SQL Editor

-- Step 1: Check if auth user exists in auth.users
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  encrypted_password IS NOT NULL as has_password
FROM auth.users
WHERE email = 'dean@gmail.com';

-- Step 2: Check if user exists in public.users table
SELECT 
  id,
  gmail,
  full_name,
  role,
  department,
  status
FROM public.users
WHERE gmail = 'dean@gmail.com';

-- Step 3: If auth user EXISTS but email is NOT confirmed, confirm it:
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email = 'dean@gmail.com'
  AND email_confirmed_at IS NULL;

-- Step 4: Verify the fix
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  encrypted_password IS NOT NULL as has_password
FROM auth.users
WHERE email = 'dean@gmail.com';

-- ============================================
-- IF AUTH USER DOES NOT EXIST:
-- ============================================
-- The auth user must be created via Supabase Auth API or Dashboard
-- You have two options:

-- OPTION A: Delete and Recreate (Recommended)
-- 1. Delete from public.users:
--    DELETE FROM public.users WHERE gmail = 'dean@gmail.com';
-- 2. Then recreate the user via the app (Create User dialog)

-- OPTION B: Create Auth User via Supabase Dashboard
-- 1. Go to Supabase Dashboard → Authentication → Users
-- 2. Click "Add User" → "Create new user"
-- 3. Enter email: dean@gmail.com
-- 4. Enter password (the same password used when creating the user)
-- 5. Check "Auto Confirm User"
-- 6. Click "Create User"
-- 7. The auth user ID must match the ID in public.users table
--    If IDs don't match, update public.users:
--    UPDATE public.users 
--    SET id = 'NEW_AUTH_USER_ID_HERE' 
--    WHERE gmail = 'dean@gmail.com';

-- ============================================
-- IF PASSWORD IS WRONG:
-- ============================================
-- Reset password via Supabase Dashboard:
-- 1. Go to Supabase Dashboard → Authentication → Users
-- 2. Find dean@gmail.com
-- 3. Click on the user
-- 4. Click "Reset Password" or "Send Password Reset Email"

