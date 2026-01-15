# Admin Account Setup Guide

## How to Create and Login as the First Admin Account

Since the system requires Gmail-only authentication and admin-created accounts, you need to manually create the first admin account through Supabase.

### Method 1: Using Supabase Dashboard (Easiest - Recommended)

#### Step 1: Create Auth User in Supabase

1. Go to your **Supabase Dashboard** → **Authentication** → **Users**
2. Click **"Add User"** or **"Create User"**
3. Fill in:
   - **Email**: Your Gmail address (e.g., `admin@gmail.com`)
   - **Password**: Create a secure password
   - **Auto Confirm User**: ✅ Enable this (so you can login immediately)
4. Click **"Create User"**
5. **Note the email address** you used (you'll need it in the next step)

#### Step 2: Create User Record in Database (Automatic UUID)

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Run this SQL query (replace `admin@gmail.com` with your actual Gmail):

```sql
-- This automatically gets the UUID from auth.users and creates the user record
INSERT INTO public.users (
    id,
    gmail,
    full_name,
    role,
    department,
    status,
    created_at
) 
SELECT 
    id,                                    -- Automatically gets UUID from auth.users
    email,                                 -- Automatically gets email from auth.users
    'System Administrator',                -- Your full name (change if needed)
    'admin',                               -- Role must be 'admin'
    'Administration',                      -- Department (change if needed)
    'active',                             -- Status
    NOW()                                  -- Created timestamp
FROM auth.users
WHERE email = 'admin@gmail.com'           -- ⚠️ CHANGE THIS to your Gmail address
ON CONFLICT (id) DO NOTHING;
```

**Important:** Replace `'admin@gmail.com'` with the actual Gmail address you used in Step 1!

**Example if your Gmail is `john.doe@gmail.com`:**
```sql
INSERT INTO public.users (
    id,
    gmail,
    full_name,
    role,
    department,
    status,
    created_at
) 
SELECT 
    id,
    email,
    'System Administrator',
    'admin',
    'Administration',
    'active',
    NOW()
FROM auth.users
WHERE email = 'john.doe@gmail.com'
ON CONFLICT (id) DO NOTHING;
```

#### Step 3: Verify the User Was Created

Run this query to check:
```sql
SELECT * FROM public.users WHERE gmail = 'admin@gmail.com';  -- Replace with your Gmail
```

You should see your admin user with `role = 'admin'` and `status = 'active'`.

#### Step 4: Login to the App

1. Open your Flutter app
2. Go to the **Login Page**
3. Enter:
   - **Email**: Your Gmail address (e.g., `admin@gmail.com`)
   - **Password**: The password you created in Step 1
4. Click **"Sign In"**
5. You should be redirected to the **Admin Dashboard**

### Method 2: Manual UUID Method (If Method 1 Doesn't Work)

If Method 1 doesn't work, you can manually specify the UUID:

#### Step 1: Get Your Auth User UUID

1. Go to **Supabase Dashboard** → **Authentication** → **Users**
2. Find your user and **copy the UUID** (it looks like: `123e4567-e89b-12d3-a456-426614174000`)

#### Step 2: Insert User Record with Manual UUID

Run this SQL (replace both the UUID and email):

```sql
INSERT INTO public.users (
    id,
    gmail,
    full_name,
    role,
    department,
    status,
    created_at
) VALUES (
    '123e4567-e89b-12d3-a456-426614174000',  -- ⚠️ PASTE YOUR UUID HERE
    'admin@gmail.com',                        -- ⚠️ YOUR GMAIL ADDRESS
    'System Administrator',
    'admin',
    'Administration',
    'active',
    NOW()
);
```

**Important:** 
- Replace `'123e4567-e89b-12d3-a456-426614174000'` with your actual UUID from Step 1
- Replace `'admin@gmail.com'` with your actual Gmail address

### Method 3: Using Supabase Admin API (For Developers)

If you have access to the Supabase Admin API:

```dart
// Create auth user first via Supabase Admin API
// Then create user record in database
```

## After Creating Admin Account

Once you're logged in as admin, you can:

1. **Create Other Users**: Go to **Admin Dashboard** → **User Management** → **Create New User**
2. **Manage Users**: View, edit, enable/disable, and delete users
3. **Access Admin Features**: All admin-only features will be available

## Troubleshooting

### "Invalid email or password"
- Verify the auth user was created correctly in Supabase Dashboard
- Check that the email matches exactly (case-sensitive)
- Ensure "Auto Confirm User" was enabled

### "Gmail not found. Please contact your administrator."
- The user record in `public.users` table doesn't exist
- Run the SQL INSERT query from Step 2
- Verify the `id` matches the auth user ID exactly

### "User not found" after login
- The `id` in `public.users` doesn't match `auth.users.id`
- Check both tables and ensure IDs match
- Re-run the INSERT query with the correct UUID

### Can't access Admin Dashboard
- Verify the `role` field in `public.users` is exactly `'admin'` (lowercase)
- Check the user status is `'active'`
- Refresh the app or sign out and sign in again

## Quick Reference

**Required Fields for Admin User:**
- `id`: UUID (must match `auth.users.id`)
- `gmail`: Gmail address (must match `auth.users.email`)
- `full_name`: Display name
- `role`: Must be `'admin'`
- `department`: Optional but recommended
- `status`: Must be `'active'`

**Login Credentials:**
- **Email**: Your Gmail address
- **Password**: Password set in Supabase Auth

---

**Note**: After creating the first admin, you can create other users (including additional admins) through the app's User Management interface.

