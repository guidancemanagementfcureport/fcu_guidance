import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/student/student_dashboard.dart';
import '../pages/student/submit_report_page.dart';
import '../pages/student/view_report_status_page.dart';
import '../pages/student/request_counseling_page.dart';
import '../pages/student/view_counseling_status_page.dart';
import '../pages/student/guidance_resources_page.dart';
import '../pages/student/help_support_page.dart';
import '../pages/student/student_profile_page.dart';
import '../pages/teacher/teacher_dashboard.dart';
import '../pages/teacher/teacher_reports_page.dart';
import '../pages/teacher/teacher_case_progress_page.dart';
import '../pages/teacher/teacher_profile_page.dart';
import '../pages/counselor/counselor_dashboard.dart';
import '../pages/counselor/counselor_cases_page.dart';
import '../pages/counselor/counselor_student_history_page.dart';
import '../pages/counselor/counselor_case_timeline_page.dart';
import '../pages/counselor/counselor_profile_page.dart';
import '../pages/counselor/resource_library_landing_page.dart';
import '../pages/counselor/counselor_reports_page.dart';
import '../pages/communication/communication_tools_page.dart';
import '../pages/admin/admin_dashboard.dart';
import '../pages/admin/user_management_page.dart';
import '../pages/admin/admin_profile_page.dart';
import '../pages/admin/admin_report_analytics_page.dart';
import '../pages/admin/admin_guidance_report_generator_page.dart';
import '../pages/admin/backup_restore_page.dart';
import '../pages/dean/dean_dashboard.dart';
import '../pages/dean/dean_reports_page.dart';
import '../pages/dean/dean_report_analytics_page.dart';
import '../pages/placeholder_page.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class AppRouter {
  static GoRouter? _router;

  static GoRouter getRouter(AuthProvider authProvider) {
    _router ??= GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final currentUser = authProvider.currentUser;

        // If not authenticated and trying to access protected route
        if (!isAuthenticated &&
            state.matchedLocation != '/login' &&
            state.matchedLocation != '/') {
          return '/login';
        }

        // If authenticated, redirect based on role
        if (isAuthenticated && currentUser != null) {
          final role = currentUser.role;

          // Redirect to appropriate dashboard if accessing login
          if (state.matchedLocation == '/login') {
            switch (role) {
              case UserRole.student:
                return '/student/dashboard';
              case UserRole.teacher:
                return '/teacher/dashboard';
              case UserRole.counselor:
                return '/counselor/dashboard';
              case UserRole.dean:
                return '/dean/dashboard';
              case UserRole.admin:
                return '/admin/dashboard';
            }
          }

          // Role-based route protection
          if (state.matchedLocation == '/admin/dashboard' &&
              role == UserRole.dean) {
            return '/dean/dashboard';
          }

          if (state.matchedLocation.startsWith('/student') &&
              role != UserRole.student) {
            return '/${role.toString()}/dashboard';
          }
          if (state.matchedLocation.startsWith('/teacher') &&
              role != UserRole.teacher) {
            return '/${role.toString()}/dashboard';
          }
          if (state.matchedLocation.startsWith('/counselor') &&
              role != UserRole.counselor) {
            return '/${role.toString()}/dashboard';
          }
          if (state.matchedLocation.startsWith('/admin') &&
              role != UserRole.admin &&
              role != UserRole.dean) {
            return '/${role.toString()}/dashboard';
          }
        }

        return null; // No redirect needed
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

        // Student routes
        GoRoute(
          path: '/student/dashboard',
          builder: (context, state) => const StudentDashboard(),
        ),
        GoRoute(
          path: '/student/submit-report',
          builder: (context, state) => const SubmitReportPage(),
        ),
        GoRoute(
          path: '/student/report-status',
          builder: (context, state) => const ViewReportStatusPage(),
        ),
        GoRoute(
          path: '/student/request-counseling',
          builder: (context, state) => const RequestCounselingPage(),
        ),
        GoRoute(
          path: '/student/counseling-status',
          builder: (context, state) => const ViewCounselingStatusPage(),
        ),
        GoRoute(
          path: '/student/resources',
          builder: (context, state) => const GuidanceResourcesPage(),
        ),
        GoRoute(
          path: '/student/help',
          builder: (context, state) => const HelpSupportPage(),
        ),
        GoRoute(
          path: '/student/profile',
          builder: (context, state) => const StudentProfilePage(),
        ),

        // Teacher routes
        GoRoute(
          path: '/teacher/dashboard',
          builder: (context, state) => const TeacherDashboard(),
        ),
        GoRoute(
          path: '/teacher/reports',
          builder: (context, state) => const TeacherReportsPage(),
        ),
        GoRoute(
          path: '/teacher/communication',
          builder: (context, state) => const CommunicationToolsPage(),
        ),
        GoRoute(
          path: '/teacher/notifications',
          builder:
              (context, state) => const PlaceholderPage(
                title: 'Notifications',
                description: 'View your notifications and updates.',
                icon: Icons.notifications_outlined,
              ),
        ),
        GoRoute(
          path: '/teacher/cases',
          builder: (context, state) => const TeacherCaseProgressPage(),
        ),
        GoRoute(
          path: '/teacher/profile',
          builder: (context, state) => const TeacherProfilePage(),
        ),

        // Counselor routes
        GoRoute(
          path: '/counselor/dashboard',
          builder: (context, state) => const CounselorDashboard(),
        ),
        GoRoute(
          path: '/counselor/cases',
          builder: (context, state) => const CounselorCasesPage(),
        ),
        GoRoute(
          path: '/counselor/notifications',
          builder:
              (context, state) => const PlaceholderPage(
                title: 'Notifications',
                description: 'View your notifications and updates.',
                icon: Icons.notifications_outlined,
              ),
        ),
        GoRoute(
          path: '/counselor/history',
          builder: (context, state) => const CounselorStudentHistoryPage(),
        ),
        GoRoute(
          path: '/counselor/timeline',
          builder: (context, state) => const CounselorCaseTimelinePage(),
        ),
        GoRoute(
          path: '/counselor/communication',
          builder: (context, state) => const CommunicationToolsPage(),
        ),
        GoRoute(
          path: '/counselor/resources',
          builder: (context, state) => const ResourceLibraryLandingPage(),
        ),
        GoRoute(
          path: '/counselor/reports',
          builder: (context, state) => const CounselorReportsPage(),
        ),
        GoRoute(
          path: '/counselor/profile',
          builder: (context, state) => const CounselorProfilePage(),
        ),

        // Dean routes
        GoRoute(
          path: '/dean/dashboard',
          builder: (context, state) => const DeanDashboard(),
        ),
        GoRoute(
          path: '/dean/reports',
          builder: (context, state) => const DeanReportsPage(),
        ),
        GoRoute(
          path: '/dean/communication',
          builder: (context, state) => const CommunicationToolsPage(),
        ),
        GoRoute(
          path: '/dean/analytics',
          builder: (context, state) => const DeanReportAnalyticsPage(),
        ),

        // Admin routes
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboard(),
        ),
        GoRoute(
          path: '/admin/user-management',
          builder: (context, state) => const UserManagementPage(),
        ),
        GoRoute(
          path: '/admin/profile-management',
          builder: (context, state) => const AdminProfilePage(),
        ),
        GoRoute(
          path: '/admin/analytics',
          builder: (context, state) => const AdminReportAnalyticsPage(),
        ),
        GoRoute(
          path: '/admin/generate-report',
          builder: (context, state) {
            final reportData = state.extra as Map<String, dynamic>;
            return AdminGuidanceReportGeneratorPage(reportData: reportData);
          },
        ),
        GoRoute(
          path: '/admin/backup',
          builder: (context, state) => const BackupRestorePage(),
        ),
        GoRoute(
          path: '/admin/settings',
          builder:
              (context, state) => const PlaceholderPage(
                title: 'System Settings',
                description: 'Configure system settings and preferences.',
                icon: Icons.settings_outlined,
              ),
        ),
        GoRoute(
          path: '/admin/profile',
          builder: (context, state) => const AdminProfilePage(),
        ),
      ],
    );
    return _router!;
  }
}
