import 'package:flutter/material.dart';
import '../models/menu_item_model.dart';
import '../models/user_model.dart';

class MenuService {
  static Map<UserRole, List<MenuItem>> get roleBasedMenus => {
    UserRole.student: _studentMenus,
    UserRole.teacher: _teacherMenus,
    UserRole.counselor: _counselorMenus,
    UserRole.dean: _deanMenus,
    UserRole.admin: _adminMenus,
  };

  // Student Menu Items
  static const List<MenuItem> _studentMenus = [
    MenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/student/dashboard',
    ),
    MenuItem(
      title: 'Submit Report',
      icon: Icons.report_outlined,
      route: '/student/submit-report',
    ),
    MenuItem(
      title: 'View Report Status',
      icon: Icons.visibility_outlined,
      route: '/student/report-status',
    ),
    MenuItem(
      title: 'Request Counseling',
      icon: Icons.psychology_outlined,
      route: '/student/request-counseling',
    ),
    MenuItem(
      title: 'Counseling Status',
      icon: Icons.track_changes_outlined,
      route: '/student/counseling-status',
    ),
    MenuItem(
      title: 'Guidance Resources',
      icon: Icons.library_books_outlined,
      route: '/student/resources',
    ),
    MenuItem(
      title: 'Help / Support',
      icon: Icons.help_outline,
      route: '/student/help',
    ),
    MenuItem(
      title: 'Profile',
      icon: Icons.person_outline,
      route: '/student/profile',
    ),
  ];

  // Teacher Menu Items
  static const List<MenuItem> _teacherMenus = [
    MenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/teacher/dashboard',
    ),
    MenuItem(
      title: 'Student Reports & Incidents',
      icon: Icons.assignment_outlined,
      route: '/teacher/reports',
    ),
    MenuItem(
      title: 'Messages report',
      icon: Icons.chat_bubble_outline,
      route: '/teacher/communication',
    ),
    MenuItem(
      title: 'Monitor Case Program',
      icon: Icons.monitor_outlined,
      route: '/teacher/cases',
    ),
    MenuItem(
      title: 'Profile',
      icon: Icons.person_outline,
      route: '/teacher/profile',
    ),
  ];

  // Counselor Menu Items
  static const List<MenuItem> _counselorMenus = [
    MenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/counselor/dashboard',
    ),
    MenuItem(
      title: 'Case Records',
      icon: Icons.folder_outlined,
      route: '/counselor/cases',
    ),
    MenuItem(
      title: 'Messages report',
      icon: Icons.chat_bubble_outline,
      route: '/counselor/communication',
    ),
    MenuItem(
      title: 'Student History',
      icon: Icons.history_outlined,
      route: '/counselor/history',
    ),
    MenuItem(
      title: 'Student Case Timeline',
      icon: Icons.timeline_outlined,
      route: '/counselor/timeline',
    ),
    MenuItem(
      title: 'Resource Library',
      icon: Icons.library_books_outlined,
      route: '/counselor/resources',
    ),
    MenuItem(
      title: 'View Statistical Reports',
      icon: Icons.analytics_outlined,
      route: '/counselor/reports',
    ),
    MenuItem(
      title: 'Profile',
      icon: Icons.person_outline,
      route: '/counselor/profile',
    ),
  ];

  // Dean Menu Items (Oversight-focused, read-only access)
  static const List<MenuItem> _deanMenus = [
    MenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/dean/dashboard',
    ),
    MenuItem(
      title: 'Report Review & Approval',
      icon: Icons.assignment_outlined,
      route: '/dean/reports',
    ),
    MenuItem(
      title: 'Messages report',
      icon: Icons.chat_bubble_outline,
      route: '/dean/communication',
    ),
    MenuItem(
      title: 'Report Analytics',
      icon: Icons.analytics_outlined,
      route: '/dean/analytics',
    ),
    MenuItem(
      title: 'Profile',
      icon: Icons.person_outline,
      route: '/admin/profile-management',
    ),
  ];

  // Admin Menu Items
  static const List<MenuItem> _adminMenus = [
    MenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/admin/dashboard',
    ),
    MenuItem(
      title: 'User Management',
      icon: Icons.people_outline,
      route: '/admin/user-management',
    ),
    MenuItem(
      title: 'Profile',
      icon: Icons.person_outline,
      route: '/admin/profile-management',
    ),
    MenuItem(
      title: 'Report Analytics',
      icon: Icons.analytics_outlined,
      route: '/admin/analytics',
    ),
    MenuItem(
      title: 'Backup & Restore',
      icon: Icons.backup_outlined,
      route: '/admin/backup',
    ),
  ];

  static List<MenuItem> getMenusForRole(UserRole role) {
    return roleBasedMenus[role] ?? [];
  }
}
