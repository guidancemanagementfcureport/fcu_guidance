# Supabase Database Schema - Table List

This document provides a comprehensive list of the tables and views currently active in the FCU Guidance Management System database.

## �️ Core Business Tables

### 1. `users`
- **Purpose:** Stores extended user profile information for all roles (Student, Teacher, Counselor, Dean, Admin).
- **Key Columns:** `id` (UUID), `gmail`, `full_name`, `role`, `student_level`, `department`.

### 2. `reports`
- **Purpose:** Central repository for all official (non-anonymous) incident reports.
- **Key Columns:** `id`, `student_id`, `teacher_id`, `title`, `type`, `status`, `attachment_url`.

### 3. `anonymous_reports`
- **Purpose:** Stores reports submitted by unauthenticated users.
- **Key Columns:** `id`, `case_code`, `title`, `type`, `details`, `status`.

### 4. `anonymous_report_teachers`
- **Purpose:** Links anonymous reports to trusted teachers who can view them.

### 5. `counseling_requests`
- **Purpose:** Manages student requests for formal counseling sessions.
- **Key Columns:** `id`, `student_id`, `preferred_date`, `status`, `counselor_id`.

---

## 💬 Communication & Chat Tables

### 6. `support_sessions`
- **Purpose:** Manages AI Assistant and Human Support chat sessions.
- **Key Columns:** `id`, `student_id` (NULL for guests), `student_name`, `status`.

### 7. `support_messages`
- **Purpose:** Stores individual messages within a support session.
- **Key Columns:** `id`, `session_id`, `sender_role`, `content`.

### 8. `case_messages`
- **Purpose:** Real-time messaging for official reports between staff and students.

### 9. `anonymous_messages`
- **Purpose:** Secure communication channel for anonymous reports using the `case_code`.

---

## 🔔 System & Management Tables

### 10. `notifications`
- **Purpose:** Powers the real-time alert system (NEW badges, status updates).
- **Key Columns:** `id`, `user_id`, `type`, `data`, `is_read`.

### 11. `backup_jobs` & `backup_records`
- **Purpose:** Tracks the configuration and history of system database backups.

### 12. `activity_logs`
- **Purpose:** General audit trail for system actions.

### 13. `report_activity_logs`
- **Purpose:** Specific history of status changes and edits for incident reports.

### 14. `counseling_activity_logs`
- **Purpose:** Audit trail for counseling appointment scheduling and updates.

---

## 👁️ Database Views
These are virtual tables used for role-based data filtering.

- **`student_reports_view`**: Filtered data for student self-service.
- **`teacher_reports_view`**: Reports specifically assigned to or forwarded to a teacher.
- **`counselor_case_records_view`**: A unified management view for the guidance office.
