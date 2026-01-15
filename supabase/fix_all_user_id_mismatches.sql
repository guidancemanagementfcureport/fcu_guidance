-- Fix All User ID Mismatches Between auth.users and public.users
-- ================================================
-- This script finds and fixes ID mismatches for all users
-- Run this in Supabase SQL Editor

-- Step 1: Find all users with ID mismatches
SELECT 
  au.id as auth_id,
  pu.id as public_id,
  au.email,
  pu.gmail,
  CASE 
    WHEN au.id = pu.id THEN 'IDs Match'
    ELSE 'IDs DO NOT MATCH - Needs Fix'
  END as status
FROM auth.users au
INNER JOIN public.users pu ON au.email = pu.gmail
WHERE au.id != pu.id
ORDER BY au.email;

-- Step 2: Fix ID mismatches by updating public.users to match auth.users
-- This updates all users where the IDs don't match
UPDATE public.users pu
SET id = au.id
FROM auth.users au
WHERE au.email = pu.gmail
  AND au.id != pu.id;

-- Step 3: Verify the fix
SELECT 
  au.id as auth_id,
  pu.id as public_id,
  au.email,
  pu.gmail,
  CASE 
    WHEN au.id = pu.id THEN '✅ IDs Now Match'
    ELSE '❌ IDs Still Don''t Match'
  END as status
FROM auth.users au
INNER JOIN public.users pu ON au.email = pu.gmail
ORDER BY au.email;

-- Expected result: All users should show "✅ IDs Now Match"

