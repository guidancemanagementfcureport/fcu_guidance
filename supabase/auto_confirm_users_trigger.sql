-- Auto-Confirm Users Trigger
-- ================================================
-- This trigger automatically confirms email addresses for users created via signUp
-- This allows users to login immediately without email confirmation
-- while keeping email confirmation enabled in Supabase Auth settings
--
-- IMPORTANT: Run this script in Supabase SQL Editor to set up auto-confirmation

-- Create function to auto-confirm users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-confirm the user's email immediately
  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger that fires after a user is inserted into auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Verify the trigger was created
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- Note: This requires the function to run with SECURITY DEFINER
-- which allows it to update auth.users table

