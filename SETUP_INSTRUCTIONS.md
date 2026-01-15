# FCU Guidance Management System - Setup Instructions

## Prerequisites

1. **Flutter SDK** (3.7.2 or higher)
   - Install from: https://flutter.dev/docs/get-started/install

2. **Supabase Account**
   - Sign up at: https://supabase.com
   - Create a new project

3. **Development Environment**
   - VS Code or Android Studio with Flutter extensions
   - Git (optional)

## Setup Steps

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **API**
3. Copy your **Project URL** and **anon/public key**

4. Open `lib/config/supabase_config.dart` and update:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 3. Set Up Database Schema

1. In Supabase dashboard, go to **SQL Editor**
2. Open the file `supabase_schema.sql` from the project root
3. Copy the entire SQL content
4. Paste it into the SQL Editor and click **Run**

This will create:
- All required tables (users, reports, counseling_requests, etc.)
- Row Level Security (RLS) policies
- Indexes for performance
- Triggers for automatic timestamp updates

### 4. Configure Supabase Auth

Since we're using ID-based login (not email), you need to:

1. Go to **Authentication** → **Settings** in Supabase
2. Enable **Email** provider (we use email format: `school_id@fcu.local`)
3. Disable **Confirm email** requirement (or set to auto-confirm)
4. For admin user creation, ensure **Service Role** key is accessible (stored securely)

### 5. Create First Admin User

**Option A: Via Supabase Dashboard**
1. Go to **Authentication** → **Users**
2. Click **Add User** → **Create new user**
3. Email: `ADMIN_SCHOOL_ID@fcu.local` (e.g., `ADMIN001@fcu.local`)
4. Password: Generate a 6-digit password
5. Auto-confirm: Yes

6. Then in **SQL Editor**, run:
```sql
INSERT INTO users (id, school_id, role, full_name, is_active, is_archived)
VALUES (
  'USER_UUID_FROM_AUTH',  -- Get this from Authentication → Users
  'ADMIN_SCHOOL_ID',       -- e.g., 'ADMIN001'
  'admin',
  'Admin User',
  true,
  false
);
```

**Option B: Via App (After First Admin is Created)**
- Use the Admin Dashboard → User Management
- Create additional users with auto-generated 6-digit passwords

### 6. Run the Application

```bash
# For web
flutter run -d chrome

# For mobile (Android)
flutter run -d android

# For mobile (iOS)
flutter run -d ios
```

## Project Structure

```
lib/
├── config/
│   └── supabase_config.dart      # Supabase credentials
├── models/
│   ├── user_model.dart           # User data model
│   ├── report_model.dart         # Report data model
│   ├── counseling_request_model.dart
│   ├── notification_model.dart
│   └── resource_model.dart
├── services/
│   ├── supabase_service.dart     # Database operations
│   └── auth_service.dart         # Authentication logic
├── providers/
│   └── auth_provider.dart        # State management
├── pages/
│   ├── home_page.dart            # Landing page
│   ├── login_page.dart           # Login screen
│   ├── student/
│   │   └── student_dashboard.dart
│   ├── teacher/
│   │   └── teacher_dashboard.dart
│   ├── counselor/
│   │   └── counselor_dashboard.dart
│   └── admin/
│       ├── admin_dashboard.dart
│       └── user_management_page.dart
├── widgets/
│   └── dashboard_card.dart       # Reusable card component
├── theme/
│   └── app_theme.dart           # Blue gradient theme
├── utils/
│   ├── toast_utils.dart         # Toast notifications
│   ├── password_generator.dart  # 6-digit password generator
│   └── animations.dart           # Animation helpers
├── routes/
│   └── app_router.dart          # GoRouter configuration
└── main.dart                    # App entry point
```

## Key Features

### Authentication
- **ID-based login**: Users login with School ID and 6-digit password
- **Admin-only user creation**: Only System Admin can create new users
- **Auto-generated passwords**: 6-digit random numeric passwords

### User Roles
- **Student**: Submit reports, request counseling, view status
- **Teacher**: Review student reports, communicate, monitor cases
- **Counselor**: Manage cases, view student history, upload resources
- **System Admin**: User management, analytics, backup/restore

### Security
- Row Level Security (RLS) policies enforce data access
- Role-based route guards
- Secure password generation and storage

## Troubleshooting

### Supabase Connection Issues
- Verify your Supabase URL and anon key in `supabase_config.dart`
- Check Supabase project is active
- Ensure RLS policies are enabled

### Authentication Errors
- Verify email provider is enabled in Supabase Auth settings
- Check user exists in both `auth.users` and `public.users` tables
- Ensure user is active and not archived

### Database Errors
- Run the SQL schema again if tables are missing
- Check RLS policies are correctly applied
- Verify user has proper permissions

## Next Steps

1. **Customize UI**: Modify colors, fonts, and layouts in `app_theme.dart`
2. **Add Features**: Implement detailed forms and views for each module
3. **File Uploads**: Configure Supabase Storage buckets for resource library
4. **Notifications**: Set up real-time notifications using Supabase Realtime
5. **Analytics**: Implement detailed reporting and statistics

## Support

For issues or questions:
- Check Supabase documentation: https://supabase.com/docs
- Flutter documentation: https://flutter.dev/docs
- Review code comments in the project

