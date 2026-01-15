# Report Workflow Schema Files

This directory contains separate schema files for each role's perspective of the report workflow system.

## 📁 Schema Files

### 1. **student_reports_schema.sql**
- **Purpose**: Student Submit Report functionality
- **Contains**:
  - RLS policies for students to submit and view their own reports
  - Student reports view
  - Helper function for report status timeline
  - Storage policies for student file uploads

### 2. **teacher_reports_schema.sql**
- **Purpose**: Teacher Student Reports & Incidents functionality
- **Contains**:
  - RLS policies for teachers to view and update all reports
  - Teacher reports view with student/teacher/counselor information
  - Helper functions for marking as reviewed and forwarding to counselor
  - Storage policies for teacher file access

### 3. **counselor_reports_schema.sql**
- **Purpose**: Counselor Case Records functionality
- **Contains**:
  - RLS policies for counselors to view and update forwarded reports
  - Counselor case records view with full case information
  - Helper functions for accepting and confirming/settling reports
  - Storage policies for counselor file access

## 🚀 Setup Instructions

### Step 1: Create Base Tables (REQUIRED FIRST)
**You must run this first before any role-specific schemas:**

1. Run `reports_base_schema.sql` - Creates the `reports` and `report_activity_logs` tables

### Step 2: Run Role-Specific Schemas
After base tables are created, run the role-specific schemas:

1. Run `student_reports_schema.sql`
2. Run `teacher_reports_schema.sql`
3. Run `counselor_reports_schema.sql`

### Option 2: Run Individual Schemas
If you only need to set up specific role functionality:

- For student functionality only: Run `student_reports_schema.sql`
- For teacher functionality only: Run `teacher_reports_schema.sql`
- For counselor functionality only: Run `counselor_reports_schema.sql`

## 📋 Prerequisites

Before running role-specific schema files, ensure:

1. ✅ **Run `reports_base_schema.sql` first** - This creates:
   - `reports` table with all required columns
   - `report_activity_logs` table
   - Storage bucket `reports`
   - Indexes and constraints

2. ✅ `users` table exists with `role` column (from user_management_schema.sql)

## 🔍 Verification

Each schema file includes verification queries at the end. After running a schema file, check:

- Policies were created successfully
- Views were created successfully
- Functions were created successfully

## 🔐 Security Notes

- **RLS is NOT enabled** - Access control is handled in the application layer
- Storage policies allow authenticated users to upload and view files
- Functions accept user IDs as parameters (no auth.uid() dependency)
- Application code should enforce role-based access control

## 📝 Notes

- These schemas are **additive** - they add views and functions without modifying existing tables
- If you need to modify base tables, use `report_workflow_schema_complete.sql`
- Views provide convenient access patterns for querying data
- Helper functions simplify common operations (accept user IDs as parameters)
- **No RLS policies** - Access control must be implemented in your Flutter application

## 🐛 Troubleshooting

If you encounter errors:

1. **View already exists**: Views are recreated with `CREATE OR REPLACE` - this is safe
2. **Function already exists**: Functions are recreated with `CREATE OR REPLACE` - this is safe
3. **Permission denied**: Ensure you're running as a database superuser or have proper permissions
4. **Storage policy conflicts**: If you have existing storage policies, they may need to be dropped first

## ✅ Testing Checklist

After running all schemas:

- [ ] Views are created successfully
- [ ] Helper functions are created successfully
- [ ] Storage policies allow file uploads
- [ ] Storage policies allow file access
- [ ] Application enforces access control (students see only their reports, etc.)
- [ ] File uploads work correctly
- [ ] Activity logs are created correctly

---

## ⚠️ Important: No RLS

**These schemas do NOT use Row Level Security (RLS).**

Access control must be implemented in your Flutter application:
- Filter reports by `student_id` for students
- Filter reports by `teacher_id` or show all for teachers
- Filter reports by `counselor_id` or status='forwarded' for counselors
- Validate user roles before allowing operations

---

**Last Updated**: 2024
**Status**: ✅ Ready for Production (with application-level access control)

