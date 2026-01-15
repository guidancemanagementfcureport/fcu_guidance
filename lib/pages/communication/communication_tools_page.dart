import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/case_message_model.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/support_chat_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class CommunicationToolsPage extends StatefulWidget {
  const CommunicationToolsPage({super.key});

  @override
  State<CommunicationToolsPage> createState() => _CommunicationToolsPageState();
}

class _CommunicationToolsPageState extends State<CommunicationToolsPage> {
  final _supabase = SupabaseService();
  final _messageController = TextEditingController();
  String? _selectedMessageType;

  bool _isLoadingCases = true;
  bool _isSending = false;
  bool _isLoadingMessages = false;

  List<ReportModel> _filteredCases = [];
  List<ReportModel> _allCases = [];
  ReportModel? _selectedCase;
  List<CaseMessageModel> _messages = [];
  final Map<String, UserModel> _userCache = {};

  final List<String> _messageTypes = const [
    'Observation',
    'Recommendation',
    'Follow-up',
    'Status Update',
  ];

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCases();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          final matchedLocation = GoRouterState.of(context).matchedLocation;
          context.read<NotificationProvider>().markNotificationsAsSeenForRoute(
            authProvider.currentUser!.id,
            matchedLocation,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCases() async {
    setState(() {
      _isLoadingCases = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        return;
      }

      // Fetch regular reports
      List<ReportModel> regularReports = [];
      if (user.role == UserRole.teacher) {
        regularReports = await _supabase.getReportsWithFilters(
          teacherId: user.id,
        );
      } else if (user.role == UserRole.counselor) {
        regularReports = await _supabase.getReportsWithFilters(
          counselorId: user.id,
        );
      } else if (user.role == UserRole.dean) {
        // Dean sees only College reports
        regularReports = await _supabase.getDeanReports();
      } else if (user.role == UserRole.admin) {
        regularReports = await _supabase.getReportsWithFilters(deanId: user.id);
      }

      // Fetch and transform anonymous reports
      List<Map<String, dynamic>> anonymousReportsRaw = [];
      if (user.role == UserRole.teacher) {
        anonymousReportsRaw = await _supabase.getTeacherAnonymousReports(
          user.id,
        );
      } else if (user.role == UserRole.counselor) {
        anonymousReportsRaw = await _supabase.getCounselorAnonymousReports(
          user.id,
        );
      } else if (user.role == UserRole.dean) {
        // Dean sees ONLY college anonymous reports... but since they are anonymous,
        // we can't filter by student level directly unless we track it or infer it.
        // Assuming strictly College oversight: Filter by NO counselor or College counselor maybe?
        // Or simply SHOW NO anonymous reports if they can't determine the level.
        // However, usually Deans see all escalated.
        // Given the requirement "only college student", we will assume standard reports only
        // or anonymous reports explicitly flagged (if possible).
        // Since we can't determine level for purely anonymous, we might need to
        // exclude them OR include all.
        // Let's exclude anonymous reports for now to be safe on "student level" constraint,
        // OR ask. But since the prompt is "messages report also only college student",
        // and anonymous reports have no student attached, we'll exclude them to be safe.
        // Wait, regular functionality should remain for Admin.
        anonymousReportsRaw = [];
      } else if (user.role == UserRole.admin) {
        // Admins can see all anonymous reports for oversight
        final allAnon = await _supabase.getAnonymousReports();
        anonymousReportsRaw =
            allAnon
                .map(
                  (r) => {
                    'anonymous_reports': {
                      'id': r.id,
                      'case_code': r.trackingId,
                      'category': r.type,
                      'description': r.details,
                      'status': r.status.toString().split('.').last,
                      'created_at': r.createdAt.toIso8601String(),
                      'updated_at': r.updatedAt.toIso8601String(),
                      'teacher_note': r.teacherNote,
                      'counselor_id': r.counselorId,
                    },
                  },
                )
                .toList();
      }

      final anonymousReports =
          anonymousReportsRaw.map((data) {
            final report = data['anonymous_reports'];
            return ReportModel(
              id: report['id'],
              title: 'Anonymous Case: ${report['case_code']}',
              type: report['category'],
              details: report['description'],
              status:
                  report['status'] == 'pending'
                      ? ReportStatus.submitted
                      : ReportStatus.values.firstWhere(
                        (e) => e.toString().split('.').last == report['status'],
                        orElse: () => ReportStatus.pending,
                      ),
              isAnonymous: true,
              createdAt: DateTime.parse(report['created_at']),
              updatedAt: DateTime.parse(report['updated_at']),
              trackingId: report['case_code'],
              teacherNote: report['teacher_note'],
              counselorId: report['counselor_id'],
            );
          }).toList();

      // Fetch Support Sessions (AI Chats)
      // Filter for Deans: Only College students
      final supportSessionsRaw = await _supabase.getSupportSessions();
      var supportReports =
          supportSessionsRaw.map((session) {
            return ReportModel(
              id: session.id,
              title: 'Support Chat: ${session.studentName ?? 'Guest Student'}',
              type: 'Support Chat',
              details:
                  'Session started: ${DateFormat('MMM d').format(session.createdAt)}',
              status:
                  session.status == SupportSessionStatus.resolved
                      ? ReportStatus.settled
                      : ReportStatus.pending,
              isAnonymous: session.studentId == null,
              createdAt: session.createdAt,
              updatedAt: session.updatedAt,
              studentId: session.studentId,
            );
          }).toList();

      if (user.role == UserRole.dean) {
        // Filter support reports: must have a studentId and the student must be college
        // We need to fetch student levels for these sessions
        final studentIds =
            supportReports
                .map((r) => r.studentId)
                .whereType<String>()
                .toSet()
                .toList();
        if (studentIds.isNotEmpty) {
          final collegeUsers = await _supabase.getUsersByIds(studentIds);
          // Filter only those who are college
          final collegeIds =
              collegeUsers
                  .where(
                    (u) =>
                        u.studentLevel != null &&
                        u.studentLevel == StudentLevel.college,
                  )
                  .map((u) => u.id)
                  .toSet();

          supportReports =
              supportReports
                  .where(
                    (r) =>
                        r.studentId != null && collegeIds.contains(r.studentId),
                  )
                  .toList();
        } else {
          supportReports = [];
        }
      }

      if (mounted) {
        setState(() {
          _allCases = [
            ...regularReports,
            ...anonymousReports,
            ...supportReports,
          ];

          // Filter for counselors: only show assigned reports or unassigned ones.
          // This prevents the "Counselor is not assigned to this case" error for cases assigned to others.
          if (user.role == UserRole.counselor) {
            _allCases =
                _allCases.where((c) {
                  // If assigned to someone else, hide it
                  if (c.counselorId != null && c.counselorId != user.id) {
                    return false;
                  }
                  return true;
                }).toList();
          }

          _allCases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _filteredCases = _allCases;

          if (_selectedCase == null && _allCases.isNotEmpty) {
            _selectCase(_allCases.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading cases: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCases = false;
        });
      }
    }
  }

  Future<void> _loadUserInfo(String userId) async {
    if (userId == 'anonymous' || _userCache.containsKey(userId)) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final user = await _supabase.getUserById(userId);
      if (user != null && mounted) {
        setState(() {
          _userCache[userId] = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  Future<void> _loadAnonymousMessages(String reportId) async {
    setState(() => _isLoadingMessages = true);
    try {
      final messagesRaw = await _supabase.getAnonymousMessages(reportId);
      if (mounted) {
        setState(() {
          _messages =
              messagesRaw.map((msg) {
                return CaseMessageModel(
                  id: msg['id'],
                  caseId: msg['report_id'],
                  senderId: msg['sender_id'] ?? 'anonymous',
                  senderRole: msg['sender_type'],
                  message: msg['message'],
                  createdAt: DateTime.parse(msg['created_at']),
                );
              }).toList();
        });

        // Load sender info
        for (final msg in _messages) {
          if (msg.senderId != 'anonymous') {
            _loadUserInfo(msg.senderId);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading messages: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  Future<void> _loadSupportMessages(String sessionId) async {
    setState(() => _isLoadingMessages = true);
    try {
      final messagesRaw = await _supabase.getSupportMessages(sessionId);
      if (mounted) {
        setState(() {
          _messages =
              messagesRaw.map((msg) {
                return CaseMessageModel(
                  id: msg.id,
                  caseId: msg.sessionId,
                  senderId:
                      msg.senderId ??
                      (msg.senderRole == 'ai' ? 'ai' : 'anonymous'),
                  senderRole: msg.senderRole,
                  message: msg.message,
                  createdAt: msg.createdAt,
                );
              }).toList();
        });

        // Load sender info
        for (final msg in _messages) {
          if (msg.senderId != 'anonymous' && msg.senderId != 'ai') {
            _loadUserInfo(msg.senderId);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading support messages: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  Future<void> _loadMessages(String reportId) async {
    setState(() {
      _isLoadingMessages = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoadingMessages = false;
          });
        }
        return;
      }

      final messages = await _supabase.getCaseMessages(
        caseId: reportId,
        requester: user,
      );

      if (mounted) {
        setState(() {
          _messages = messages;
        });

        // Load sender info
        for (final msg in messages) {
          _loadUserInfo(msg.senderId);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading messages: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_selectedCase == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ToastUtils.showWarning(context, 'Please enter a message');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) return;

      if (_selectedCase!.type == 'Support Chat') {
        await _supabase.sendSupportMessage(
          sessionId: _selectedCase!.id,
          senderId: user.id,
          senderRole: user.role.toString(),
          message: text,
        );
        // Switch status to human_active if counselor replies
        await _supabase.updateSupportSessionStatus(
          _selectedCase!.id,
          SupportSessionStatus.humanActive,
        );

        _messageController.clear();
        await _loadSupportMessages(_selectedCase!.id);
      } else if (_selectedCase!.isAnonymous) {
        await _supabase.sendAnonymousMessage(
          reportId: _selectedCase!.id,
          senderType: user.role.toString(),
          senderId: user.id,
          message: text,
        );
        _messageController.clear();
        await _loadAnonymousMessages(_selectedCase!.id);
      } else {
        final messageText =
            _selectedMessageType != null && _selectedMessageType!.isNotEmpty
                ? '${_selectedMessageType!}::$text'
                : text;

        await _supabase.createCaseMessage(
          caseId: _selectedCase!.id,
          sender: user,
          message: messageText,
        );

        _messageController.clear();
        setState(() {
          _selectedMessageType = null;
        });

        await _loadMessages(_selectedCase!.id);
      }

      if (mounted) {
        ToastUtils.showSuccess(context, 'Message posted');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error sending message: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    final query = value.toLowerCase();
    setState(() {
      _filteredCases =
          _allCases.where((c) {
            final title = c.title.toLowerCase();
            final type = c.type.toLowerCase();
            final status = c.status.toString().toLowerCase();
            return title.contains(query) ||
                type.contains(query) ||
                status.contains(query);
          }).toList();
    });
  }

  String _formatTimestamp(DateTime time) {
    return DateFormat('MMM d, h:mm a').format(time);
  }

  String _extractType(String? message) {
    if (message == null) return '';
    final parts = message.split('::');
    if (parts.length > 1) {
      return parts.first;
    }
    return '';
  }

  String _extractMessage(String? message) {
    if (message == null) return '';
    final parts = message.split('::');
    if (parts.length > 1) {
      return parts.sublist(1).join('::');
    }
    return message;
  }

  void _selectCase(ReportModel c) {
    setState(() {
      _selectedCase = c;
    });

    // Mark notifications for this specific case as seen
    context.read<NotificationProvider>().markMessageAsSeen(c.id);

    if (_selectedCase!.type == 'Support Chat') {
      _loadSupportMessages(c.id);
    } else if (c.isAnonymous) {
      _loadAnonymousMessages(c.id);
    } else {
      if (c.studentId != null) {
        _loadUserInfo(c.studentId!);
      }
      _loadMessages(c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Messages report',
                subtitle: 'Case communication tracking and messages',
                icon: Icons.forum_rounded,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    final isSmallHeight = constraints.maxHeight < 600;

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child:
                          _isLoadingCases
                              ? const Center(child: CircularProgressIndicator())
                              : isWide
                              ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Case List Sidebar
                                  SizedBox(width: 320, child: _buildCaseList()),
                                  const SizedBox(width: 16),
                                  // Chat Pane
                                  Expanded(child: _buildMessagesPane()),
                                ],
                              )
                              : isSmallHeight
                              ? SingleChildScrollView(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 200,
                                      child: _buildCaseList(),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 500,
                                      child: _buildMessagesPane(),
                                    ),
                                  ],
                                ),
                              )
                              : Column(
                                children: [
                                  // In vertical layout, give case list fixed height or smaller proportion
                                  SizedBox(
                                    height: 200,
                                    child: _buildCaseList(),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(child: _buildMessagesPane()),
                                ],
                              ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaseList() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cases',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by title, type, or status',
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _filteredCases.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No cases found.'),
                      )
                      : ListView(
                        children:
                            _filteredCases
                                .map(
                                  (c) => _CaseTile(
                                    report: c,
                                    selected: _selectedCase?.id == c.id,
                                    onTap: () => _selectCase(c),
                                  ),
                                )
                                .toList(),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesPane() {
    if (_selectedCase == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Select a case to view discussion.')),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCase?.title ?? 'Case',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Show student information or anonymous indicator
                      if (_selectedCase!.isAnonymous) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_off,
                              size: 14,
                              color: AppTheme.warningOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Anonymous Report',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.warningOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_selectedCase!.trackingId != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• Tracking ID: ${_selectedCase!.trackingId!}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else if (_selectedCase!.studentId != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppTheme.skyBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _userCache[_selectedCase!.studentId]?.fullName ??
                                  'Loading student...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.darkGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_userCache[_selectedCase!.studentId]?.gmail !=
                                null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• ${_userCache[_selectedCase!.studentId]!.gmail}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Structured, case-based communication. Messages are logged and read-only after posting.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(_selectedCase!.status),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                _isLoadingMessages
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No messages yet. Start the discussion.'),
                      ),
                    )
                    : Builder(
                      builder: (context) {
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final currentUser = authProvider.currentUser;
                        final currentUserRole =
                            currentUser?.role.toString() ?? '';

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final type = _extractType(msg.message);
                            final body = _extractMessage(msg.message);

                            // Determine if message is from current user
                            final isCurrentUser =
                                msg.senderRole == currentUserRole;

                            // Colors based on role
                            String senderRoleDisplay = '';
                            Color roleColor;

                            if (msg.senderRole == 'teacher') {
                              roleColor = AppTheme.successGreen;
                              senderRoleDisplay = 'Teacher';
                            } else if (msg.senderRole == 'counselor') {
                              roleColor = AppTheme.warningOrange;
                              senderRoleDisplay = 'Counselor';
                            } else if (msg.senderRole == 'dean') {
                              roleColor = AppTheme.deepBlue;
                              senderRoleDisplay = 'Dean';
                            } else if (msg.senderRole == 'ai') {
                              roleColor = AppTheme.skyBlue;
                              senderRoleDisplay = 'AI Assistant';
                            } else {
                              roleColor = AppTheme.mediumGray;
                              senderRoleDisplay = msg.senderRole;
                            }

                            final bgColor =
                                isCurrentUser
                                    ? AppTheme.skyBlue
                                    : AppTheme.white;
                            final textColor =
                                isCurrentUser
                                    ? Colors.white
                                    : AppTheme.deepBlue;

                            return Align(
                              alignment:
                                  isCurrentUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment:
                                    isCurrentUser
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 6,
                                      left: 8,
                                      right: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isCurrentUser) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roleColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: roleColor.withValues(
                                                  alpha: 0.5,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              senderRoleDisplay,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: roleColor,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          msg.senderId == 'anonymous'
                                              ? (_selectedCase?.type ==
                                                      'Support Chat'
                                                  ? 'Guest Student'
                                                  : 'Student (Anonymous)')
                                              : msg.senderId == 'ai'
                                              ? 'Guidance Assistant'
                                              : _userCache[msg.senderId]
                                                      ?.fullName ??
                                                  '...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                isCurrentUser
                                                    ? AppTheme.skyBlue
                                                    : AppTheme.deepBlue,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roleColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: roleColor.withValues(
                                                  alpha: 0.5,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              'You ($senderRoleDisplay)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: roleColor,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.75,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(20),
                                        topRight: const Radius.circular(20),
                                        bottomLeft:
                                            isCurrentUser
                                                ? const Radius.circular(20)
                                                : const Radius.circular(4),
                                        bottomRight:
                                            isCurrentUser
                                                ? const Radius.circular(4)
                                                : const Radius.circular(20),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border:
                                          !isCurrentUser
                                              ? Border.all(
                                                color: AppTheme.skyBlue
                                                    .withValues(alpha: 0.1),
                                              )
                                              : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (type.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isCurrentUser
                                                      ? Colors.white.withValues(
                                                        alpha: 0.2,
                                                      )
                                                      : AppTheme.skyBlue
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              type,
                                              style: TextStyle(
                                                color:
                                                    isCurrentUser
                                                        ? Colors.white
                                                        : AppTheme.skyBlue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        Text(
                                          body,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: textColor,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatTimestamp(msg.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: textColor.withValues(
                                                  alpha: 0.7,
                                                ),
                                              ),
                                            ),
                                            if (isCurrentUser) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.done_all,
                                                size: 14,
                                                color: textColor.withValues(
                                                  alpha: 0.7,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _messageTypes.map((type) {
                        final selected = _selectedMessageType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              _selectedMessageType = v ? type : null;
                            });
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Post an update, observation, or recommendation',
                    filled: true,
                    fillColor: AppTheme.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.skyBlue,
                    ),
                    icon:
                        _isSending
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.send),
                    label: Text(_isSending ? 'Posting...' : 'Post message'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color color;
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        color = AppTheme.skyBlue;
        break;
      case ReportStatus.teacherReviewed:
        color = AppTheme.infoBlue;
        break;
      case ReportStatus.forwarded:
        color = AppTheme.warningOrange;
        break;
      case ReportStatus.counselorReviewed:
        color = AppTheme.warningOrange;
        break;
      case ReportStatus.counselorConfirmed:
        color = AppTheme.mediumBlue;
        break;
      case ReportStatus.approvedByDean:
        color = AppTheme.successGreen;
        break;
      case ReportStatus.counselingScheduled:
        color = AppTheme.skyBlue;
        break;
      case ReportStatus.settled:
      case ReportStatus.completed:
        color = AppTheme.successGreen;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toString().split('.').last,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({
    required this.report,
    required this.selected,
    required this.onTap,
  });

  final ReportModel report;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final hasUnread = notificationProvider.notifications.any(
          (n) =>
              !n.isRead &&
              n.type == NotificationType.newMessage &&
              (n.data['report_id'] == report.id ||
                  n.data['session_id'] == report.id),
        );

        return InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  selected
                      ? AppTheme.paleBlue.withValues(alpha: 0.35)
                      : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    hasUnread
                        ? AppTheme.skyBlue
                        : (selected
                            ? AppTheme.mediumBlue
                            : Colors.grey.shade200),
                width: hasUnread ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasUnread)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.skyBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        report.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, h:mm a').format(report.updatedAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StatusDot(status: report.status),
                    const SizedBox(width: 6),
                    Text(
                      report.status.toString().split('.').last,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  report.type,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        color = AppTheme.skyBlue;
        break;
      case ReportStatus.teacherReviewed:
        color = AppTheme.infoBlue;
        break;
      case ReportStatus.forwarded:
        color = AppTheme.warningOrange;
        break;
      case ReportStatus.counselorReviewed:
        color = AppTheme.warningOrange;
        break;
      case ReportStatus.counselorConfirmed:
        color = AppTheme.mediumBlue;
        break;
      case ReportStatus.approvedByDean:
        color = AppTheme.successGreen;
        break;
      case ReportStatus.counselingScheduled:
        color = AppTheme.skyBlue;
        break;
      case ReportStatus.settled:
      case ReportStatus.completed:
        color = AppTheme.successGreen;
        break;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
