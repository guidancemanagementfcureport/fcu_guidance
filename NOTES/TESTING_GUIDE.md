# FCU Guidance Management System - Comprehensive Testing Guide

This guide is designed for Quality Assurance (QA) testers to systematically verify all features and role-based workflows in the FCU Guidance Management System.

---

## �️ Global Functionality (Cross-Role)

### 1. Unified Chat Hub
- [ ] **Visibility:** Hub button appears on all student-facing pages.
- [ ] **AI Support:** Start a chat as a guest. Verify AI responds or provides guidance.
- [ ] **Logout Cleansing:** Start a chat as a student, then sign out. Verify chat refreshes to "Guest Student" mode.
- [ ] **Login Sync:** Start a chat as a guest, then sign in. Verify chat history clears/re-initializes for the official student account.

### 2. Authentication
- [ ] **Sign Up:** Create a new student account with a valid Gmail.
- [ ] **Login:** Verify role-based redirection (e.g., Dean goes to Dean Dashboard).
- [ ] **Session Persistence:** Close the browser/tab and reopen. User should remain logged in.

---

## 👤 Role-Based Testing

### **A. Guest Student (Unauthenticated)**
- [ ] **Anonymous Report:** Submit a report. Verify a unique **Case Code** is generated.
- [ ] **Report Tracking:** Use the Case Code to view the status of the submitted report.
- [ ] **AI Support:** Chat with the AI assistant without logging in.

### **B. Authenticated Student**
- [ ] **Official Report:** Submit a report with an attachment (PDF/Image). Select a specific teacher.
- [ ] **Counseling Request:** Request a session. Check for "Pending" status in **Counseling Status**.
- [ ] **Dashboard Stats:** Verify "Open reports" count increases after submission.
- [ ] **Profile Management:** Update profile details and verify they persist.

### **C. Teacher**
- [ ] **Receive Report:** Verify the report submitted by a student specifically to this teacher appears in the list.
- [ ] **Add Observation:** Add a note to a student's case.
- [ ] **Forward Case:** Use the "Forward to Counselor" button. Verify the report moves to the counselor's queue.

### **D. Counselor**
- [ ] **Case Discovery:** Verify forwarded reports from teachers and new anonymous reports appear in the portal.
- [ ] **Communication Portal:** Open the chat for a specific case. Send a message to a student.
- [ ] **AI Takeover:** Locate an active AI chat and intervene manually. Verify the student can see your name instead of the AI.
- [ ] **Scheduling:** Schedule a counseling session and verify the student receives a notification.

### **E. Dean**
- [ ] **Final Approval:** Review a case that has counselor recommendations. Change status to "Settled" (Resolved).
- [ ] **Analytics Dashboard:** Filter reports by type (Bullying, Academic) and date. Check if the graphs update correctly.
- [ ] **Cross-Department View:** Ensure the Dean can see all incidents across the entire school.

### **F. Admin**
- [ ] **Backup & Restore:** Create a database backup. Verify the "Backup Successful" toast appears.
- [ ] **User Management:** Check if user roles can be assigned/modified (Caution: test on dummy accounts).

---

## 🔔 Real-Time & Synchronization Tests

- [ ] **Instant Badges:** Have a Student send a message. Verify the Counselor's sidebar immediately shows a "NEW" badge without a page refresh.
- [ ] **Real-time Chat Bubbles:** Open a chat window on two different browsers (Student & Counselor). Send messages and verify they appear instantly in both.
- [ ] **Status Sync:** Have the Dean settle a case. Verify the Student's portal immediately updates from "Pending" to "Settled" and a badge appears.

---

## 🧪 Edge Cases & Stress Tests

- [ ] **Large Attachments:** Try uploading a file larger than the supported limit.
- [ ] **Network Interruption:** Disconnect the internet while sending a message. Verify the app shows an error or attempts to retry.
- [ ] **Invalid Case Code:** Enter a random string in the Anonymous Tracker. Verify the "Invalid Code" message appears.
- [ ] **Concurrent Login:** Log in to the same account on two different devices. Verify both stay in sync.
