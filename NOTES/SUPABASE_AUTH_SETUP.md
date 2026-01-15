# Supabase Auth Setup for User Login

## Important: Email Confirmation Settings

For the user creation and login to work properly, you **MUST** disable email confirmation in Supabase.

### How to Disable Email Confirmation:

1. Go to your **Supabase Dashboard**
2. Navigate to **Authentication** → **Settings** (or **Configuration**)
3. Find the **"Enable email confirmations"** setting
4. **Turn it OFF** (disable it)
5. Save the changes

### Why This is Required:

- When email confirmation is **enabled**: Users created via `signUp()` must confirm their email before they can login
- When email confirmation is **disabled**: Users can login immediately after account creation

### Alternative: Auto-Confirm Users

If you prefer to keep email confirmation enabled, you can:

1. Go to **Authentication** → **Users**
2. Find the newly created user
3. Click on the user
4. Enable **"Auto Confirm User"** for that specific user

However, this requires manual intervention for each user, so **disabling email confirmation is recommended for MVP**.

## Testing User Login

After disabling email confirmation:

1. Create a new user via the Admin panel
2. Note the password shown in the dialog
3. Logout (if logged in as admin)
4. Try logging in with the new user's Gmail and password
5. You should be redirected to the appropriate dashboard based on role

## Troubleshooting

### "Invalid email or password" Error

**Possible causes:**
1. **Email confirmation is enabled** - Disable it in Supabase settings
2. **Wrong password** - Verify the password used during creation
3. **Email case sensitivity** - The system normalizes emails to lowercase
4. **User not in users table** - Check if the user record exists in `public.users`

### "Email not confirmed" Error

This means email confirmation is still enabled. Follow the steps above to disable it.

### User Created But Can't Login

1. Check Supabase Dashboard → Authentication → Users
2. Verify the user exists
3. Check if "Email Confirmed" is checked
4. If not, either:
   - Disable email confirmation globally, OR
   - Manually confirm the user in the dashboard

---

**Last Updated**: 2024  
**Version**: 1.0.0

