-- Fix Existing Users - Verify and Confirm Auth Users
-- ================================================
-- This script helps fix users that exist in public.users but can't login
-- Run this if you have users that were created but can't authenticate

-- Step 1: Check which users exist in public.users but may have issues in auth.users
SELECT 
  u.id,
  u.gmail,
  u.full_name,
  u.role,
  CASE 
    WHEN au.id IS NULL THEN 'MISSING AUTH USER'
    WHEN au.email_confirmed_at IS NULL THEN 'EMAIL NOT CONFIRMED'
    ELSE 'OK'
  END as status
FROM public.users u
LEFT JOIN auth.users au ON u.id = au.id
ORDER BY u.created_at DESC;

-- Step 2: Confirm all existing auth users (if they exist)
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email_confirmed_at IS NULL
AND id IN (SELECT id FROM public.users);

-- Step 3: Verify the fix
SELECT 
  u.gmail,
  u.full_name,
  au.email_confirmed_at IS NOT NULL as email_confirmed,
  au.created_at as auth_created_at
FROM public.users u
LEFT JOIN auth.users au ON u.id = au.id
WHERE au.id IS NOT NULL;

-- Note: If a user shows "MISSING AUTH USER", you need to:
-- 1. Delete the user from public.users
-- 2. Recreate the user via the Admin panel in the app
-- OR manually create the auth user in Supabase Dashboard

