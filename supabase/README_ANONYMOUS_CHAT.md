# Anonymous Report Chatbox System - Implementation Guide

## Overview

The Anonymous Report Chatbox System allows anonymous users to communicate securely with selected teachers regarding their reports without revealing their identity. The system uses a Case Code (format: AR-XXXXXX) as the only authentication method.

## Database Setup

### 1. Run the Schema Migration

Execute the following SQL file in your Supabase SQL Editor:

```bash
fcu_app/supabase/anonymous_chat_schema.sql
```

This will create:
- `anonymous_reports` table - Stores anonymous reports with case codes
- `anonymous_report_teachers` table - Links reports to selected teachers
- `anonymous_messages` table - Stores all chat messages
- `generate_case_code()` function - Generates unique case codes
- `get_teacher_unread_count()` function - Gets unread message count for teachers
- Required indexes for performance

### 2. RLS Policies

For anonymous access, you may need to configure Row-Level Security (RLS) policies or use Supabase Edge Functions with service role key for production.

## Features Implemented

### 1. Floating Chatbox Widget (`anonymous_chatbox.dart`)

**Location:** `fcu_app/lib/widgets/anonymous_chatbox.dart`

**Features:**
- Floating button on homepage (bottom-right)
- Responsive design (full-screen on mobile, windowed on desktop)
- Case Code entry for resuming conversations
- New report creation flow
- Teacher selection (multi-select)
- Real-time chat interface with message bubbles
- Auto-scroll to latest messages
- Warning banner with Case Code display

**User Flow:**
1. User clicks "Anonymous Chat" button
2. Option to enter Case Code or create new report
3. If new: Select category → Enter description → Select teachers → Submit
4. System generates Case Code and displays it once
5. User can start chatting immediately
6. User can exit and return later using Case Code

### 2. Service Methods (`supabase_service.dart`)

**New Methods Added:**
- `createAnonymousChatReport()` - Creates report with case code
- `getAnonymousReportByCaseCode()` - Retrieves report by case code
- `sendAnonymousMessage()` - Sends a message
- `getAnonymousMessages()` - Gets all messages for a report
- `markAnonymousMessagesAsRead()` - Marks messages as read
- `getTeacherAnonymousReports()` - Gets all reports for a teacher
- `getTeacherUnreadCount()` - Gets unread message count
- `getReportTeachers()` - Gets teachers assigned to a report

### 3. Models (`anonymous_chat_model.dart`)

**New Models:**
- `AnonymousReport` - Report with case code
- `AnonymousMessage` - Chat message
- `AnonymousReportTeacher` - Teacher assignment

### 4. Homepage Integration (`home_page.dart`)

The chatbox is integrated as a Stack overlay, floating on the right side of the homepage. It's always visible and accessible.

## Usage

### For Anonymous Users

1. **Start a New Chat:**
   - Click "Anonymous Chat" button on homepage
   - Click "Create New Report"
   - Fill in category and description
   - Select one or more teachers
   - Submit and save the Case Code

2. **Resume a Chat:**
   - Click "Anonymous Chat" button
   - Enter your Case Code
   - Continue the conversation

3. **Send Messages:**
   - Type message in input field
   - Click send or press Enter
   - Messages appear in chat bubbles

### For Teachers

Teachers will receive anonymous messages in their message inbox (to be integrated with teacher dashboard).

## Privacy & Security

✅ **No personal information stored:**
- No email
- No IP address
- No device fingerprint
- No cookies required

✅ **Case Code is the only identifier:**
- Generated server-side
- Unique per report
- Not recoverable if lost
- Must be saved by user

✅ **Strict anonymity:**
- Messages labeled as "Anonymous Reporter"
- Teacher identity shown to anonymous user
- No reverse lookup possible

## Database Schema

### anonymous_reports
- `id` (UUID, PK)
- `case_code` (TEXT, UNIQUE) - Format: AR-XXXXXX
- `category` (TEXT) - Report category
- `description` (TEXT) - Initial report description
- `status` (TEXT) - pending/ongoing/resolved
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

### anonymous_report_teachers
- `id` (UUID, PK)
- `report_id` (UUID, FK)
- `teacher_id` (UUID, FK)
- `assigned_at` (TIMESTAMPTZ)

### anonymous_messages
- `id` (UUID, PK)
- `report_id` (UUID, FK)
- `sender_type` (TEXT) - 'anonymous' or 'teacher'
- `sender_id` (UUID, nullable) - Only for teachers
- `message` (TEXT)
- `is_read` (BOOLEAN)
- `created_at` (TIMESTAMPTZ)

## Next Steps

1. **Teacher Message Inbox Integration:**
   - Create teacher message dashboard page
   - Display anonymous chats
   - Allow teachers to reply
   - Show unread message indicators

2. **Notifications:**
   - In-app notifications for teachers
   - Real-time message updates (optional)

3. **Admin Oversight:**
   - Admin view of all anonymous chats
   - Status management
   - Report resolution tracking

## Testing

1. Test case code generation
2. Test anonymous report creation
3. Test message sending/receiving
4. Test case code resume functionality
5. Test teacher assignment
6. Test mobile responsiveness

## Notes

- Case Code format: AR-XXXXXX (6 alphanumeric characters)
- Messages are stored chronologically
- Report status updates automatically to 'ongoing' when first message is sent
- Teachers can be selected during report creation
- All messages are tied to the report via report_id

