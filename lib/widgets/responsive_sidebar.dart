import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/menu_item_model.dart';
import '../models/notification_model.dart';
import '../services/menu_service.dart';
import '../providers/auth_provider.dart';
import '../utils/animations.dart';
import '../utils/toast_utils.dart';
import '../providers/notification_provider.dart';
import 'notification_dialog.dart';
import 'anonymous_chatbox.dart';
import 'ai_support_chatbox.dart';
import 'chat_hub.dart';

class ResponsiveSidebar extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const ResponsiveSidebar({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  State<ResponsiveSidebar> createState() => ResponsiveSidebarState();

  static final List<ResponsiveSidebarState> _stateStack = [];

  static void openDrawer(BuildContext context) {
    final state =
        context.findAncestorStateOfType<ResponsiveSidebarState>() ??
        (_stateStack.isNotEmpty ? _stateStack.last : null);
    state?.open();
  }
}

class ResponsiveSidebarState extends State<ResponsiveSidebar> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isCollapsed = false;

  void open() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  void dispose() {
    ResponsiveSidebar._stateStack.remove(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ResponsiveSidebar._stateStack.add(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).init(authProvider.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (user == null) {
      return widget.child;
    }

    final menus = MenuService.getMenusForRole(user.role);

    // Mobile: Drawer
    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(context, user, menus),
        body: Stack(
          children: [
            widget.child,
            if (user.role == UserRole.student) ...[
              const AnonymousChatbox(),
              const AiSupportChatbox(),
              const ChatHub(),
            ],
          ],
        ),
      );
    }

    // Tablet/Desktop: Fixed Sidebar (Collapsible on tablet)
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isCollapsed ? 80 : 280,
            child: Stack(
              children: [
                _buildSidebar(context, user, menus, isTablet),
                // Collapse/Expand button for tablets
                if (isTablet)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isCollapsed = !_isCollapsed;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.mediumBlue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.skyBlue.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _isCollapsed
                                ? Icons.chevron_right
                                : Icons.chevron_left,
                            color: AppTheme.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Stack(
              children: [
                widget.child,
                if (user.role == UserRole.student) ...[
                  const AnonymousChatbox(),
                  const AiSupportChatbox(),
                  const ChatHub(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    UserModel user,
    List<MenuItem> menus,
  ) {
    return Drawer(
      width: 280,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.deepBlue, AppTheme.mediumBlue, AppTheme.skyBlue],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: _buildSidebarContent(context, user, menus, false),
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    UserModel user,
    List<MenuItem> menus,
    bool isTablet,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.deepBlue, AppTheme.mediumBlue, AppTheme.skyBlue],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border(
          right: BorderSide(
            color: AppTheme.mediumBlue.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepBlue.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: _buildSidebarContent(context, user, menus, isTablet),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context,
    UserModel user,
    List<MenuItem> menus,
    bool isCollapsible,
  ) {
    final bool isCollapsedView = isCollapsible || _isCollapsed;
    return Column(
      children: [
        // Top Section: Branding (Clickable logo returns to dashboard)
        _buildBrandingSection(context, user, isCollapsedView),

        // Middle Section: Navigation Items (Organized into logical groups)
        Expanded(
          child: _buildNavigationSection(context, menus, isCollapsedView),
        ),

        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppTheme.skyBlue.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // Notification Button
        _buildNotificationButton(context, user, isCollapsedView),

        // Bottom Section: User Info
        _buildUserProfileSection(context, user, isCollapsedView),

        const SizedBox(height: 8),

        // Logout Button
        _buildLogoutButton(context, isCollapsedView),
      ],
    );
  }

  Widget _buildUserProfileSection(
    BuildContext context,
    UserModel user,
    bool isCollapsed,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: EdgeInsets.all(isCollapsed ? 12 : 12),
      decoration: BoxDecoration(
        color: AppTheme.mediumBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.skyBlue.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child:
          isCollapsed
              ? _buildAvatarWithBadge(user, 20)
              : Row(
                children: [
                  // Avatar with Role Badge
                  _buildAvatarWithBadge(user, 24),
                  const SizedBox(width: 12),
                  // User Details (Name & Email)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.gmail,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.white.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Chevron icon
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppTheme.white.withValues(alpha: 0.4),
                  ),
                ],
              ),
    );
  }

  Widget _buildAvatarWithBadge(UserModel user, double radius) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppTheme.white,
          backgroundImage:
              user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child:
              user.avatarUrl == null
                  ? Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: radius * 0.8,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mediumBlue,
                    ),
                  )
                  : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppTheme.skyBlue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.role.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationButton(
    BuildContext context,
    UserModel user,
    bool isCollapsed,
  ) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unreadCount = notificationProvider.unreadCount;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showNotificationDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.mediumBlue,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!isCollapsed) ...[
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ).fadeInSlideUp(delay: 600.ms);
      },
    );
  }

  void _showNotificationDialog(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    showDialog(
      context: context,
      builder:
          (context) => NotificationDialog(
            provider: notificationProvider,
            userId: user?.id ?? '',
          ),
    );
  }

  // Top Section: Branding
  Widget _buildBrandingSection(
    BuildContext context,
    UserModel user,
    bool isCollapsed,
  ) {
    // Determine dashboard route based on role
    String dashboardRoute;
    switch (user.role) {
      case UserRole.student:
        dashboardRoute = '/student/dashboard';
        break;
      case UserRole.teacher:
        dashboardRoute = '/teacher/dashboard';
        break;
      case UserRole.counselor:
        dashboardRoute = '/counselor/dashboard';
        break;
      case UserRole.dean:
        dashboardRoute = '/dean/dashboard';
        break;
      case UserRole.admin:
        dashboardRoute = '/admin/dashboard';
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(dashboardRoute),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(0)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isCollapsed ? 16 : 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.mediumBlue.withValues(alpha: 0.4),
                AppTheme.skyBlue.withValues(alpha: 0.3),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.skyBlue.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/img/favicon_fcu/android-chrome-192x192.png',
                width: isCollapsed ? 48 : 56, // Increased size
                height: isCollapsed ? 48 : 56,
                fit: BoxFit.contain,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'FCU Guidance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Middle Section: Navigation Items (Organized into logical groups)
  Widget _buildNavigationSection(
    BuildContext context,
    List<MenuItem> menus,
    bool isCollapsed,
  ) {
    // Organize menus into groups
    final primaryMenus = <MenuItem>[];
    final secondaryMenus = <MenuItem>[];
    final accountMenus = <MenuItem>[];

    for (final menu in menus) {
      if (menu.route.contains('dashboard') ||
          menu.route.contains('report') ||
          menu.route.contains('counseling') ||
          menu.route.contains('case') ||
          menu.route.contains('user-management')) {
        primaryMenus.add(menu);
      } else if (menu.route.contains('resource') ||
          menu.route.contains('help') ||
          menu.route.contains('communication') ||
          menu.route.contains('notification') ||
          menu.route.contains('analytics')) {
        secondaryMenus.add(menu);
      } else if (menu.route.contains('profile')) {
        accountMenus.add(menu);
      } else {
        primaryMenus.add(menu);
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      children: [
        // Primary Navigation
        if (primaryMenus.isNotEmpty) ...[
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Primary',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.white.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ...primaryMenus.asMap().entries.map((entry) {
            final index = entry.key;
            final menu = entry.value;
            final isActive =
                widget.currentRoute == menu.route ||
                widget.currentRoute.startsWith(menu.route);
            return _buildMenuItem(
              context,
              menu,
              isActive,
              isCollapsed,
            ).fadeInSlideUp(delay: (index * 50).ms);
          }),
          if (secondaryMenus.isNotEmpty || accountMenus.isNotEmpty)
            const SizedBox(height: 8),
        ],

        // Secondary / Support
        if (secondaryMenus.isNotEmpty) ...[
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Support',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.white.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ...secondaryMenus.asMap().entries.map((entry) {
            final index = entry.key;
            final menu = entry.value;
            final isActive =
                widget.currentRoute == menu.route ||
                widget.currentRoute.startsWith(menu.route);
            return _buildMenuItem(
              context,
              menu,
              isActive,
              isCollapsed,
            ).fadeInSlideUp(delay: (index * 50).ms);
          }),
          if (accountMenus.isNotEmpty) const SizedBox(height: 8),
        ],

        // Account
        if (accountMenus.isNotEmpty) ...[
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Account',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.white.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ...accountMenus.asMap().entries.map((entry) {
            final index = entry.key;
            final menu = entry.value;
            final isActive =
                widget.currentRoute == menu.route ||
                widget.currentRoute.startsWith(menu.route);
            return _buildMenuItem(
              context,
              menu,
              isActive,
              isCollapsed,
            ).fadeInSlideUp(delay: (index * 50).ms);
          }),
        ],

        // Back to Home shortcut
        const SizedBox(height: 8),
        if (!isCollapsed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Shortcuts',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.white.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
        _buildMenuItem(
          context,
          const MenuItem(
            title: 'Back to Home',
            icon: Icons.home_rounded,
            route: '/',
          ),
          widget.currentRoute == '/',
          isCollapsed,
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    MenuItem menu,
    bool isActive,
    bool isCollapsed,
  ) {
    final menuItem = Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final count = _getNotificationCount(
          menu,
          notificationProvider.notifications,
        );
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color:
                isActive
                    ? AppTheme.skyBlue.withValues(alpha: 0.3)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border:
                isActive
                    ? Border.all(
                      color: AppTheme.skyBlue.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                    : null,
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: AppTheme.skyBlue.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (MediaQuery.of(context).size.width < 768) {
                  Navigator.of(context).pop(); // Close drawer on mobile
                }
                context.go(menu.route);
              },
              borderRadius: BorderRadius.circular(12),
              child: Focus(
                autofocus: false,
                onFocusChange: (hasFocus) {
                  // Enhanced focus handling for accessibility
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Active indicator bar
                      if (isActive)
                        Container(
                          width: 3,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.white.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  isActive
                                      ? AppTheme.white.withValues(alpha: 0.2)
                                      : AppTheme.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              menu.icon,
                              color:
                                  isActive
                                      ? AppTheme.white
                                      : AppTheme.white.withValues(alpha: 0.7),
                              size: 20,
                            ),
                          ),
                          if (count > 0)
                            Positioned(
                              top: -5,
                              right: -5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorRed,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.mediumBlue,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    count > 99 ? '99+' : count.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!isCollapsed) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            menu.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w500,
                              color:
                                  isActive
                                      ? AppTheme.white
                                      : AppTheme.white.withValues(alpha: 0.8),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Add tooltip when collapsed for better UX
    if (isCollapsed) {
      return Tooltip(
        message: menu.title,
        preferBelow: false,
        verticalOffset: 0,
        decoration: BoxDecoration(
          color: AppTheme.darkGray,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: AppTheme.white, fontSize: 12),
        child: menuItem,
      );
    }

    return menuItem;
  }

  int _getNotificationCount(
    MenuItem menu,
    List<NotificationModel> notifications,
  ) {
    final unreadNotifications = notifications.where((n) => !n.isRead);

    if (menu.title == 'Student Reports & Incidents') {
      return unreadNotifications
          .where((n) => n.type == NotificationType.newReport)
          .map((n) => n.data['report_id'])
          .toSet()
          .length;
    }

    if (menu.title == 'Messages report') {
      // For messages, we also group by report_id to show number of cases with new messages
      return unreadNotifications
          .where((n) => n.type == NotificationType.newMessage)
          .map((n) => n.data['report_id'] ?? n.data['session_id'])
          .where((id) => id != null)
          .toSet()
          .length;
    }

    if (menu.title == 'Case Records') {
      return unreadNotifications
          .where((n) => n.type == NotificationType.newReport)
          .map((n) => n.data['report_id'])
          .toSet()
          .length;
    }

    if (menu.title == 'Report Review & Approval') {
      return unreadNotifications
          .where((n) => n.type == NotificationType.newReport)
          .map((n) => n.data['report_id'])
          .toSet()
          .length;
    }

    if (menu.title == 'View Report Status') {
      return unreadNotifications
          .where((n) => n.type == NotificationType.reportUpdate)
          .map((n) => n.data['report_id'])
          .toSet()
          .length;
    }

    return 0;
  }

  Widget _buildLogoutButton(BuildContext context, bool isCollapsed) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.errorRed, // Make it solid/prominent for visibility
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorRed.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogoutDialog(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment:
                  isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
              children: [
                const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Confirm Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final userName = authProvider.currentUser?.fullName ?? 'User';

                  // Show toast before sign out to ensure it's visible
                  if (context.mounted) {
                    ToastUtils.showSuccess(
                      context,
                      'Goodbye, $userName!',
                      title: 'Signed Out',
                    );
                  }

                  await authProvider.signOut();
                  // Navigation is handled automatically by AuthProvider listener in AppRouter
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: AppTheme.white,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );
  }
}
