# Database Schema Setup Guide

## 📋 Quick Setup Instructions

### Step 1: Open Supabase SQL Editor
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** in the left sidebar
3. Click **New Query**

### Step 2: Run the Schema Script
1. Open the file: `supabase/report_workflow_schema.sql`
2. Copy the entire contents
3. Paste into the Supabase SQL Editor
4. Click **Run** (or press `Ctrl+Enter` / `Cmd+Enter`)

### Step 3: Verify Setup
After running the script, you should see:
- ✅ Success messages for all CREATE/ALTER statements
- ✅ No errors

You can also run the verification queries at the bottom of the SQL file to confirm everything was created correctly.

## 📊 What Gets Created

### 1. **Updated Reports Table**
- Adds `type` column (report type)
- Adds `attachment_url` column (file URL)
- Adds `incident_date` column (when incident occurred)

### 2. **New Report Activity Logs Table**
- Tracks all actions on reports
- Stores who did what and when
- Includes optional notes/comments

### 3. **Storage Bucket**
- Creates `reports` bucket for file uploads
- Sets 10MB file size limit
- Allows: PDF, JPEG, PNG, DOC, DOCX

### 4. **Indexes**
- Performance indexes on frequently queried columns
- Speeds up filtering and sorting

### 5. **Security Policies**
- RLS policies for data access
- Storage policies for file uploads/downloads

## 🔍 Verification

After running the script, verify by checking:

```sql
-- Check reports table columns
SELECT column_name, data_type 
FROM information_schema.columns
WHERE table_name = 'reports'
AND column_name IN ('type', 'attachment_url', 'incident_date');

-- Check activity logs table exists
SELECT COUNT(*) FROM report_activity_logs;

-- Check storage bucket
SELECT * FROM storage.buckets WHERE id = 'reports';
```

## ⚠️ Important Notes

1. **No Data Loss**: The script uses `IF NOT EXISTS` and `ADD COLUMN IF NOT EXISTS` to prevent errors if run multiple times.

2. **Existing Data**: Existing reports will have:
   - `type` = 'other' (default)
   - `attachment_url` = NULL
   - `incident_date` = NULL

3. **Storage Bucket**: The bucket is set to **private** by default. Only authenticated users with proper policies can access files.

4. **RLS Policies**: Make sure your existing `reports` table has RLS enabled and appropriate policies.

## 🚀 After Setup

Once the schema is set up:
1. Test creating a report with the new fields
2. Test file upload functionality
3. Verify activity logs are being created
4. Test the complete workflow (Student → Teacher → Counselor)

## 📝 Troubleshooting

### Error: "column already exists"
- This is normal if you run the script multiple times
- The script uses `IF NOT EXISTS` to handle this gracefully

### Error: "bucket already exists"
- The bucket may have been created manually
- The script will skip bucket creation if it exists

### Error: "permission denied"
- Make sure you're running as a database admin
- Check your Supabase project permissions

## ✅ Success Checklist

- [ ] Reports table has new columns (type, attachment_url, incident_date)
- [ ] report_activity_logs table exists
- [ ] Storage bucket 'reports' exists
- [ ] Indexes were created
- [ ] RLS policies are active
- [ ] Storage policies are active

---

**Ready to use!** The schema is now set up and ready for the report workflow module.

