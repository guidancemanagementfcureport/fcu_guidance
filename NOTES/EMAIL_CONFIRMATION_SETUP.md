# Email Confirmation Setup Guide

## Problem

When email confirmation is **enabled** in Supabase:
- New users can't login until they confirm their email
- Users need to check their email and click a confirmation link

When email confirmation is **disabled**:
- Security is reduced
- Any email can be used without verification

## Solution: Auto-Confirm Trigger

We'll keep email confirmation **enabled** for security, but use a database trigger to **automatically confirm** users when they're created.

### Step 1: Enable Email Confirmation in Supabase

1. Go to **Supabase Dashboard** → **Authentication** → **Settings**
2. Find **"Enable email confirmations"**
3. **Turn it ON** (enable it)
4. Save changes

### Step 2: Run the Auto-Confirm Trigger

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Open the file: `fcu_app/supabase/auto_confirm_users_trigger.sql`
3. Copy and paste the SQL into the editor
4. Click **"Run"** to execute

This creates a trigger that automatically confirms users when they're created via `signUp()`.

### Step 3: Confirm Existing Users (Admin, etc.)

For users that were created before the trigger was set up:

1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Find the user (e.g., your admin account)
3. Click on the user
4. Check the **"Email Confirmed"** checkbox
5. Save changes

**OR** run this SQL for all existing users:

```sql
-- Confirm all existing users
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email_confirmed_at IS NULL;
```

### Step 4: Test

1. Create a new user via the Admin panel
2. The user should be automatically confirmed
3. Try logging in with the new user's credentials
4. Login should work immediately without email confirmation

## How It Works

1. **Email confirmation is enabled** → Security maintained
2. **Database trigger auto-confirms** → Users can login immediately
3. **Best of both worlds** → Security + Convenience

## Troubleshooting

### "Email not confirmed" Error

**For new users:**
- Check if the trigger is set up correctly
- Verify the trigger exists: Run `SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';`
- Re-run the trigger SQL if needed

**For existing users:**
- Manually confirm them in Supabase Dashboard
- Or run the SQL update query above

### Admin Can't Login

1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Find your admin user
3. Ensure **"Email Confirmed"** is checked
4. If not, check it and save

### Trigger Not Working

1. Check if the function exists:
   ```sql
   SELECT * FROM pg_proc WHERE proname = 'handle_new_user';
   ```

2. Check if the trigger exists:
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
   ```

3. If missing, re-run the trigger SQL file

## Security Note

The trigger uses `SECURITY DEFINER` which allows it to update the `auth.users` table. This is safe because:
- The trigger only runs on INSERT
- It only sets `email_confirmed_at` if it's NULL
- It doesn't modify passwords or other sensitive data

---

**Last Updated**: 2024  
**Version**: 1.0.0

