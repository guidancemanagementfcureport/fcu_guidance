# FCU Guidance Management System - Project Notes

## 🚀 Development Overview
The **FCU Guidance Management System** is a unified digital platform designed to provide students with accessible guidance resources and provide staff with efficient tools for case management, reporting, and real-time support.

### 🛠 Technology Stack

#### **Frontend (Universal Web & Mobile)**
- **Framework:** [Flutter SDK (Dart)](https://flutter.dev/) - For building a highly responsive, high-performance UI across Web, Android, and iOS.
- **State Management:** [Provider](https://pub.dev/packages/provider) - Ensures real-time data flow and consistent app state across modules.
- **Routing & Navigation:** [GoRouter](https://pub.dev/packages/go_router) - Handles deep-linking and complex role-based navigation.
- **UI & Aesthetics:**
  - **Animations:** [Flutter Animate](https://pub.dev/packages/flutter_animate) for premium micro-interactions.
  - **Visual Effects:** Glassmorphism, Custom Gradients, and Shimmer effects for loading states.
  - **Icons:** [Cupertino Icons](https://pub.dev/packages/cupertino_icons) and Material Design icons.
- **Toast Notifications:** [Toastification](https://pub.dev/packages/toastification) for sleek, modern alerts.

#### **Backend & Infrastructure (Powered by Supabase)**
- **Database:** [PostgreSQL](https://www.postgresql.org/) - Structured data storage with advanced relational logic.
- **Auth:** [Supabase Auth](https://supabase.com/auth) - Secure session management for students and staff.
- **Real-Time Engine:** [Supabase Realtime](https://supabase.com/realtime) - Powers the instant messaging and live notification updates using WebSockets.
- **File Storage:** [Supabase Storage](https://supabase.com/storage) - Cloud storage for incident reports, evidence, and attachments.
- **Security:** [Row Level Security (RLS)](https://supabase.com/docs/guides/auth/row-level-security) - Server-side security policies that ensure users only access data they are authorized to see.
- **Server Logic:** PostgreSQL Triggers and Functions for automated status updates and system notifications.

#### **Utilities & Dev Tools**
- **Date/Time:** [Intl](https://pub.dev/packages/intl) for localized formatting.
- **ID Generation:** [UUID](https://pub.dev/packages/uuid) for unique case and session identification.
- **File Picking:** [File Picker](https://pub.dev/packages/file_picker) for cross-platform document uploads.
- **Documentation:** [Mermaid.js](https://mermaid.js.org/) for live-rendered system flowcharts.

---

## 🧭 System Flow & User Journeys

### 1. Student / Guest User Flow
The student journey is designed for ease of access and privacy.

*   **Public Access:**
    *   **Guest Support:** Users can use the **Chat Hub** without signing in to talk to an **AI Guidance Assistant**. These are logged as "Guest Student" for staff.
    *   **Anonymous Reporting:** Students can submit reports without revealing their identity. They receive a unique **Case Code** to track progress later.
*   **Authenticated Access:**
    *   **Official Reports:** Logged-in students can submit detailed reports linked to their profile, upload attachments, and select specific trusted teachers.
    *   **Counseling Requests:** Students can request formal face-to-face or virtual counseling sessions.
    *   **Real-time Support:** Access to the Guidance AI Assistant, which can be taken over by human counselors in real-time.

### 2. Staff User Flow (Teacher / Counselor / Dean)
Staff members have a centralized dashboard to manage student welfare.

*   **Incident Management:**
    *   **Teachers:** Review reports submitted specifically to them, add observations, and forward them to counselors.
    *   **Counselors:** Manage the full lifecycle of a case, schedule counseling, and update statuses.
    *   **Deans:** Oversee all reports, provide final approvals (settled/resolved), and view statistical analytics.
*   **Communication Tools:**
    *   **Unified Messaging:** A dedicated portal to chat with students (anonymous or official).
    *   **Live Takeover:** Counselors can jump into an active AI chat session to provide human support.
*   **Notifications:** Real-time badges and alerts for new reports, new messages, or status updates.

### 3. Administrator Flow
*   **System Health:** Access to **Backup & Restore** tools to manage database snapshots.
*   **User Management:** Controlling roles and permissions (Admin, Dean, Counselor, Teacher, Student).

---

## 🛡️ Security & Privacy
- **Anonymity Bridge:** The system uses a specialized mapping to allow students to remain anonymous while giving counselors the ability to respond to their reports via a secure "Case Code" system.
- **RLS Policies:** Explicit database rules ensure that teachers only see reports assigned to them, and students can only see their own chat history.

---

## 📈 Recent Technical Highlights
- **Chat Hub Integration:** A unified floating menu for all chat types, ensuring help is always one click away from any page.
- **Auto-Refresh Logic:** Intelligent session management that clears chat history on logout and re-initializes for the current user status.
- **Responsive Layout:** Optimized for Mobile, Tablet, and Desktop with glassmorphism aesthetics.
