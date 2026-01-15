import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sticky_navigation_bar.dart';

class TermsConditionPage extends StatelessWidget {
  const TermsConditionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      body: StickyNavigationBar(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section with Gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 32,
                  vertical: isMobile ? 24 : 32,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.skyBlue.withValues(alpha: 0.1),
                      AppTheme.lightBlue.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please read these terms carefully before using the Guidance Management System.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.darkGray.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Content Section
              Container(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: isMobile
                    ? _buildMobileLayout()
                    : _buildDesktopLayout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntroductionSection(),
        const SizedBox(height: 16),
        _buildSectionAccordion(
          title: '1. Introduction',
          content: _buildIntroductionContent(),
        ),
        const SizedBox(height: 8),
        _buildSectionAccordion(
          title: '2. User Responsibilities',
          content: _buildUserResponsibilitiesContent(),
        ),
        const SizedBox(height: 8),
        _buildSectionAccordion(
          title: '3. Anonymous Reporting Policy',
          content: _buildAnonymousReportingContent(),
        ),
        const SizedBox(height: 8),
        _buildSectionAccordion(
          title: '4. Data Privacy & Confidentiality',
          content: _buildDataPrivacyContent(),
        ),
        const SizedBox(height: 8),
        _buildSectionAccordion(
          title: '5. Role-Based Access',
          content: _buildRoleBasedAccessContent(),
        ),
        const SizedBox(height: 8),
        _buildSectionAccordion(
          title: '6. System Limitations',
          content: _buildSystemLimitationsContent(),
        ),
        const SizedBox(height: 8),
        _buildSectionAccordion(
          title: '7. Modifications & Updates',
          content: _buildModificationsContent(),
        ),
        const SizedBox(height: 24),
        _buildAcceptanceStatement(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntroductionSection(),
        const SizedBox(height: 32),
        _buildSectionCard(
          title: '1. Introduction',
          content: _buildIntroductionContent(),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '2. User Responsibilities',
          content: _buildUserResponsibilitiesContent(),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '3. Anonymous Reporting Policy',
          content: _buildAnonymousReportingContent(),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '4. Data Privacy & Confidentiality',
          content: _buildDataPrivacyContent(),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '5. Role-Based Access',
          content: _buildRoleBasedAccessContent(),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '6. System Limitations',
          content: _buildSystemLimitationsContent(),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: '7. Modifications & Updates',
          content: _buildModificationsContent(),
        ),
        const SizedBox(height: 32),
        _buildAcceptanceStatement(),
      ],
    );
  }

  Widget _buildIntroductionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.skyBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.skyBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to the Guidance Management System',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This system is designed to support students, teachers, counselors, deans, and administrators in managing guidance-related activities. Our platform emphasizes confidentiality, responsible use, and the well-being of all users.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.darkGray,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget content}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightBlue.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGray.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.skyBlue.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _buildSectionAccordion({
    required String title,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightBlue.withValues(alpha: 0.3),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.deepBlue,
          ),
        ),
        trailing: const Icon(
          Icons.expand_more,
          color: AppTheme.skyBlue,
        ),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.skyBlue.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _buildIntroductionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The Guidance Management System is a secure platform designed to facilitate communication and case management between students, teachers, counselors, and administrators.',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Who can use this system:',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.deepBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '• Students: Submit reports, request counseling, and track case status\n'
          '• Teachers: Review student reports, monitor cases, and communicate with guidance staff\n'
          '• Counselors: Manage cases, track student history, and provide support\n'
          '• Deans: Oversee guidance operations, review reports, and monitor institutional compliance\n'
          '• Administrators: Manage user accounts, system settings, and analytics',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildUserResponsibilitiesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All users are expected to use this system responsibly and in good faith. By using the platform, you agree to:',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _buildBulletPoint('Provide truthful and accurate information in all reports and communications'),
        _buildBulletPoint('Use the platform only for legitimate guidance-related purposes'),
        _buildBulletPoint('Respect the privacy and confidentiality of all users'),
        _buildBulletPoint('Refrain from submitting false reports, harassment, or abuse'),
        _buildBulletPoint('Report any misuse or security concerns immediately to administrators'),
        _buildBulletPoint('Follow all school policies and guidelines'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.warningOrange.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            'Important: Misuse of the system, including false reporting or abuse, may result in disciplinary action and account suspension.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.darkGray,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnonymousReportingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The Guidance Management System supports anonymous reporting to encourage students to come forward with concerns without fear of identification.',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _buildBulletPoint('Anonymous reports do not require user login or personal identification'),
        _buildBulletPoint('A unique tracking ID is provided for anonymous reporters to check status'),
        _buildBulletPoint('Your identity remains completely confidential and is not stored'),
        _buildBulletPoint('The guidance office may investigate reports as needed to ensure student safety'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.infoBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.infoBlue.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            'Note: While anonymous reporting is allowed, abuse of this feature (such as submitting false or malicious reports) is strictly prohibited and may be investigated.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.darkGray,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your privacy and the confidentiality of all information shared through this system are our top priorities.',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _buildBulletPoint('All data is encrypted and stored securely using industry-standard security measures'),
        _buildBulletPoint('Reports and case information are accessible only to authorized guidance staff members'),
        _buildBulletPoint('User information is protected in accordance with privacy laws and school policies'),
        _buildBulletPoint('No personal information is shared with unauthorized parties'),
        _buildBulletPoint('Anonymous reports maintain complete confidentiality—no identifying information is collected'),
        const SizedBox(height: 12),
        Text(
          'Data Retention:',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.deepBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Case records and reports are retained in accordance with school policies and legal requirements. You may request access to your own data or request deletion in accordance with applicable privacy laws.',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBasedAccessContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The Guidance Management System uses role-based access control to ensure that users only see and interact with information appropriate to their role.',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _buildRoleItem('Students', 'Can submit reports, request counseling, and view their own case status'),
        _buildRoleItem('Teachers', 'Can review student reports, monitor cases assigned to them, and communicate with guidance staff'),
        _buildRoleItem('Counselors', 'Can manage all cases, access student history, view reports, and provide guidance support'),
        _buildRoleItem('Deans', 'Can oversee guidance operations, review all reports, monitor institutional compliance, and access analytics'),
        _buildRoleItem('Administrators', 'Can manage user accounts, system settings, generate reports, and have full system access'),
        const SizedBox(height: 12),
        Text(
          'Access to information is strictly limited to what is necessary for each role to perform their duties effectively.',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemLimitationsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'It is important to understand the limitations of this system:',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _buildBulletPoint('This system is a support tool for guidance activities, not an emergency service'),
        _buildBulletPoint('For immediate emergencies or crisis situations, contact emergency services (911) or campus security directly'),
        _buildBulletPoint('Guidance outcomes may vary based on case evaluation and available resources'),
        _buildBulletPoint('Response times may vary depending on case priority and counselor availability'),
        _buildBulletPoint('The system does not replace direct communication with guidance counselors when urgent matters arise'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.warningOrange.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency Situations:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'If you or someone else is in immediate danger, please contact emergency services immediately. Do not rely solely on this system for emergency situations.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkGray,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModificationsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The Guidance Management System may be updated and improved over time. These Terms & Conditions may be modified to reflect changes in the system, policies, or legal requirements.',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkGray,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _buildBulletPoint('We will notify users of significant changes to these terms'),
        _buildBulletPoint('Continued use of the system after changes are made indicates acceptance of the updated terms'),
        _buildBulletPoint('You are encouraged to review these terms periodically'),
        _buildBulletPoint('If you do not agree with updated terms, you may discontinue use of the system'),
        const SizedBox(height: 12),
        Text(
          'Last Updated:',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.deepBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'These terms were last updated on the date of system deployment. Check back periodically for updates.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.darkGray,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptanceStatement() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.skyBlue.withValues(alpha: 0.1),
            AppTheme.lightBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.skyBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppTheme.successGreen,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'By using this system, you acknowledge that you have read, understood, and agreed to these Terms & Conditions. You agree to use the Guidance Management System responsibly and in accordance with all stated policies.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.deepBlue,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.skyBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
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

  Widget _buildRoleItem(String role, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$role:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              description,
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
