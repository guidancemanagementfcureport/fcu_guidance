# Troubleshooting Login Issues

## "Invalid login credentials" Error

If you're getting "Invalid login credentials" when trying to login, follow these steps:

### Step 1: Verify User Was Created in Supabase Auth

1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Search for the user's Gmail address
3. Check if the user exists:
   - ✅ **User exists**: Continue to Step 2
   - ❌ **User doesn't exist**: The user creation failed. Check the error logs in the app.

### Step 2: Verify Email Confirmation Status

1. In the **Users** list, click on the user
2. Check the **"Email Confirmed"** status:
   - ✅ **Confirmed**: Continue to Step 3
   - ❌ **Not confirmed**: 
     - Run the auto-confirm trigger: `supabase/auto_confirm_users_trigger.sql`
     - OR manually check the "Email Confirmed" checkbox
     - OR run this SQL:
       ```sql
       UPDATE auth.users
       SET email_confirmed_at = NOW()
       WHERE email = 'user@gmail.com';  -- Replace with actual email
       ```

### Step 3: Verify Password

**Important**: Make sure you're using the **exact password** shown in the creation dialog.

1. Check the password shown when the user was created
2. Ensure there are no extra spaces or characters
3. If password was auto-generated, copy it exactly (6 digits)
4. If password was manually entered, ensure it matches what was typed

### Step 4: Verify Email Address

1. Make sure you're using the **exact Gmail address** used during creation
2. Check for typos
3. Ensure it's lowercase (the system normalizes to lowercase)
4. No extra spaces before or after

### Step 5: Check User Status in Database

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Run this query (replace with actual email):
   ```sql
   SELECT * FROM public.users 
   WHERE gmail = 'user@gmail.com';  -- Replace with actual email
   ```
3. Verify:
   - User exists in `public.users` table
   - `status` is `'active'`
   - `id` matches the auth user ID

### Step 6: Test Login Directly in Supabase

1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Find the user
3. Click **"Send magic link"** or **"Reset password"**
4. This helps verify the email and auth user are set up correctly

## Common Issues and Solutions

### Issue: User Created But Can't Login

**Possible causes:**
1. Email not confirmed → Run auto-confirm trigger or manually confirm
2. Wrong password → Use exact password from creation dialog
3. User doesn't exist in `public.users` → Check database

**Solution:**
```sql
-- Check if user exists in both tables
SELECT 
  au.id as auth_id,
  au.email,
  au.email_confirmed_at,
  u.id as user_id,
  u.gmail,
  u.status
FROM auth.users au
LEFT JOIN public.users u ON au.id = u.id
WHERE au.email = 'user@gmail.com';  -- Replace with actual email
```

### Issue: Password Doesn't Work

**Check:**
1. Password shown in dialog matches what you're typing
2. No extra spaces (copy-paste the password)
3. Password is at least 6 characters
4. If auto-generated, it's exactly 6 digits

**Solution:**
- Reset password in Supabase Dashboard
- Or create a new user with a known password

### Issue: Email Confirmation Required

**Symptoms:**
- Error: "Email not confirmed"
- User exists but can't login

**Solution:**
1. Run the auto-confirm trigger: `supabase/auto_confirm_users_trigger.sql`
2. Or manually confirm in Supabase Dashboard
3. Or run SQL:
   ```sql
   UPDATE auth.users
   SET email_confirmed_at = NOW()
   WHERE email_confirmed_at IS NULL;
   ```

## Debugging Steps

### Enable Debug Logging

The app now includes debug logging. Check your console/terminal for:
- `Creating auth user with email: ...`
- `Auth user created successfully with ID: ...`
- `Attempting sign in with email: ...`
- `Sign in error: ...`

### Verify User Creation Flow

1. **Create user** via Admin panel
2. **Check console logs** for:
   - "Auth user created successfully"
   - "Email confirmed" or "Email not confirmed"
3. **Check Supabase Dashboard**:
   - User exists in Authentication → Users
   - User exists in Table Editor → users
4. **Try login** with exact credentials

### SQL Queries for Verification

```sql
-- Check all users and their confirmation status
SELECT 
  email,
  email_confirmed_at,
  created_at
FROM auth.users
ORDER BY created_at DESC;

-- Check users table
SELECT 
  gmail,
  full_name,
  role,
  status,
  created_at
FROM public.users
ORDER BY created_at DESC;

-- Check if auth user and users table are linked
SELECT 
  au.email as auth_email,
  u.gmail as user_gmail,
  au.id = u.id as ids_match,
  au.email_confirmed_at is not null as email_confirmed
FROM auth.users au
LEFT JOIN public.users u ON au.id = u.id
WHERE au.email = 'user@gmail.com';  -- Replace with actual email
```

## Still Having Issues?

1. **Check Supabase logs**: Dashboard → Logs → Auth
2. **Verify trigger is set up**: Run `SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';`
3. **Check email confirmation setting**: Authentication → Settings
4. **Try creating a test user** with a simple password to verify the flow

---

**Last Updated**: 2024  
**Version**: 1.0.0

