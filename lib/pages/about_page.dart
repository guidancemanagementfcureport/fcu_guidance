import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sticky_navigation_bar.dart';
import '../utils/animations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final isTablet = MediaQuery.of(context).size.width > 600 && !isWeb;

    return Scaffold(
      body: StickyNavigationBar(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Section 1: Hero / Intro
              _buildHeroSection(context, isWeb, isTablet),

              // Section 2: What the System Does
              _buildWhatSystemDoesSection(context, isWeb, isTablet),

              // Section 3: Mission Statement
              _buildMissionSection(context, isWeb, isTablet),

              // Section 4: Who It's For
              _buildWhoItsForSection(context, isWeb, isTablet),

              // Section 5: Core Values / Benefits
              _buildCoreValuesSection(context, isWeb, isTablet),
            ],
          ),
        ),
      ),
    );
  }

  // Section 1: Hero / Intro
  Widget _buildHeroSection(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 80 : isTablet ? 48 : 24,
        vertical: isWeb ? 80 : isTablet ? 60 : 48,
      ),
      child: isWeb
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppTheme.skyBlue, AppTheme.mediumBlue],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'About FCU Guidance Management System',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                    height: 1.2,
                                    letterSpacing: -0.5,
                                  ),
                                ).fadeInSlideUp(),
                                const SizedBox(height: 16),
                                const Text(
                                  'A centralized digital platform designed to support the Guidance Office in managing student concerns, counseling requests, and guidance-related services for Junior High, Senior High, and College levels.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppTheme.darkGray,
                                    height: 1.7,
                                  ),
                                ).fadeInSlideUp(delay: 100.ms),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.paleBlue.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.skyBlue.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'The system serves as a bridge between students, teachers, counselors, deans, and administrators, ensuring that student concerns are addressed in a timely and organized manner. It promotes transparency, confidentiality, and effective communication while streamlining the entire guidance process—from report submission to case resolution, including Dean approval for college-level cases.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.darkGray,
                            height: 1.7,
                          ),
                        ),
                      ).fadeInSlideUp(delay: 200.ms),
                    ],
                  ),
                ),
                const SizedBox(width: 60),
                // Image on the right side
                Container(
                  width: 500,
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/img/about.png',
                      width: 500,
                      height: 400,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 500,
                          height: 400,
                          color: AppTheme.lightGray,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: AppTheme.mediumGray,
                              size: 64,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ).fadeInSlideUp(delay: 300.ms),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppTheme.skyBlue, AppTheme.mediumBlue],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About FCU Guidance Management System',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ).fadeInSlideUp(),
                          const SizedBox(height: 16),
                          const Text(
                            'A centralized digital platform designed to support the Guidance Office in managing student concerns, counseling requests, and guidance-related services efficiently and securely.',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.darkGray,
                              height: 1.7,
                            ),
                          ).fadeInSlideUp(delay: 100.ms),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.paleBlue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.skyBlue.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'The system serves as a bridge between students, teachers, counselors, and administrators, ensuring that student concerns are addressed in a timely and organized manner. It promotes transparency, confidentiality, and effective communication while streamlining the entire guidance process—from report submission to case resolution.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.darkGray,
                      height: 1.7,
                    ),
                  ),
                ).fadeInSlideUp(delay: 200.ms),
                const SizedBox(height: 32),
                // Image below text on mobile
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/img/about.png',
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 300,
                            color: AppTheme.lightGray,
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: AppTheme.mediumGray,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ).fadeInSlideUp(delay: 300.ms),
              ],
            ),
    );
  }

  // Section 2: What the System Does
  Widget _buildWhatSystemDoesSection(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    final features = [
      {
        'icon': Icons.description_rounded,
        'title': 'Secure Submission',
        'description':
            'Secure submission of student reports and concerns',
      },
      {
        'icon': Icons.visibility_rounded,
        'title': 'Structured Review',
        'description':
            'Structured review and monitoring of cases by teachers and counselors',
      },
      {
        'icon': Icons.assignment_rounded,
        'title': 'Streamlined Process',
        'description':
            'Streamlined counseling request and approval process',
      },
      {
        'icon': Icons.track_changes_rounded,
        'title': 'Real-Time Tracking',
        'description':
            'Real-time tracking of report and counseling statuses',
      },
      {
        'icon': Icons.security_rounded,
        'title': 'Role-Based Access',
        'description':
            'Role-based access to ensure data confidentiality and integrity',
      },
    ];

    return Container(
      color: AppTheme.lightGray,
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 80 : isTablet ? 48 : 24,
        vertical: isWeb ? 80 : isTablet ? 60 : 48,
      ),
      child: Column(
        children: [
          Text(
            'WHAT THE SYSTEM OFFERS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyBlue,
              letterSpacing: 2,
            ),
          ).fadeIn(),
          const SizedBox(height: 20),
          Text(
            'Comprehensive Guidance Management',
            style: TextStyle(
              fontSize: isWeb ? 36 : isTablet ? 32 : 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 60),
          isWeb
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: features.length,
                  itemBuilder: (context, index) {
                    return _buildFeatureCard(
                      features[index]['icon'] as IconData,
                      features[index]['title'] as String,
                      features[index]['description'] as String,
                      index,
                    );
                  },
                )
              : Column(
                  children: features.asMap().entries.map((entry) {
                    final index = entry.key;
                    final feature = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildFeatureCard(
                        feature['icon'] as IconData,
                        feature['title'] as String,
                        feature['description'] as String,
                        index,
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String description,
    int index,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.skyBlue.withValues(alpha: 0.1),
                  AppTheme.mediumBlue.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 28,
              color: AppTheme.skyBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.darkGray,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).fadeInSlideUp(delay: Duration(milliseconds: 100 * index));
  }

  // Section 3: Mission Statement
  Widget _buildMissionSection(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.paleBlue,
            AppTheme.lightBlue.withValues(alpha: 0.1),
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 80 : isTablet ? 48 : 24,
        vertical: isWeb ? 80 : isTablet ? 60 : 48,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.skyBlue, AppTheme.mediumBlue],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.skyBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Colors.white,
              size: 32,
            ),
          ).fadeIn(),
              const SizedBox(height: 32),
          Text(
            'OUR MISSION',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyBlue,
              letterSpacing: 2,
            ),
          ).fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 20),
          SizedBox(
            width: isWeb ? 800 : double.infinity,
            child: const Text(
              'Our mission is to provide a secure, efficient, and user-friendly platform that prioritizes student well-being and supports academic and personal development. The FCU Guidance Management System empowers deans, counselors, teachers, and administrators to manage student concerns responsibly while maintaining professionalism, privacy, and care.',
              style: TextStyle(
                fontSize: 20,
                color: AppTheme.deepBlue,
                height: 1.7,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ).fadeInSlideUp(delay: 200.ms),
        ],
      ),
    );
  }

  // Section 4: Who It's For
  Widget _buildWhoItsForSection(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    final roles = [
      {
        'icon': Icons.school_rounded,
        'title': 'Students',
        'description':
            'A safe and accessible space to submit reports, request counseling, and track the status of their concerns.',
        'color': AppTheme.skyBlue,
      },
      {
        'icon': Icons.person_rounded,
        'title': 'Teachers',
        'description':
            'Tools to review, monitor, and forward student reports responsibly to the Guidance Office.',
        'color': AppTheme.mediumBlue,
      },
      {
        'icon': Icons.support_agent_rounded,
        'title': 'Counselors',
        'description':
            'A centralized system to assess cases, manage counseling requests, maintain student records, and resolve reports efficiently.',
        'color': AppTheme.skyBlue,
      },
      {
        'icon': Icons.assignment_turned_in_rounded,
        'title': 'College Deans',
        'description':
            'Provides final review and approval for college-level incident reports, ensuring academic oversight and resolution.',
        'color': AppTheme.mediumBlue,
      },
      {
        'icon': Icons.admin_panel_settings_rounded,
        'title': 'Administrators',
        'description':
            'Oversight and system management to ensure proper access control, data accuracy, and operational efficiency.',
        'color': AppTheme.skyBlue,
      },
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 80 : isTablet ? 48 : 24,
        vertical: isWeb ? 80 : isTablet ? 60 : 48,
      ),
      child: Column(
        children: [
          Text(
            'WHO THE SYSTEM IS FOR',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyBlue,
              letterSpacing: 2,
            ),
          ).fadeIn(),
          const SizedBox(height: 20),
          Text(
            'Designed for Every Stakeholder',
                style: TextStyle(
              fontSize: isWeb ? 36 : isTablet ? 32 : 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepBlue,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 60),
          isWeb
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 32,
                    mainAxisSpacing: 32,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    return _buildRoleCard(
                      roles[index]['icon'] as IconData,
                      roles[index]['title'] as String,
                      roles[index]['description'] as String,
                      roles[index]['color'] as Color,
                      index,
                    );
                  },
                )
              : Column(
                  children: roles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final role = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildRoleCard(
                        role['icon'] as IconData,
                        role['title'] as String,
                        role['description'] as String,
                        role['color'] as Color,
                        index,
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    IconData icon,
    String title,
    String description,
    Color color,
    int index,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
                style: TextStyle(
              fontSize: 15,
                  color: AppTheme.darkGray,
                  height: 1.6,
                ),
              ),
            ],
          ),
    ).fadeInSlideUp(delay: Duration(milliseconds: 100 * index));
  }

  // Section 5: Core Values / Benefits
  Widget _buildCoreValuesSection(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    final values = [
      {
        'icon': Icons.lock_rounded,
        'title': 'Confidentiality & Security',
        'description':
            'All student information and reports are handled with strict confidentiality protocols and enterprise-grade security.',
      },
      {
        'icon': Icons.speed_rounded,
        'title': 'Faster Response',
        'description':
            'Streamlined processes ensure student concerns are addressed in a timely and organized manner.',
      },
      {
        'icon': Icons.dashboard_rounded,
        'title': 'Centralized Management',
        'description':
            'A unified platform that brings together all guidance-related activities in one secure location.',
      },
      {
        'icon': Icons.thumb_up_rounded,
        'title': 'User-Friendly Experience',
        'description':
            'Intuitive interface designed for ease of use, ensuring all stakeholders can navigate the system effectively.',
      },
    ];

    return Container(
      color: AppTheme.deepBlue,
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 80 : isTablet ? 48 : 24,
        vertical: isWeb ? 80 : isTablet ? 60 : 48,
      ),
      child: Column(
        children: [
          const Text(
            'OUR COMMITMENT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyBlue,
              letterSpacing: 2,
            ),
          ).fadeIn(),
          const SizedBox(height: 20),
          SizedBox(
            width: isWeb ? 800 : double.infinity,
            child: const Text(
              'The FCU Guidance Management System is built with a strong commitment to confidentiality, accountability, and student-centered care. By leveraging modern technology, the platform enhances the guidance process and supports a safer, more responsive educational environment.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
          ).fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 60),
          isWeb
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 32,
                    mainAxisSpacing: 32,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: values.length,
                  itemBuilder: (context, index) {
                    return _buildValueCard(
                      values[index]['icon'] as IconData,
                      values[index]['title'] as String,
                      values[index]['description'] as String,
                      index,
                    );
                  },
                )
              : Column(
                  children: values.asMap().entries.map((entry) {
                    final index = entry.key;
                    final value = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildValueCard(
                        value['icon'] as IconData,
                        value['title'] as String,
                        value['description'] as String,
                        index,
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildValueCard(
    IconData icon,
    String title,
    String description,
    int index,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).fadeInSlideUp(delay: Duration(milliseconds: 100 * index));
  }
}
