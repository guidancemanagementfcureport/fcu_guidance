# Anonymous Reports Module - Implementation Guide

## Overview

The Anonymous Reporting Module allows students and individuals to submit confidential reports to the Guidance Office without logging in or providing any personal information. The system generates a unique Tracking ID that can be used to check report status.

## Database Setup

### 1. Run the Schema Migration

Execute the following SQL file in your Supabase SQL Editor:

```bash
fcu_app/supabase/anonymous_reports_schema.sql
```

This will:
- Make `student_id` nullable in the `reports` table
- Add `tracking_id` column with unique constraint
- Create index for tracking ID lookups
- Add function to generate unique tracking IDs (format: `ANON-XXXXXX`)
- Create trigger to auto-generate tracking IDs for anonymous reports
- Update status constraint to include 'pending' status
- Make `actor_id` nullable in `report_activity_logs` for anonymous activity tracking

### 2. RLS Policies (Important)

For anonymous reports to work, you need to configure Row-Level Security (RLS) policies:

**Option 1: Allow Anonymous Inserts (Less Secure)**
```sql
-- Allow anonymous inserts to reports table
CREATE POLICY "Allow anonymous report creation"
ON reports FOR INSERT
TO anon
WITH CHECK (is_anonymous = true AND student_id IS NULL);
```

**Option 2: Use Supabase Edge Function (Recommended for Production)**

Create a Supabase Edge Function that:
- Accepts anonymous report submissions
- Uses service role key to insert reports
- Validates and sanitizes input
- Returns tracking ID

## Features Implemented

### 1. Anonymous Report Form (`anonymous_report_form_page.dart`)

**Features:**
- No login required
- Report Type dropdown (Bullying, Academic Concern, Personal Issue, Behavioral Issue, Safety Concern, Other)
- Report Title field
- Report Details field (multi-line, minimum 20 characters)
- Form validation
- Success dialog with Tracking ID
- Copy Tracking ID to clipboard
- Link to tracker page

**User Flow:**
1. User fills out form
2. Submits report
3. Receives Tracking ID in success dialog
4. Can copy Tracking ID
5. Can navigate to tracker page

### 2. Anonymous Report Tracker (`anonymous_report_tracker_page.dart`)

**Features:**
- Enter Tracking ID to check status
- Real-time status display with color coding
- Report details view
- Status icons and colors:
  - Pending/Submitted: Orange
  - Teacher Reviewed/Forwarded: Blue
  - Counselor Confirmed: Green
  - Settled: Gray
- Copy Tracking ID functionality
- Formatted date display

### 3. Backend Services

**New Methods in `SupabaseService`:**

- `createAnonymousReport()` - Creates anonymous report without authentication
- `getReportByTrackingId()` - Retrieves report by tracking ID
- `getAnonymousReports()` - Gets all anonymous reports (for admin/counselor dashboards)

**Updated Methods:**
- `createReportActivityLog()` - Now supports nullable `actorId` for anonymous reports
- `ReportModel` - Updated to support nullable `studentId` and `trackingId`

## Integration with Existing System

### Counselor/Admin Dashboards

Anonymous reports will automatically appear in:
- Counselor case lists (filtered by `is_anonymous = true`)
- Admin dashboards
- Report management pages

Reports are identified as "Anonymous" and show:
- Tracking ID instead of student name
- Status: "Pending Review" initially
- All other report details

### Status Workflow

Anonymous reports follow the same workflow:
1. **Pending** - Initial status after submission
2. **Teacher Reviewed** - If reviewed by teacher
3. **Forwarded** - If forwarded to counselor
4. **Counselor Confirmed** - If confirmed by counselor
5. **Settled** - If case is resolved

## Security Considerations

### Privacy
- No personal information collected
- No IP address logging (if possible)
- No authentication required
- Tracking ID is the only identifier

### Data Protection
- Reports stored securely in database
- Only authorized counselors/admins can view reports
- Tracking ID is unique and non-guessable
- Reports cannot be linked to individuals

### Best Practices
1. **For Production:** Use Supabase Edge Function for anonymous submissions
2. **RLS Policies:** Configure strict RLS policies
3. **Rate Limiting:** Consider implementing rate limiting to prevent abuse
4. **Monitoring:** Monitor for suspicious patterns
5. **Data Retention:** Establish data retention policies

## Testing

### Test Anonymous Report Submission

1. Navigate to anonymous report form
2. Fill out form:
   - Select report type
   - Enter title
   - Enter details (minimum 20 characters)
3. Submit report
4. Verify Tracking ID is generated (format: `ANON-XXXXXX`)
5. Copy Tracking ID

### Test Report Tracking

1. Navigate to tracker page
2. Enter Tracking ID
3. Verify report details are displayed
4. Check status updates work correctly

### Test Integration

1. Login as counselor/admin
2. Verify anonymous reports appear in dashboard
3. Verify reports show as "Anonymous"
4. Verify status updates work

## Troubleshooting

### Issue: Reports not being created

**Solution:**
- Check RLS policies allow anonymous inserts
- Verify database schema migration ran successfully
- Check Supabase logs for errors

### Issue: Tracking ID not generated

**Solution:**
- Verify trigger `trigger_set_tracking_id` exists
- Check function `generate_tracking_id()` is working
- Verify `is_anonymous = true` is set

### Issue: Cannot find report by Tracking ID

**Solution:**
- Verify Tracking ID format (must start with `ANON-`)
- Check Tracking ID is uppercase
- Verify report exists in database
- Check RLS policies allow reading

## Next Steps

1. **Run Database Migration:** Execute `anonymous_reports_schema.sql`
2. **Configure RLS Policies:** Set up appropriate security policies
3. **Test Functionality:** Test submission and tracking
4. **Add Routes:** Add routes to your app router for form and tracker pages
5. **Update Navigation:** Add links to anonymous report form in public navigation

## Files Modified/Created

### Created Files:
- `fcu_app/supabase/anonymous_reports_schema.sql` - Database migration
- `fcu_app/lib/pages/anonymous_report_tracker_page.dart` - Tracker page
- `fcu_app/supabase/README_ANONYMOUS_REPORTS.md` - This documentation

### Modified Files:
- `fcu_app/lib/pages/anonymous_report_form_page.dart` - Enhanced form
- `fcu_app/lib/models/report_model.dart` - Added trackingId, nullable studentId
- `fcu_app/lib/services/supabase_service.dart` - Added anonymous report methods

## Support

For issues or questions, refer to:
- Supabase documentation: https://supabase.com/docs
- Flutter documentation: https://flutter.dev/docs
- Project documentation in `fcu_app/supabase/README_*.md` files

