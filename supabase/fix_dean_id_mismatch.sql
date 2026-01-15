-- Fix Dean User Login Issue - Complete Diagnostic and Fix
-- ================================================
-- This script checks and fixes all potential issues
-- Run this in Supabase SQL Editor

-- ============================================
-- STEP 1: Check auth user details
-- ============================================
SELECT 
  id as auth_user_id,
  email,
  email_confirmed_at,
  created_at,
  encrypted_password IS NOT NULL as has_password
FROM auth.users
WHERE email = 'dean@gmail.com';

-- ============================================
-- STEP 2: Check public.users details
-- ============================================
SELECT 
  id as public_user_id,
  gmail,
  full_name,
  role,
  department,
  status
FROM public.users
WHERE gmail = 'dean@gmail.com';

-- ============================================
-- STEP 3: Check if IDs match (CRITICAL!)
-- ============================================
SELECT 
  au.id as auth_id,
  pu.id as public_id,
  au.email,
  pu.gmail,
  CASE 
    WHEN au.id = pu.id THEN 'IDs Match'
    ELSE 'IDs DO NOT MATCH - This is the problem!'
  END as id_status,
  CASE 
    WHEN au.email_confirmed_at IS NOT NULL THEN 'Email Confirmed'
    ELSE 'Email Not Confirmed'
  END as email_status
FROM auth.users au
FULL OUTER JOIN public.users pu ON au.email = pu.gmail
WHERE au.email = 'dean@gmail.com' OR pu.gmail = 'dean@gmail.com';

-- ============================================
-- STEP 4: FIX ID MISMATCH (if IDs don't match)
-- ============================================
-- IMPORTANT: Get the auth_user_id from Step 1, then run this:
-- Replace '10302e19-9ac0-4386-97e6-7a70e55b791c' with the actual auth user ID

-- First, check what the current public.users ID is:
SELECT id FROM public.users WHERE gmail = 'dean@gmail.com';

-- Then update public.users to match auth.users ID:
UPDATE public.users
SET id = '10302e19-9ac0-4386-97e6-7a70e55b791c'  -- REPLACE WITH AUTH USER ID FROM STEP 1
WHERE gmail = 'dean@gmail.com';

-- ============================================
-- STEP 5: Verify the fix
-- ============================================
SELECT 
  au.id as auth_id,
  pu.id as public_id,
  au.email,
  pu.gmail,
  CASE 
    WHEN au.id = pu.id THEN 'IDs Now Match - Ready to test login!'
    ELSE 'IDs Still Don''t Match - Check the UPDATE statement'
  END as status
FROM auth.users au
INNER JOIN public.users pu ON au.id = pu.id
WHERE au.email = 'dean@gmail.com';

-- ============================================
-- IF LOGIN STILL FAILS AFTER ID FIX:
-- ============================================
-- The password might be incorrect. Reset it via:

-- OPTION 1: Supabase Dashboard (Easiest)
-- 1. Go to Authentication → Users
-- 2. Find dean@gmail.com
-- 3. Click on the user
-- 4. Click "Send Password Reset Email" or "Reset Password"
-- 5. Set a new password

-- OPTION 2: Use Supabase Admin API (requires service role key)
-- POST https://YOUR_PROJECT.supabase.co/auth/v1/admin/users/USER_ID
-- Headers: { "Authorization": "Bearer SERVICE_ROLE_KEY" }
-- Body: { "password": "new_password_here" }

-- OPTION 3: Delete and Recreate (if all else fails)
-- DELETE FROM public.users WHERE gmail = 'dean@gmail.com';
-- DELETE FROM auth.users WHERE email = 'dean@gmail.com';
-- Then recreate via the app

