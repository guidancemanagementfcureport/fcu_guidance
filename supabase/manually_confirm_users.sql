-- Manually Confirm User Emails
-- ================================================
-- This script manually confirms email addresses for users in auth.users
-- Use this if the auto-confirm trigger isn't working or for existing users
-- 
-- IMPORTANT: Run this in Supabase SQL Editor with proper permissions

-- Option 1: Confirm email for a specific user by email
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email = 'dean@gmail.com';

-- Option 2: Confirm email for all users that aren't confirmed yet
-- UPDATE auth.users
-- SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
-- WHERE email_confirmed_at IS NULL;

-- Option 3: Confirm email for a specific user by ID
-- UPDATE auth.users
-- SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
-- WHERE id = 'USER_ID_HERE';

-- Verify the update
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at
FROM auth.users
WHERE email = 'dean@gmail.com';

