import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';
import 'dart:math';

class GuidanceResourcesPage extends StatefulWidget {
  const GuidanceResourcesPage({super.key});

  @override
  State<GuidanceResourcesPage> createState() => _GuidanceResourcesPageState();
}

class _GuidanceResourcesPageState extends State<GuidanceResourcesPage> {
  // Quote Search State
  final TextEditingController _quoteSearchController = TextEditingController();
  final List<Map<String, String>> _quotes = [
    {
      'quote': "Believe you can and you're halfway there.",
      'author': "Theodore Roosevelt",
    },
    {
      'quote': "The only way to do great work is to love what you do.",
      'author': "Steve Jobs",
    },
    {
      'quote':
          "Success is not final, failure is not fatal: it is the courage to continue that counts.",
      'author': "Winston Churchill",
    },
    {
      'quote': "It always seems impossible until it's done.",
      'author': "Nelson Mandela",
    },
    {
      'quote': "Don't watch the clock; do what it does. Keep going.",
      'author': "Sam Levenson",
    },
    {
      'quote':
          "You are never too old to set another goal or to dream a new dream.",
      'author': "C.S. Lewis",
    },
    {
      'quote': "Start where you are. Use what you have. Do what you can.",
      'author': "Arthur Ashe",
    },
    {
      'quote':
          "Your time is limited, so don't waste it living someone else's life.",
      'author': "Steve Jobs",
    },
  ];
  Map<String, String>? _displayedQuote;

  // Playlist State
  // Mock Data for Playlists
  final List<Map<String, dynamic>> _musicTracks = [
    {
      'title': 'Focus & Relax Music',
      'description': 'Calming lo-fi beats to help you study or relax.',
      'url': 'https://youtu.be/1ZYbU82GVz4?si=dif153OtXexMqS1a',
    },
    {
      'title': 'Deep Focus Music',
      'description': 'Ambient soundscapes for deep concentration.',
      'url': 'https://www.youtube.com/watch?v=WPni755-Krg',
    },
    {
      'title': 'Study with Me',
      'description': 'Real-time study session with calming background.',
      'url': 'https://www.youtube.com/watch?v=M5QY2_8704o',
    },
    {
      'title': 'Piano for Studying',
      'description': 'Soft piano music to enhance focus.',
      'url': 'https://www.youtube.com/watch?v=XULUBg_ZcAU',
    },
  ];

  final List<Map<String, dynamic>> _meditationTracks = [
    {
      'title': 'Breathing Exercise',
      'description': 'Take a moment to breathe deep and reset.',
      'url': 'https://www.youtube.com/watch?v=inpok4MKVLM',
    },
    {
      'title': '5-Minute Meditation',
      'description': 'Quick stress relief for busy students.',
      'url': 'https://www.youtube.com/watch?v=ssss7V1_eyA',
    },
    {
      'title': 'Mindfulness for Anxiety',
      'description': 'Guided meditation to reduce anxiety.',
      'url': 'https://www.youtube.com/watch?v=O-6f5wQXSu8',
    },
    {
      'title': 'Sleep Meditation',
      'description': 'Drift off to sleep with this guided session.',
      'url': 'https://www.youtube.com/watch?v=aEqlQvczMJQ',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Set initial random quote
    _generateRandomQuote();
  }

  void _generateRandomQuote() {
    setState(() {
      _displayedQuote = _quotes[Random().nextInt(_quotes.length)];
    });
  }

  void _searchQuote() {
    final query = _quoteSearchController.text.toLowerCase();
    if (query.isEmpty) {
      _generateRandomQuote();
      return;
    }

    final result = _quotes.firstWhere(
      (q) =>
          q['quote']!.toLowerCase().contains(query) ||
          q['author']!.toLowerCase().contains(query),
      orElse: () => {'quote': 'No matching quote found.', 'author': ''},
    );

    setState(() {
      _displayedQuote = result;
    });
  }

  @override
  void dispose() {
    _quoteSearchController.dispose();
    super.dispose();
  }

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
                title: 'Guidance Resources',
                subtitle: 'Helpful resources for your well-being',
                icon: Icons.library_books_rounded,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.of(context).size.width > 600 ? 24 : 16,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
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
                                    color: AppTheme.skyBlue.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.library_books_rounded,
                                    color: AppTheme.skyBlue,
                                    size: 48,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Guidance Resources',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.deepBlue,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Helpful tips and support materials to guide you through your academic and personal journey.',
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

                          // NEW: Daily Inspiration (Searchable Quotes)
                          _buildQuoteSection(context),
                          const SizedBox(height: 32),

                          // NEW: Relaxation Zone (Music & Meditation Playlists)
                          _buildRelaxationSection(context),
                          const SizedBox(height: 32),

                          // Section 1: Wellness Tips
                          _buildSection(
                            context,
                            title: 'Wellness Tips',
                            icon: Icons.favorite_rounded,
                            color: AppTheme.errorRed,
                            cards: [
                              _ResourceCard(
                                icon: Icons.self_improvement_rounded,
                                title: 'Managing Stress in School',
                                description:
                                    'Take regular breaks, practice deep breathing, and maintain a balanced schedule to manage academic stress effectively.',
                                color: AppTheme.errorRed,
                                linkUrl:
                                    'https://www.apa.org/topics/stress/tips',
                              ),
                              _ResourceCard(
                                icon: Icons.school_rounded,
                                title: 'Building Healthy Study Habits',
                                description:
                                    'Create a consistent study routine, find a quiet space, and use active learning techniques to improve retention.',
                                color: AppTheme.errorRed,
                                linkUrl:
                                    'https://learningcenter.unc.edu/tips-and-tools/studying-101-study-smarter-not-harder/',
                              ),
                              _ResourceCard(
                                icon: Icons.trending_up_rounded,
                                title: 'How to Stay Motivated',
                                description:
                                    'Set achievable goals, celebrate small wins, and remember your long-term aspirations to maintain motivation.',
                                color: AppTheme.errorRed,
                                linkUrl:
                                    'https://www.verywellmind.com/surprising-ways-to-get-motivated-2795388',
                              ),
                              _ResourceCard(
                                icon: Icons.people_rounded,
                                title: 'Managing Social Pressure',
                                description:
                                    'Stay true to your values, surround yourself with supportive friends, and don\'t be afraid to say no when needed.',
                                color: AppTheme.errorRed,
                                linkUrl:
                                    'https://kidshealth.org/en/teens/peer-pressure.html',
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Section 2: Understanding Counseling
                          _buildSection(
                            context,
                            title: 'Understanding Counseling',
                            icon: Icons.psychology_rounded,
                            color: AppTheme.warningOrange,
                            cards: [
                              _ResourceCard(
                                icon: Icons.help_outline_rounded,
                                title: 'When Should I Request Counseling?',
                                description:
                                    'Request counseling when you need support with personal issues, academic concerns, or emotional well-being after a report is confirmed.',
                                color: AppTheme.warningOrange,
                              ),
                              _ResourceCard(
                                icon: Icons.timeline_rounded,
                                title: 'What Happens After I Submit a Report?',
                                description:
                                    'Your report is reviewed by a teacher, then forwarded to a counselor who confirms it. Once confirmed, you can request counseling.',
                                color: AppTheme.warningOrange,
                              ),
                              _ResourceCard(
                                icon: Icons.event_note_rounded,
                                title: 'What to Expect During Counseling',
                                description:
                                    'Counseling sessions provide a safe, confidential space to discuss concerns, develop coping strategies, and receive guidance.',
                                color: AppTheme.warningOrange,
                              ),
                              _ResourceCard(
                                icon: Icons.person_outline_rounded,
                                title: 'Role of the Counselor',
                                description:
                                    'Counselors provide emotional support, help develop problem-solving skills, and guide you through challenges in a confidential setting.',
                                color: AppTheme.warningOrange,
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Section 3: Safety & Reporting Guide
                          _buildSection(
                            context,
                            title: 'Safety & Reporting Guide',
                            icon: Icons.security_rounded,
                            color: AppTheme.successGreen,
                            cards: [
                              _ResourceCard(
                                icon: Icons.report_problem_rounded,
                                title: 'How to Report an Incident Safely',
                                description:
                                    'Use the Submit Report feature to document incidents. Include details, date, and any relevant attachments. Reports are confidential.',
                                color: AppTheme.successGreen,
                              ),
                              _ResourceCard(
                                icon: Icons.flag_rounded,
                                title: 'Why Reporting Matters',
                                description:
                                    'Reporting helps create a safer campus environment, ensures incidents are addressed, and provides you with the support you need.',
                                color: AppTheme.successGreen,
                              ),
                              _ResourceCard(
                                icon: Icons.lock_rounded,
                                title: 'Confidentiality and Data Privacy',
                                description:
                                    'Your reports and counseling requests are kept confidential. Only authorized staff members have access to your information.',
                                color: AppTheme.successGreen,
                              ),
                              _ResourceCard(
                                icon: Icons.gavel_rounded,
                                title: 'Your Rights as a Student',
                                description:
                                    'You have the right to report incidents, request counseling, receive support, and have your concerns taken seriously.',
                                color: AppTheme.successGreen,
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Section 4: Study & Productivity Advice
                          _buildSection(
                            context,
                            title: 'Study & Productivity Advice',
                            icon: Icons.lightbulb_rounded,
                            color: AppTheme.infoBlue,
                            cards: [
                              _ResourceCard(
                                icon: Icons.schedule_rounded,
                                title: 'Time Management Basics',
                                description:
                                    'Prioritize tasks, use a planner, break large projects into smaller steps, and allocate time for both study and relaxation.',
                                color: AppTheme.infoBlue,
                              ),
                              _ResourceCard(
                                icon: Icons.balance_rounded,
                                title: 'Balancing Academics and Personal Life',
                                description:
                                    'Set boundaries, schedule downtime, maintain hobbies, and ensure you have time for friends and family alongside studies.',
                                color: AppTheme.infoBlue,
                              ),
                              _ResourceCard(
                                icon: Icons.checklist_rounded,
                                title: 'Setting Priorities',
                                description:
                                    'Identify what\'s most important, focus on urgent and important tasks first, and learn to delegate or postpone less critical items.',
                                color: AppTheme.infoBlue,
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Section 5: Quick Help / Emergency Contacts
                          _buildSection(
                            context,
                            title: 'Quick Help & Emergency Contacts',
                            icon: Icons.phone_rounded,
                            color: AppTheme.mediumBlue,
                            cards: [
                              _ResourceCard(
                                icon: Icons.business_rounded,
                                title: 'Guidance Office',
                                description:
                                    'Contact the guidance office during school hours for appointments, questions, or support. Visit in person or call during office hours.',
                                color: AppTheme.mediumBlue,
                              ),
                              _ResourceCard(
                                icon: Icons.emergency_rounded,
                                title: 'Emergency Hotline',
                                description:
                                    'For immediate emergencies, contact campus security or call the emergency hotline. Your safety is our priority.',
                                color: AppTheme.mediumBlue,
                              ),
                              _ResourceCard(
                                icon: Icons.policy_rounded,
                                title: 'Campus Policies',
                                description:
                                    'Access campus policies and procedures through the school website. Understanding policies helps you know your rights and responsibilities.',
                                color: AppTheme.mediumBlue,
                              ),
                              _ResourceCard(
                                icon: Icons.support_agent_rounded,
                                title: 'Self-Help Resources',
                                description:
                                    'Explore online resources, mental health apps, and self-help materials available through the guidance office and school library.',
                                color: AppTheme.mediumBlue,
                              ),
                            ],
                          ),

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
    required List<_ResourceCard> cards,
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
              child: Icon(icon, color: color, size: 28),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            int crossAxisCount = 1;
            double aspectRatio = 1.1;

            if (width > 900) {
              crossAxisCount = 3;
              aspectRatio = 1.0; // Square-ish on desktops
            } else if (width > 600) {
              crossAxisCount = 2;
              aspectRatio = 0.9; // Taller on tablets
            } else {
              crossAxisCount = 1;
              aspectRatio = 1.3; // Flatter on mobile for list-like feel
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20, // Increased spacing
                mainAxisSpacing: 20,
                childAspectRatio: aspectRatio,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                return cards[index].fadeInSlideUp(delay: (index * 50).ms);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuoteSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.skyBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 40,
                color: AppTheme.skyBlue,
              ),
              // Search Bar for Quotes
              SizedBox(
                width: 250,
                height: 40,
                child: TextField(
                  controller: _quoteSearchController,
                  onChanged: (value) => _searchQuote(),
                  decoration: InputDecoration(
                    hintText: 'Search for inspiration...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppTheme.mediumGray.withValues(alpha: 0.7),
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: AppTheme.skyBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: AppTheme.skyBlue.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '"${_displayedQuote?['quote'] ?? 'Believe in yourself.'}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '- ${_displayedQuote?['author'] ?? 'Unknown'}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.mediumGray,
            ),
          ),
          const SizedBox(height: 16),
          // "New Quote" Button to simply shuffle if search is empty
          TextButton.icon(
            onPressed: _generateRandomQuote,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('New Quote'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.skyBlue),
          ),
        ],
      ),
    ).fadeInSlideUp(delay: 200.ms);
  }

  Widget _buildRelaxationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.library_music_rounded,
                color: AppTheme.purple,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Curated Playlists',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Audio sessions for focus and relaxation',
                    style: TextStyle(fontSize: 14, color: AppTheme.mediumGray),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: _PlaylistCard(
                    title: 'Focus & Study',
                    subtitle: 'Beats to boost concentration',
                    icon: Icons.headphones_rounded,
                    color: AppTheme.purple,
                    tracks: _musicTracks,
                    startIndex: 1,
                  ),
                ),
                SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),
                Expanded(
                  flex: isWide ? 1 : 0,
                  child: _PlaylistCard(
                    title: 'Mindfulness & Sleep',
                    subtitle: 'Guided sessions for peace',
                    icon: Icons.self_improvement_rounded,
                    color: AppTheme.teal,
                    tracks: _meditationTracks,
                    startIndex: 1,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> tracks;
  final int startIndex;

  const _PlaylistCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tracks,
    required this.startIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Playlist Header (Album Art Style)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Row(
              children: [
                // Album Art Placeholder
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 40, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLAYLIST',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.deepBlue,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.deepBlue.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tracks List
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children:
                  tracks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final track = entry.value;
                    return _TrackTile(
                      index: startIndex + index,
                      title: track['title'],
                      description: track['description'],
                      url: track['url'],
                      color: color,
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    ).fadeInSlideUp();
  }
}

class _TrackTile extends StatefulWidget {
  final int index;
  final String title;
  final String description;
  final String url;
  final Color color;

  const _TrackTile({
    required this.index,
    required this.title,
    required this.description,
    required this.url,
    required this.color,
  });

  @override
  State<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<_TrackTile> {
  bool _isHovered = false;

  void _onTap() {
    final videoId = YoutubePlayerController.convertUrlToId(widget.url);
    if (videoId != null) {
      showDialog(
        context: context,
        builder: (context) => _YoutubeDialog(videoId: videoId),
      );
    } else {
      _launchUrl();
    }
  }

  Future<void> _launchUrl() async {
    final uri = Uri.parse(widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch ${widget.url}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color:
                _isHovered
                    ? widget.color.withValues(alpha: 0.05)
                    : Colors.transparent,
          ),
          child: Row(
            children: [
              // Track Number / Play Icon
              SizedBox(
                width: 32,
                child: Center(
                  child:
                      _isHovered
                          ? Icon(
                            Icons.play_arrow_rounded,
                            size: 20,
                            color: widget.color,
                          )
                          : Text(
                            '${widget.index}',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGray,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
              const SizedBox(width: 16),
              // Track Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _isHovered ? widget.color : AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGray.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Trailing Elements
              if (_isHovered)
                Icon(
                  Icons.more_horiz_rounded,
                  color: AppTheme.mediumGray,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YoutubeDialog extends StatefulWidget {
  final String videoId;

  const _YoutubeDialog({required this.videoId});

  @override
  State<_YoutubeDialog> createState() => _YoutubeDialogState();
}

class _YoutubeDialogState extends State<_YoutubeDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
        ),
      ),
    );
  }
}

class _ResourceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String? linkUrl;

  const _ResourceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.linkUrl,
  });

  @override
  State<_ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<_ResourceCard> {
  bool _isHovered = false;

  Future<void> _launchUrl() async {
    if (widget.linkUrl == null) return;
    final uri = Uri.parse(widget.linkUrl!);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch ${widget.linkUrl}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor:
          widget.linkUrl != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.linkUrl != null ? _launchUrl : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0.0,
            _isHovered ? -5.0 : 0.0,
            0.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.color.withValues(alpha: _isHovered ? 0.3 : 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _isHovered ? 0.15 : 0.05),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 28),
                    ),
                    if (widget.linkUrl != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 18,
                          color: widget.color,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.mediumGray,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).fadeInSlideUp();
  }
}
