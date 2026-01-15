import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/sticky_navigation_bar.dart';

class ContactCrisisSupportPage extends StatelessWidget {
  const ContactCrisisSupportPage({super.key});

  Future<void> _launchPhone(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final isTablet = MediaQuery.of(context).size.width > 600 && !isWeb;

    return Scaffold(
      body: StickyNavigationBar(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: EdgeInsets.symmetric(
              horizontal: isWeb ? 48 : isTablet ? 32 : 24,
              vertical: isWeb ? 48 : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header
                _buildPageHeader(),
                const SizedBox(height: 48),
                // Emergency Contacts Section (High Priority)
                _buildEmergencySection(context),
                const SizedBox(height: 48),
                // Guidance Office Contact Section
                _buildGuidanceOfficeSection(context),
                const SizedBox(height: 48),
                // Optional Support Message
                _buildSupportMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.skyBlue.withValues(alpha: 0.1),
                AppTheme.mediumBlue.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.skyBlue.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: const Text(
            'CONTACT SUPPORT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyBlue,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Contact Support',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'We\'re here to help. Reach out anytime - your concerns matter.',
          style: TextStyle(
            fontSize: 18,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.priority_high,
                color: AppTheme.errorRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Emergency Contacts',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildEmergencyCard(
          context,
          'Emergency Services',
          '911',
          Icons.emergency,
          Colors.red,
          () => _launchPhone('911'),
          isPrimary: true,
        ),
        const SizedBox(height: 16),
        _buildEmergencyCard(
          context,
          'Crisis Hotline',
          '1-800-273-8255',
          Icons.phone_in_talk,
          AppTheme.errorRed,
          () => _launchPhone('18002738255'),
          note: 'Available 24/7',
        ),
      ],
    );
  }

  Widget _buildEmergencyCard(
    BuildContext context,
    String label,
    String contact,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isPrimary = false,
    String? note,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPrimary
              ? [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.08),
                ]
              : [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        contact,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumGray,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceOfficeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: AppTheme.skyBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Guidance Office',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                  ),
                ),
              ],
            ),
            // FCU Logo
            Image.asset(
              'assets/img/favicon_fcu/android-chrome-192x192.png',
              height: 50,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Reach out to Filamer Christian University Guidance and Counseling Center for support.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.mediumGray,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24),
        _buildGuidanceCard(
          context,
          'Email',
          'fcu.guidance@gmail.com',
          Icons.email_rounded,
          AppTheme.skyBlue,
          () => _launchEmail('fcu.guidance@gmail.com'),
        ),
        const SizedBox(height: 16),
        _buildGuidanceCard(
          context,
          'Phone',
          '621-0471 or 621-2318 loc. 140',
          Icons.phone_rounded,
          AppTheme.skyBlue,
          () => _launchPhone('6210471'), // Launches primary number
        ),
        const SizedBox(height: 16),
        _buildGuidanceCard(
          context,
          'Facebook Page',
          'Filamer Christian University Guidance and Counseling Center',
          Icons.facebook_rounded,
          const Color(0xFF1877F2),
          () async {
            final uri = Uri.parse('https://www.facebook.com/FilamerChristianUniversityGuidanceAndCounselingCenter');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
        ),
      ],
    );
  }

  Widget _buildGuidanceCard(
    BuildContext context,
    String label,
    String contact,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.lightGray,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mediumGray,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        contact,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.paleBlue.withValues(alpha: 0.5),
            AppTheme.skyBlue.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.skyBlue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.support_agent,
              color: AppTheme.skyBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              'If you\'re unsure where to start, contacting the Guidance Office is always a safe first step.',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.darkGray,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
