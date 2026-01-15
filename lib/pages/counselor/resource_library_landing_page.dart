import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class ResourceLibraryLandingPage extends StatelessWidget {
  const ResourceLibraryLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Resource Library',
                subtitle: 'Trusted tools and materials to support student well-being',
                icon: Icons.library_books_rounded,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Hero Section
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 48 : 24,
                          vertical: isDesktop ? 64 : 48,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.skyBlue.withValues(alpha: 0.15),
                              AppTheme.mediumBlue.withValues(alpha: 0.08),
                              AppTheme.paleBlue.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppTheme.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.skyBlue.withValues(alpha: 0.2),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.library_books_rounded,
                                    size: 64,
                                    color: AppTheme.skyBlue,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                const Text(
                                  'Guidance Resource Library',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                    letterSpacing: -1,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Trusted tools and materials to support student well-being and professional guidance.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppTheme.mediumGray,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 40),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        // Scroll to categories section
                                        final position = Scrollable.of(context).position;
                                        position.animateTo(
                                          position.pixels + 600,
                                          duration: const Duration(milliseconds: 500),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      icon: const Icon(Icons.explore_rounded),
                                      label: const Text('Explore Resources'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.skyBlue,
                                        foregroundColor: AppTheme.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        // Scroll to categories section
                                        final position = Scrollable.of(context).position;
                                        position.animateTo(
                                          position.pixels + 600,
                                          duration: const Duration(milliseconds: 500),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      icon: const Icon(Icons.checklist_rounded),
                                      label: const Text('View Protocols'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.skyBlue,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        side: const BorderSide(
                                          color: AppTheme.skyBlue,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).fadeInSlideUp(),

                      // Resource Categories Section
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 48 : 24,
                          vertical: isDesktop ? 64 : 48,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Resource Categories',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                    letterSpacing: -0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Organized collections of professional guidance materials',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.mediumGray,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 40),
                                // Category Cards Grid
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final crossAxisCount = isDesktop
                                        ? 2
                                        : (isTablet
                                            ? 2
                                            : 1);
                                    return GridView.count(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 24,
                                      mainAxisSpacing: 24,
                                      childAspectRatio: isDesktop ? 1.1 : 1.2,
                                      children: [
                                        _CategoryCard(
                                          icon: Icons.checklist_rounded,
                                          title: 'Intervention Protocols',
                                          description:
                                              'Step-by-step procedures for managing student cases and interventions.',
                                          color: AppTheme.skyBlue,
                                          onTap: () {
                                            ToastUtils.showInfo(
                                              context,
                                              'Intervention Protocols section coming soon',
                                            );
                                          },
                                        ),
                                        _CategoryCard(
                                          icon: Icons.description_rounded,
                                          title: 'Standardized Forms',
                                          description:
                                              'Official guidance forms for referrals, consent, and documentation.',
                                          color: AppTheme.successGreen,
                                          onTap: () {
                                            ToastUtils.showInfo(
                                              context,
                                              'Standardized Forms section coming soon',
                                            );
                                          },
                                        ),
                                        _CategoryCard(
                                          icon: Icons.balance_rounded,
                                          title: 'Legal Guides',
                                          description:
                                              'Policies, legal references, and confidentiality guidelines for guidance practice.',
                                          color: AppTheme.warningOrange,
                                          onTap: () {
                                            ToastUtils.showInfo(
                                              context,
                                              'Legal Guides section coming soon',
                                            );
                                          },
                                        ),
                                        _CategoryCard(
                                          icon: Icons.groups_rounded,
                                          title: 'Group Counseling Curricula',
                                          description:
                                              'Structured counseling programs for group sessions and student development.',
                                          color: AppTheme.infoBlue,
                                          onTap: () {
                                            ToastUtils.showInfo(
                                              context,
                                              'Group Counseling Curricula section coming soon',
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Trust & Professional Value Section
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 48 : 24,
                          vertical: isDesktop ? 48 : 32,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.white,
                              AppTheme.paleBlue.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              children: [
                                const Text(
                                  'Why Trust Our Resource Library',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 40),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final crossAxisCount = isDesktop
                                        ? 4
                                        : (isTablet
                                            ? 2
                                            : 1);
                                    return GridView.count(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 24,
                                      mainAxisSpacing: 24,
                                      children: [
                                        _TrustFeature(
                                          icon: Icons.verified_rounded,
                                          title: 'Professionally Curated',
                                          description:
                                              'Resources selected and reviewed by experienced guidance professionals.',
                                        ),
                                        _TrustFeature(
                                          icon: Icons.school_rounded,
                                          title: 'Designed for Education',
                                          description:
                                              'Tailored specifically for high school and college guidance settings.',
                                        ),
                                        _TrustFeature(
                                          icon: Icons.update_rounded,
                                          title: 'Updated & Standardized',
                                          description:
                                              'Regularly updated materials following current best practices and standards.',
                                        ),
                                        _TrustFeature(
                                          icon: Icons.lock_rounded,
                                          title: 'Secure & Role-Based',
                                          description:
                                              'Protected access ensuring resources are available to authorized personnel only.',
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Footer / Call-to-Action
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 48 : 24,
                          vertical: isDesktop ? 48 : 32,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.skyBlue.withValues(alpha: 0.1),
                              AppTheme.mediumBlue.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.skyBlue,
                                        AppTheme.mediumBlue,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'Empowering guidance professionals with reliable, structured resources.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppTheme.darkGray,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                OutlinedButton(
                                  onPressed: () => context.go('/counselor/dashboard'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.skyBlue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side: const BorderSide(
                                      color: AppTheme.skyBlue,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Text('Back to Dashboard'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGray,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.mediumGray,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'View Resources',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TrustFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.skyBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 32,
            color: AppTheme.skyBlue,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGray,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.mediumGray,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
