# Email Confirmation Setup Guide

## 🔐 Problem: Users Cannot Login After Creation

If users (especially Dean, Teacher, Counselor accounts) cannot login after being created, it's likely because their email address hasn't been confirmed in Supabase Auth.

## ✅ Solution 1: Auto-Confirm Trigger (Recommended)

The auto-confirm trigger automatically confirms email addresses when users are created, allowing them to login immediately.

### Setup Steps:

1. **Open Supabase SQL Editor**
   - Go to your Supabase project dashboard
   - Navigate to **SQL Editor** in the left sidebar
   - Click **New Query**

2. **Run the Auto-Confirm Trigger Script**
   - Open the file: `supabase/auto_confirm_users_trigger.sql`
   - Copy the entire contents
   - Paste into the Supabase SQL Editor
   - Click **Run** (or press `Ctrl+Enter` / `Cmd+Enter`)

3. **Verify the Trigger is Active**
   ```sql
   SELECT 
     trigger_name,
     event_manipulation,
     event_object_table
   FROM information_schema.triggers
   WHERE trigger_name = 'on_auth_user_created';
   ```

### How It Works:

- When a new user is created via `auth.signUp()`, the trigger automatically sets `email_confirmed_at = NOW()`
- This allows users to login immediately without email confirmation
- The trigger runs with `SECURITY DEFINER` to have permission to update `auth.users`

## ✅ Solution 2: Manually Confirm All Users (Quick Fix)

If you have multiple users that can't login, use this script to confirm all at once:

1. **Open Supabase SQL Editor**
2. **Run the Confirm All Users Script**
   - Open the file: `supabase/confirm_all_user_emails.sql`
   - Copy the entire contents
   - Paste into SQL Editor
   - Click **Run**
   - This will confirm all unconfirmed user emails

## ✅ Solution 3: Manually Confirm Specific User

If you need to confirm a specific user:

1. **Open Supabase SQL Editor**
2. **Run the Manual Confirmation Script**
   - Open the file: `supabase/manually_confirm_users.sql`
   - Update the email address in the script (e.g., `'dean@gmail.com'`)
   - Copy and paste into SQL Editor
   - Click **Run**

### For Specific User:
```sql
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email = 'dean@gmail.com';
```

### For All Unconfirmed Users:
```sql
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email_confirmed_at IS NULL;
```

## ✅ Solution 3: Disable Email Confirmation (Not Recommended)

If you don't want email confirmation at all:

1. Go to **Supabase Dashboard** → **Authentication** → **Settings**
2. Find **Email Auth** section
3. **Disable** "Enable email confirmations"
4. Save changes

⚠️ **Note**: This is less secure and not recommended for production.

## 🔍 Troubleshooting

### Error: "Invalid login credentials"
- **Cause**: Email not confirmed or user doesn't exist
- **Fix**: Run the auto-confirm trigger or manually confirm the user

### Error: "Trigger not working"
- **Check**: Verify the trigger exists in `information_schema.triggers`
- **Fix**: Re-run the `auto_confirm_users_trigger.sql` script
- **Note**: The trigger requires `SECURITY DEFINER` permissions

### Error: "Permission denied" when running trigger script
- **Cause**: Insufficient database permissions
- **Fix**: Ensure you're running as a database admin or service role

### Users created before trigger setup
- **Fix**: Run the manual confirmation script for those users
- **Or**: Recreate the users (they will be auto-confirmed)

## 📋 Verification Checklist

After setting up email confirmation:

- [ ] Auto-confirm trigger is installed and active
- [ ] New users can login immediately after creation
- [ ] Existing users are confirmed (if using manual script)
- [ ] No "Invalid login credentials" errors for valid accounts

## 🚀 Quick Fix for Dean User

If the Dean user (`dean@gmail.com`) cannot login:

### Step 1: Check if Auth User Exists

Run this in Supabase SQL Editor:
```sql
SELECT id, email, email_confirmed_at, created_at
FROM auth.users
WHERE email = 'dean@gmail.com';
```

### Step 2A: If Auth User EXISTS but Email Not Confirmed

Run this to confirm the email:
```sql
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email = 'dean@gmail.com';
```

### Step 2B: If Auth User DOES NOT EXIST

The auth user was never created. You have two options:

**Option 1: Delete and Recreate (Recommended)**
1. Delete from `public.users`:
   ```sql
   DELETE FROM public.users WHERE gmail = 'dean@gmail.com';
   ```
2. Recreate the user via the app (Create User dialog)

**Option 2: Create Auth User via Dashboard**
1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Click **"Add User"** → **"Create new user"**
3. Enter email: `dean@gmail.com`
4. Enter password (the same password used when creating the user)
5. Check **"Auto Confirm User"**
6. Click **"Create User"**
7. **IMPORTANT**: The auth user ID must match the ID in `public.users` table
   - Get the auth user ID from the dashboard
   - Update `public.users`:
     ```sql
     UPDATE public.users 
     SET id = 'NEW_AUTH_USER_ID_HERE' 
     WHERE gmail = 'dean@gmail.com';
     ```

### Step 3: Verify the Fix

```sql
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at
FROM auth.users
WHERE email = 'dean@gmail.com';
```

### Step 4: Try Logging In

After confirming the email or creating the auth user, try logging in again.

---

**For a complete diagnostic and fix script, see: `supabase/fix_dean_auth_user.sql`**

**After setup, all new users will be automatically confirmed and can login immediately!**

