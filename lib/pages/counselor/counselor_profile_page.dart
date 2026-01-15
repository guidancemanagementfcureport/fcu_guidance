import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/edit_profile_dialog.dart';
import '../../widgets/modern_dashboard_header.dart';

class CounselorProfilePage extends StatelessWidget {
  const CounselorProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return ResponsiveSidebar(
        currentRoute: currentRoute,
        child: const Scaffold(
          body: Center(child: Text('Not authenticated')),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              ModernDashboardHeader(
                title: 'Professional Profile',
                subtitle: 'Manage your guidance credentials and account security settings',
                icon: Icons.badge_rounded,
                actions: [
                  FilledButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => EditProfileDialog(user: user),
                      );
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit Profile'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: isDesktop 
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAvatarCard(context, user),
                              const SizedBox(width: 32),
                              Expanded(child: _buildInfoCard(context, user)),
                            ],
                          )
                        : Column(
                            children: [
                              _buildAvatarCard(context, user),
                              const SizedBox(height: 32),
                              _buildInfoCard(context, user),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCard(BuildContext context, dynamic user) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.skyBlue.withValues(alpha: 0.2), AppTheme.infoBlue.withValues(alpha: 0.1)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: AppTheme.skyBlue.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 2),
              ],
              image: user.avatarUrl != null
                  ? DecorationImage(image: NetworkImage(user.avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: user.avatarUrl == null
                ? const Icon(Icons.person_rounded, color: AppTheme.skyBlue, size: 70)
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            user.fullName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.deepBlue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.displayName.toUpperCase(),
              style: const TextStyle(color: AppTheme.skyBlue, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 40),
          _buildQuickStat('Registered Since', DateFormat('MMM yyyy').format(user.createdAt)),
        ],
      ),
    ).fadeInSlideUp();
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.mediumGray, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppTheme.deepBlue, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.deepBlue),
          ),
          const SizedBox(height: 32),
          _buildInfoItem(Icons.alternate_email_rounded, 'Gmail Address', user.gmail, AppTheme.skyBlue),
          const Divider(height: 48),
          _buildInfoItem(Icons.business_center_outlined, 'Department', user.department ?? 'Guidance Office', AppTheme.warningOrange),
          const Divider(height: 48),
          _buildInfoItem(Icons.verified_user_outlined, 'Account Status', user.isActive ? 'Active & Verified' : 'Standard', AppTheme.successGreen),
          const Divider(height: 48),
          _buildInfoItem(Icons.login_rounded, 'Last Interactive Login', user.lastLogin != null ? DateFormat('MMMM dd, yyyy • HH:mm').format(user.lastLogin!) : 'Recent session', AppTheme.infoBlue),
        ],
      ),
    ).fadeInSlideUp(delay: const Duration(milliseconds: 100));
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.mediumGray, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: AppTheme.deepBlue, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
