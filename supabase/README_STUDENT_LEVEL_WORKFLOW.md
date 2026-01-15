# Student Level Identification & Conditional Routing

## Overview

The FCU Guidance Management System automatically identifies student academic level (College, Senior High School, Junior High School) from the user profile and uses this information to guide the report review and escalation workflow.

## Student Level Storage

Student level information is stored in the `users` table:

- `student_level` - Enum: `junior_high`, `senior_high`, `college`
- `grade_level` - Grade level (7-10 for JHS, 11-12 for SHS)
- `strand` - Strand for SHS students (STEM, HUMSS, ABM, GAS)
- `section` - Section for JHS students (optional)
- `course` - Course/Program for College students
- `year_level` - Year level for College students (1st-4th Year)

## Automatic Identification

When a student submits a report:

1. System automatically retrieves student level from `users` table via `student_id` foreign key
2. Student level is displayed as a colored badge (read-only) during submission
3. No manual selection required - prevents errors and ensures data consistency

## Conditional Workflow Routing

### College Students (Required Dean Approval)

**Workflow:**
```
Submitted → Teacher Reviewed → Counselor Reviewed → Approved by Dean → Counseling Scheduled → Completed
```

**Key Rules:**
- Counselor **must** forward College reports to Dean
- Counselor cannot finalize or settle College reports independently
- Dean has final authority for College-level counseling requests

**UI Behavior:**
- Counselor sees warning badge: "College reports must be forwarded to Dean for approval"
- Only "Forward to Dean" button is shown (required action)
- Cannot access "Accept Report" or "Confirm & Settle" buttons

### Senior High / Junior High Students (Counselor Can Finalize)

**Workflow:**
```
Submitted → Teacher Reviewed → Counselor Confirmed/Settled → Completed
```

**Alternative Workflow (if escalation needed):**
```
Submitted → Teacher Reviewed → Counselor Reviewed → Approved by Dean → Counseling Scheduled → Completed
```

**Key Rules:**
- Counselor can accept, confirm, or settle SHS/JHS reports internally
- Counselor can optionally forward to Dean if escalation is needed
- No mandatory Dean approval required

**UI Behavior:**
- Counselor sees student level badge (Green for SHS, Blue for JHS)
- Both "Accept Report" and "Confirm & Settle" buttons are available
- Optional "Forward to Dean" action available if needed

## Database Queries

### Get Reports by Student Level

```sql
-- College reports awaiting Dean approval
SELECT r.*, u.student_level, u.course, u.year_level
FROM reports r
JOIN users u ON r.student_id = u.id
WHERE u.student_level = 'college'
AND r.status = 'counselor_reviewed';

-- SHS/JHS reports for Counselor review
SELECT r.*, u.student_level, u.grade_level, u.strand, u.section
FROM reports r
JOIN users u ON r.student_id = u.id
WHERE u.student_level IN ('senior_high', 'junior_high')
AND r.status = 'teacher_reviewed';
```

### Get Student Level Distribution

```sql
-- Count reports by student level
SELECT 
  u.student_level,
  COUNT(*) as report_count,
  COUNT(CASE WHEN r.status = 'counselor_reviewed' THEN 1 END) as awaiting_dean
FROM reports r
JOIN users u ON r.student_id = u.id
WHERE r.status IN ('submitted', 'teacher_reviewed', 'counselor_reviewed')
GROUP BY u.student_level;
```

## Activity Log Actions

The system logs different actions based on student level:

- **College Reports:** `reviewed_and_forwarded_to_dean` (when counselor forwards)
- **SHS/JHS Reports:** `confirmed` or `settled` (when counselor finalizes)

## UI Display

### Student Level Badges

- **Junior High School:** Blue badge (#3B82F6)
- **Senior High School:** Green badge (#10B981)
- **College:** Purple badge (#8B5CF6)

### Academic Details Display

**Junior High:**
- Grade Level (Grade 7-10)
- Section (optional)

**Senior High:**
- Grade Level (Grade 11-12)
- Strand (STEM, HUMSS, ABM, GAS)

**College:**
- Course/Program
- Year Level (1st-4th Year)

## Migration Notes

If you're updating an existing database:

1. Ensure `users` table has `student_level`, `strand`, `section`, `year_level` columns
2. Run `migrate_student_level_columns.sql` if needed
3. Update existing student records with their academic level
4. Reports will automatically use student level from user profile

## Benefits

1. **Data Consistency:** Student level stored once in users table, referenced via foreign key
2. **Error Prevention:** No manual selection during report submission
3. **Clear Routing:** Conditional logic ensures proper escalation
4. **Scalability:** Easy to add new student levels or modify routing rules
5. **Audit Trail:** Activity logs capture routing decisions based on student level

