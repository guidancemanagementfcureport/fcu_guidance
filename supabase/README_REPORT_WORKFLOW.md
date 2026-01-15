# Guided Report Escalation & Counseling Workflow

## Overview

This document describes the structured, role-based report handling workflow that ensures accountability, confidentiality, and proper escalation from Teacher → Counselor → Dean, while allowing students to request counseling only after formal Dean approval.

**Student Level Identification:** The system automatically identifies student academic level (College, Senior High School, Junior High School) from the `users` table via the `student_id` foreign key. This information is used to guide conditional routing and workflow decisions.

## Workflow Status Lifecycle

```
Submitted → Teacher Reviewed → Counselor Reviewed → Approved by Dean → Counseling Scheduled → Completed
```

### Status Definitions

1. **submitted** - Initial status when student submits a report
2. **teacher_reviewed** - Teacher has reviewed the report and added internal notes
3. **counselor_reviewed** - Counselor has evaluated the report and forwarded to Dean
4. **approved_by_dean** - Dean has approved the report for counseling eligibility
5. **counseling_scheduled** - Dean has scheduled the counseling session
6. **completed** - Counseling session completed and case closed

### Legacy Status Support

The following statuses are still supported for backward compatibility:
- `pending` - Pending review
- `forwarded` - Forwarded to counselor (legacy)
- `counselor_confirmed` - Counselor confirmed (legacy)
- `settled` - Case settled (legacy)

## Role Responsibilities

### Student
- Submit report (anonymous or logged in)
- Receive status updates
- Request counseling only after Dean approval
- View scheduled session details

### Teacher (First Reviewer)
**Responsibilities:**
- Receive newly submitted student reports
- Review report content
- Add internal remarks (not visible to student)
- Decide: Forward to Counselor or Mark as non-actionable

**Actions:**
- "Review & Forward to Counselor" button
- Status changes: `submitted` → `teacher_reviewed`

### Counselor (Case Evaluator)
**Responsibilities:**
- Receive reports forwarded by Teachers
- Evaluate seriousness and guidance relevance
- Add professional assessment notes
- **Conditional Routing Based on Student Level:**
  - **College Students:** Must forward to Dean (cannot finalize independently)
  - **Senior High / Junior High:** Can accept, confirm, or settle reports internally

**Actions:**
- **For College Reports:** "Forward to Dean" button (required)
- **For SHS/JHS Reports:** "Accept Report" or "Confirm & Settle" buttons
- Status changes: `teacher_reviewed` → `counselor_reviewed` (College) or `counselor_confirmed`/`settled` (SHS/JHS)

### Dean (Decision Authority)
**Responsibilities:**
- Receive counselor-reviewed reports (primarily College-level reports)
- Approve or decline counseling request eligibility
- Assign counseling session details
- Select participants for the session

**Actions:**
- "Accept for Counseling" / "Decline" buttons
- Status changes: `counselor_reviewed` → `approved_by_dean`
- Schedule counseling session: `approved_by_dean` → `counseling_scheduled`

**Note:** While Dean primarily handles College reports, they may also review escalated SHS/JHS cases if needed.

## Student Level Identification & Routing

### Automatic Identification
- Student level is automatically captured from the `users` table when a report is submitted
- No manual selection required - prevents errors and ensures consistency
- Student level information is displayed as colored badges:
  - **Blue** for Junior High School
  - **Green** for Senior High School
  - **Purple** for College

### Conditional Workflow Routing

**College Students:**
1. Student submits report
2. Teacher reviews and forwards to Counselor
3. Counselor reviews and **must forward to Dean** (cannot finalize)
4. Dean approves or declines
5. If approved, Dean schedules counseling session

**Senior High / Junior High Students:**
1. Student submits report
2. Teacher reviews and forwards to Counselor
3. Counselor can:
   - Accept and confirm the report
   - Settle the case internally
   - Forward to Dean if escalation is needed (optional)

### Querying Reports by Student Level

To filter reports by student level, JOIN with the `users` table:

```sql
-- Get all College student reports
SELECT r.* 
FROM reports r
JOIN users u ON r.student_id = u.id
WHERE u.student_level = 'college'
AND r.status = 'counselor_reviewed';

-- Get all SHS/JHS student reports
SELECT r.* 
FROM reports r
JOIN users u ON r.student_id = u.id
WHERE u.student_level IN ('senior_high', 'junior_high')
AND r.status = 'teacher_reviewed';
```

## Data Visibility Rules

### Students Can See:
- Report status
- Their own student level information (read-only during submission)
- Counseling schedule (after approval)
- Counselor name
- Session details (date, time, location, type)

### Students Cannot See:
- Internal notes (teacher_note, counselor_note, dean_note)
- Teacher/counselor/dean remarks
- Internal assessment details
- Other students' information

### Teachers, Counselors, and Deans Can See:
- Student level badge and academic details
- Full report information
- Internal notes from previous reviewers
- Student level determines available actions (conditional routing)

## Database Schema Changes

### Reports Table
**New Columns:**
- `dean_id` - UUID reference to the Dean who approved the report
- `teacher_note` - Internal notes from teacher (TEXT)
- `counselor_note` - Internal notes from counselor (TEXT)
- `dean_note` - Internal notes from dean (TEXT)

**Student Level Information:**
- Student level is accessed via `student_id` foreign key to `users` table
- No need to duplicate student level in reports table (normalized design)
- Use JOIN queries to filter by student level when needed

**Updated Status Constraint:**
Now includes: `counselor_reviewed`, `approved_by_dean`, `counseling_scheduled`, `completed`

**New Indexes:**
- `idx_reports_status_student_id` - For efficient filtering by status and student level

### Counseling Requests Table
**New Columns:**
- `dean_id` - UUID reference to the Dean who scheduled the session
- `session_date` - DATE for scheduled session
- `session_time` - TIME for scheduled session
- `session_type` - TEXT: 'Individual' or 'Group'
- `location_mode` - TEXT: 'In-person' or 'Online'
- `participants` - JSONB array of participant user IDs and roles

**Participant Structure:**
```json
[
  {
    "userId": "uuid",
    "role": "counselor|facilitator|adviser|parent"
  }
]
```

## Counseling Session Scheduling

After Dean approval, the Dean can schedule a counseling session with:

1. **Session Date** - Date picker
2. **Session Time** - Time picker
3. **Session Type** - Dropdown: Individual or Group
4. **Location/Mode** - Dropdown: In-person or Online
5. **Participants** - Checkbox selection:
   - Counselor (required)
   - Facilitator (optional)
   - Adviser (optional)
   - Parent/Guardian (optional)

## Migration Instructions

### For New Databases
Run the schema files in order:
1. `reports_base_schema.sql`
2. `counseling_requests_schema.sql`

### For Existing Databases
Run the migration script:
```sql
\i supabase/migrate_report_workflow.sql
```

This will:
- Add new columns to existing tables
- Update status constraints
- Create necessary indexes
- Add documentation comments

## Application Code Updates

### Models Updated
- `ReportModel` - Added deanId, teacherNote, counselorNote, deanNote
- `ReportStatus` enum - Added counselorReviewed, approvedByDean, counselingScheduled, completed
- `CounselingRequestModel` - Added session scheduling fields
- `UserModel` - Added studentLevel, strand, section, yearLevel fields for student level identification

### Services
The `SupabaseService` has been updated to:
- Handle new status transitions
- Support Dean approval workflow
- Support counseling session scheduling
- Filter internal notes from student views
- Automatically identify student level from user profile during report submission
- Support conditional routing based on student level (College → Dean required, SHS/JHS → Counselor can finalize)
- Log "reviewed_and_forwarded_to_dean" action for College reports

## Notifications (MVP)

Trigger notifications on:
- Teacher receives new report
- Counselor receives forwarded report
- Dean receives counselor-reviewed report
- Student receives approval
- Student receives counseling schedule

**Delivery:** In-app notifications only (email optional for future)

## MVP Constraints

✅ No complex approval chains
✅ No multi-session scheduling
✅ No document uploads
✅ No chat yet
✅ Simple linear escalation
✅ Role-based data visibility enforced at UI level

## Future Enhancements (Not MVP)

- Emergency fast-track bypass
- Multi-session counseling plans
- Consent digital signatures
- Audit trail & logs
- Parent portal access
- Email notifications
- SMS notifications

