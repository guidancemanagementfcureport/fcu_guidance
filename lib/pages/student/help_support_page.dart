import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Help & Support',
                subtitle: 'Get help and guidance for using the system',
                icon: Icons.help_outline_rounded,
              ),
              Expanded(
                child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Section
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.skyBlue.withValues(alpha: 0.1),
                            AppTheme.mediumBlue.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.skyBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.help_outline_rounded,
                              color: AppTheme.skyBlue,
                              size: 48,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Help & Support',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Get help and guidance for using the system.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.mediumGray,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).fadeInSlideUp(),
                    const SizedBox(height: 32),

                    // Section A: Getting Started
                    _buildSection(
                      context,
                      title: 'Getting Started',
                      icon: Icons.play_circle_outline_rounded,
                      color: AppTheme.skyBlue,
                      items: [
                        _HelpItem(
                          icon: Icons.report_problem_rounded,
                          title: 'How to Submit an Incident Report',
                          description:
                              'Navigate to Submit Report, fill in the required fields (title, type, description, date), optionally attach files, and submit. Your report will be reviewed by a teacher.',
                          color: AppTheme.skyBlue,
                        ),
                        _HelpItem(
                          icon: Icons.psychology_rounded,
                          title: 'How to Request Counseling',
                          description:
                              'After a counselor confirms your report, you can request counseling. Select the confirmed report, provide your reason and preferred time, then submit your request.',
                          color: AppTheme.skyBlue,
                        ),
                        _HelpItem(
                          icon: Icons.track_changes_rounded,
                          title: 'Understanding Report Statuses',
                          description:
                              'Reports progress through: Submitted → Reviewed by Teacher → Forwarded → Counselor Confirmed → Approved by Dean (for College) → Settled.',
                          color: AppTheme.skyBlue,
                        ),
                        _HelpItem(
                          icon: Icons.info_outline_rounded,
                          title: 'How the Guidance Process Works',
                          description:
                              'Submit a report → Teacher reviews → Counselor handles → Dean approves (for College) → Case settled. Each step is tracked in your dashboard.',
                          color: AppTheme.skyBlue,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Section B: Frequently Asked Questions
                    _buildFAQSection(context),

                    const SizedBox(height: 32),

                    // Section C: Troubleshooting
                    _buildSection(
                      context,
                      title: 'Troubleshooting',
                      icon: Icons.build_rounded,
                      color: AppTheme.warningOrange,
                      items: [
                        _HelpItem(
                          icon: Icons.error_outline_rounded,
                          title: 'I cannot submit a report',
                          description:
                              'Check your internet connection, ensure all required fields are filled, and verify file attachments are under 10MB. If issues persist, contact the guidance office.',
                          color: AppTheme.warningOrange,
                        ),
                        _HelpItem(
                          icon: Icons.visibility_off_rounded,
                          title: 'My counseling request is not appearing',
                          description:
                              'Ensure your report has been confirmed by a counselor first. Only confirmed reports allow counseling requests. Check your Counseling Status page for updates.',
                          color: AppTheme.warningOrange,
                        ),
                        _HelpItem(
                          icon: Icons.refresh_rounded,
                          title: 'The page is not loading',
                          description:
                              'Try refreshing the page, clearing your browser cache, or using a different browser. If the problem continues, contact technical support.',
                          color: AppTheme.warningOrange,
                        ),
                        _HelpItem(
                          icon: Icons.lock_outline_rounded,
                          title: 'I cannot log in',
                          description:
                              'Verify your email and password are correct. Use the "Forgot Password" option if needed. Contact the guidance office if you need account assistance.',
                          color: AppTheme.warningOrange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Section D: Contact Support
                    _buildContactSection(context),

                    const SizedBox(height: 32),

                    // Section E: Quick Links
                    _buildQuickLinksSection(context),

                    const SizedBox(height: 32),
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

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<_HelpItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...items.map((item) => item.fadeInSlideUp()),
      ],
    );
  }

  Widget _buildFAQSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.quiz_rounded,
                color: AppTheme.successGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _FAQItem(
                question: 'Who can see my report?',
                answer:
                    'Only authorized teachers, counselors, and the College Dean (for college student reports) can view your reports. Your information is kept confidential and is only shared with staff members who need to review and address your concerns.',
              ),
              const Divider(height: 1),
              _FAQItem(
                question: 'Is my information confidential?',
                answer:
                    'Yes, all reports and counseling requests are kept strictly confidential. Only authorized guidance staff members have access to your information, and it is protected under student privacy regulations.',
              ),
              const Divider(height: 1),
              _FAQItem(
                question: 'How long does the review process take?',
                answer:
                    'The review process typically takes 1-3 business days. Teachers review reports first, then forward them to counselors. For college students, the Dean provides final approval before the case is settled.',
              ),
              const Divider(height: 1),
              _FAQItem(
                question: 'What if I submitted a report by mistake?',
                answer:
                    'Contact the guidance office immediately if you need to correct or withdraw a report. They can assist you with the necessary steps to address the situation.',
              ),
              const Divider(height: 1),
              _FAQItem(
                question: 'Can I edit or cancel a counseling request?',
                answer:
                    'Once submitted, counseling requests cannot be edited directly. If you need to make changes or cancel, please contact the guidance office or your assigned counselor.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.mediumBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.contact_support_rounded,
                color: AppTheme.mediumBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _ContactItem(
                  icon: Icons.email_rounded,
                  label: 'Guidance Office Email',
                  value: 'fcu.guidance@gmail.com',
                  color: AppTheme.skyBlue,
                ),
                const SizedBox(height: 20),
                _ContactItem(
                  icon: Icons.phone_rounded,
                  label: 'Phone Number',
                  value: '621-0471 or 621-2318 loc. 140',
                  color: AppTheme.successGreen,
                ),
                const SizedBox(height: 20),
                _ContactItem(
                  icon: Icons.facebook_rounded,
                  label: 'Facebook Page',
                  value: 'Filamer Christian University Guidance Center',
                  color: const Color(0xFF1877F2),
                ),
                const SizedBox(height: 20),
                _ContactItem(
                  icon: Icons.location_on_rounded,
                  label: 'Office Location',
                  value: 'FCU Campus, Guidance & Counseling Office',
                  color: AppTheme.errorRed,
                ),
                const SizedBox(height: 20),
                _ContactItem(
                  icon: Icons.emergency_rounded,
                  label: 'Emergency / Crisis Support',
                  value: '911 or Crisis Hotline: 1-800-273-8255',
                  color: AppTheme.errorRed,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLinksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.link_rounded,
                color: AppTheme.infoBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Quick Links',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _QuickLinkCard(
                  icon: Icons.library_books_rounded,
                  title: 'Guidance Resources',
                  onTap: () => context.go('/student/resources'),
                  color: AppTheme.skyBlue,
                ),
                _QuickLinkCard(
                  icon: Icons.report_outlined,
                  title: 'Submit a Report',
                  onTap: () => context.go('/student/submit-report'),
                  color: AppTheme.warningOrange,
                ),
                _QuickLinkCard(
                  icon: Icons.track_changes_outlined,
                  title: 'Counseling Status',
                  onTap: () => context.go('/student/counseling-status'),
                  color: AppTheme.successGreen,
                ),
                _QuickLinkCard(
                  icon: Icons.visibility_outlined,
                  title: 'Report Status',
                  onTap: () => context.go('/student/report-status'),
                  color: AppTheme.infoBlue,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Text(
        widget.question,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.deepBlue,
        ),
      ),
      trailing: Icon(
        _isExpanded ? Icons.expand_less : Icons.expand_more,
        color: AppTheme.skyBlue,
      ),
      onExpansionChanged: (expanded) {
        setState(() {
          _isExpanded = expanded;
        });
      },
      children: [
        Text(
          widget.answer,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.darkGray,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ContactItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
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
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.deepBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color color;

  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.deepBlue,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

