# Admin User Creation System - Complete Guide

## Overview

This system allows **Admin users only** to create user accounts based on **School ID** (not email). Email is optional and stored for documentation purposes only.

## Key Features

✅ **ID-Based Login**: Users login with School ID + 6-digit password  
✅ **Auto-Generated Passwords**: System generates 6-digit numeric passwords  
✅ **Admin-Only Creation**: Only admins can create user accounts  
✅ **Role Management**: Admin can create Student, Teacher, Counselor, and Admin roles  
✅ **Password Management**: Reset, regenerate, and disable user accounts  
✅ **Modern UI**: Blue gradient theme with animated transitions  

## Architecture

### Files Structure

```
/lib
  /services
    auth_service.dart          # Authentication & user creation
    admin_service.dart         # Admin-specific operations
    supabase_service.dart     # Base Supabase client
  /models
    user_model.dart           # User data model (includes email field)
  /pages/admin
    create_user_page.dart     # Create new user form
    user_list_page.dart       # View and manage users
    user_management_page.dart # Legacy (can be updated)
  /widgets
    form_input.dart           # Reusable animated form field
    password_modal.dart       # Password display modal
  /utils
    password_generator.dart   # 6-digit password generator
```

## Database Schema

### Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  school_id TEXT UNIQUE NOT NULL,    -- Used for login (username)
  role TEXT NOT NULL,                -- student, teacher, counselor, admin
  full_name TEXT NOT NULL,
  email TEXT,                        -- Optional, for documentation only
  gender TEXT,
  grade_level TEXT,                  -- For students
  department TEXT,                   -- For teachers/counselors/admin
  is_active BOOLEAN DEFAULT true,
  is_archived BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Row-Level Security (RLS) Rules

1. **Students**: Can only view their own profile
2. **Teachers**: Cannot view other teachers
3. **Counselors**: Can view all students
4. **Admins**: Can view and manage all users
5. **User Creation**: Only admins can insert new users
6. **Role Updates**: Only admins can update user roles

## Setup Instructions

### 1. Database Setup

Run the SQL schema file:
```bash
fcu_app/lib/pages/supabase/admin_user_creation_schema.sql
```

This will:
- Add email column to users table (if not exists)
- Set up RLS policies
- Create necessary indexes

### 2. Supabase Auth Configuration

**Important**: Configure Supabase Auth settings:

1. Go to **Authentication > Settings** in Supabase Dashboard
2. **Disable email confirmation** (or set to auto-confirm)
   - This allows `signUp` to work without email verification
3. **Enable email provider** (required for auth, even though login uses School ID)

### 3. Service Role Key (For Production)

⚠️ **Security Note**: The service role key should **NEVER** be in the client app.

For production, create a **Supabase Edge Function** or **Backend API** that:
- Uses the service role key securely
- Handles user creation via admin API
- Validates admin permissions

Example Edge Function structure:
```typescript
// supabase/functions/create-user/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { schoolId, fullName, role, ... } = await req.json()
  
  // Verify admin user
  // Create auth user with service role
  // Insert into users table
  // Return password
})
```

## Usage Guide

### Creating a New User (Admin Only)

1. **Navigate to Create User Page**
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(builder: (context) => CreateUserPage()),
   );
   ```

2. **Fill Required Fields**:
   - Full Name *
   - School ID Number * (this becomes the username)
   - Role * (Student, Teacher, Counselor, Admin)
   - Gender (Optional)
   - Grade Level (for students) or Department (for staff)

3. **Optional Fields**:
   - Email (stored for documentation, NOT used for login)

4. **Submit Form**:
   - System generates 6-digit password
   - Password shown in modal
   - Admin can copy password
   - User can now login with School ID + password

### User Login Process

Users login with:
- **Username**: School ID (e.g., "STU001")
- **Password**: 6-digit numeric password (e.g., "123456")

Internally, the system uses:
- **Email**: `school_id@fcu.local` (e.g., "STU001@fcu.local")
- This is handled automatically by `AuthService.signIn()`

### Managing Users

#### View All Users
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => UserListPage()),
);
```

#### Reset Password
1. Open user menu (three dots)
2. Select "Reset Password"
3. New 6-digit password generated
4. Password shown in modal

#### Archive/Disable User
1. Open user menu
2. Select "Archive User" or "Activate User"
3. User status updated

#### Filter Users
- Use search bar to filter by name, ID, or email
- Use role chips to filter by role

## API Reference

### AuthService

#### `createUserByAdmin()`
Creates a new user account (Admin only).

```dart
final result = await authService.createUserByAdmin(
  fullName: 'John Doe',
  schoolId: 'STU001',
  role: UserRole.student,
  email: 'john@example.com', // Optional
  gender: 'Male', // Optional
  gradeLevel: '10', // For students
  department: null, // For staff
);

// Returns: { 'password': '123456', 'schoolId': 'STU001', 'userId': '...' }
```

#### `resetUserPassword(String userId)`
Generates new 6-digit password for user.

```dart
final newPassword = await authService.resetUserPassword(userId);
// Returns: '654321'
```

#### `disableUser(String userId)`
Archives and disables a user account.

```dart
await authService.disableUser(userId);
```

#### `updateUserRole(String userId, UserRole newRole)`
Updates user's role (Admin only).

```dart
await authService.updateUserRole(userId, UserRole.teacher);
```

### AdminService

#### `fetchUsersByRole(UserRole? role)`
Fetches users filtered by role.

```dart
final students = await adminService.fetchUsersByRole(UserRole.student);
final allUsers = await adminService.fetchUsersByRole(null);
```

#### `getUserStatistics()`
Returns user count statistics.

```dart
final stats = await adminService.getUserStatistics();
// Returns: { 'total_users': 100, 'students': 80, 'teachers': 15, ... }
```

## UI Components

### FormInput Widget

Reusable animated form field with focus animations.

```dart
FormInput(
  controller: _nameController,
  label: 'Full Name *',
  prefixIcon: Icons.person,
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
)
```

### PasswordModal Widget

Displays generated password with copy functionality.

```dart
PasswordModal(
  password: '123456',
  schoolId: 'STU001',
  userName: 'John Doe',
  showRegenerate: false,
  onRegenerate: () { /* ... */ },
)
```

## Security Considerations

1. **Service Role Key**: Never expose in client code
2. **Admin Verification**: Always check user role before allowing operations
3. **RLS Policies**: Database-level security enforced
4. **Password Storage**: Passwords are hashed by Supabase Auth
5. **Email Optional**: Email is not required and not used for login

## Troubleshooting

### "Only admins can create user accounts"
- Verify current user has `role = 'admin'` in database
- Check RLS policies are correctly set

### "School ID already exists"
- School ID must be unique
- Check existing users in database

### "Failed to create auth user"
- Verify Supabase Auth settings (email confirmation disabled)
- Check network connectivity
- Verify user has admin permissions

### Password Reset Not Working
- Admin API requires service role key
- For production, use backend API or Edge Function
- Check user permissions in Supabase Dashboard

## Production Deployment

1. **Create Supabase Edge Function** for user creation
2. **Update AuthService** to call Edge Function instead of direct API
3. **Store service role key** securely (environment variables)
4. **Enable RLS** on all tables
5. **Test admin permissions** thoroughly
6. **Monitor logs** for security issues

## Support

For issues or questions:
1. Check Supabase Dashboard logs
2. Verify RLS policies
3. Test with admin account
4. Review error messages in app

---

**Last Updated**: 2024  
**Version**: 1.0.0

