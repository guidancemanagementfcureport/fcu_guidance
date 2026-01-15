# FCU Guidance Management System - Module Documentation

This document provides a detailed breakdown of the functional modules within the application and how various users interact with them.

---

## 🔐 1. Authentication & Role Management
This module handles secure access and ensures users see only the tools relevant to their role.
*   **Sign In / Sign Up:** Students can create accounts using their Gmail.
*   **Role-Based Dashboards:** Upon login, the system detects if the user is a Student, Teacher, Counselor, Dean, or Admin and opens the appropriate workspace.
*   **Automatic Session Handling:** The app intelligently refreshes chat and data when switching between guest and authenticated accounts.

---

## 📢 2. Incident Reporting Module
The core module for documenting student concerns.
*   **Official Reporting:** Logged-in students can submit reports for Bullying, Academic Concerns, etc. They can select a trusted teacher and upload files.
*   **Anonymous Reporting:** Allows students to report issues without logging in. They receive a **Private Case Code** which allows them to track the report and chat with staff anonymously.
*   **Status Tracking:** Students can see if their report is "Pending," "Under Review," or "Settled."

---

## 🤝 3. Counseling Module
Facilitates formal support between students and counselors.
*   **Request Form:** Students submit their preferred dates and the nature of their counseling needs.
*   **Scheduling:** Counselors review requests and set official meeting dates.
*   **Calendar/Status View:** Students track their upcoming appointments and the history of their sessions.

---

## 💬 4. Communication Hub (The Chat Hub)
A unified interface for real-time support, accessible from any page.
*   **AI Support Hub:** Instant help for students with guidance-related questions.
*   **Live Takeover:** If the AI cannot resolve the issue, a human counselor can join the chat instantly.
*   **Guest Mode:** Allows non-logged-in users to get help (displayed as "Guest Student" to staff).
*   **Anonymous Chat:** A secure channel for staff to ask follow-up questions to anonymous reporters.

---

## 📋 5. Staff Case Management Module
The workspace for Teachers, Counselors, and Deans.
*   **Teacher Portal:** Teachers can view reports assigned to them and "Forward" them to the Guidance Office.
*   **Counselor Workspace:** A comprehensive list of all active cases, counseling schedules, and unified messaging.
*   **Dean Dashboard:** High-level overview of system activity. The Dean is responsible for the final "Settling" or resolution of cases.

---

## 📊 6. Analytics & Statistics
Provides data-driven insights for school leadership.
*   **Incident Trends:** Visual graphs of report types (e.g., how many academic concerns this month).
*   **Resolution Rates:** Metrics on how quickly cases are being closed.
*   **Student Sentiment:** Analyzing common support categories requested through the AI.

---

## 🔔 7. Real-Time Notification Module
Ensures no urgent student need goes unnoticed.
*   **Universal Badges:** "NEW" badges appear in the sidebar for new reports or messages.
*   **Staff Alerts:** Teachers and Counselors get instant notifications when a student sends a message or submits a report.
*   **Student Alerts:** Students are notified when a counselor updates their case status or schedules a meeting.

---

## 🛠 8. Administrative & System Module
Tools for system maintenance.
*   **Backup & Restore:** Admins can create database snapshots and restore data if needed.
*   **User Provisioning:** Managing and assigning roles to staff members.
