import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class RequestCounselingPage extends StatefulWidget {
  const RequestCounselingPage({super.key});

  @override
  State<RequestCounselingPage> createState() => _RequestCounselingPageState();
}

class _RequestCounselingPageState extends State<RequestCounselingPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _detailsController = TextEditingController();

  final _supabase = SupabaseService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<ReportModel> _confirmedReports = [];
  ReportModel? _selectedReport;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String? _selectedCounselorId;

  // Participant selection
  final Map<String, bool> _selectedParticipants = {}; // userId -> isSelected
  final Map<String, String> _participantRoles = {}; // userId -> role
  List<UserModel> _facilitators = [];
  List<UserModel> _advisers = [];
  bool _includeParent = false;

  @override
  void initState() {
    super.initState();
    _loadConfirmedReports();
    _loadParticipants();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _loadParticipants() async {
    try {
      final allUsers = await _supabase.getAllUsers();
      final facilitators =
          allUsers
              .where(
                (u) => u.role == UserRole.counselor && u.status == 'active',
              )
              .toList();
      final advisers =
          allUsers
              .where((u) => u.role == UserRole.teacher && u.status == 'active')
              .toList();

      if (mounted) {
        setState(() {
          _facilitators = facilitators;
          _advisers = advisers;
        });
      }
    } catch (e) {
      debugPrint('Error loading participants: $e');
    }
  }

  void _toggleParticipant(String userId, String role) {
    setState(() {
      if (_selectedParticipants[userId] == true) {
        _selectedParticipants[userId] = false;
        _participantRoles.remove(userId);
      } else {
        _selectedParticipants[userId] = true;
        _participantRoles[userId] = role;
      }
    });
  }

  List<Map<String, dynamic>> _getSelectedParticipants() {
    final List<Map<String, dynamic>> participants = [];
    _selectedParticipants.forEach((userId, isSelected) {
      if (isSelected && _participantRoles.containsKey(userId)) {
        participants.add({
          'userId': userId,
          'role': _participantRoles[userId]!,
        });
      }
    });
    // Add parent/guardian as a participant flag if selected
    if (_includeParent) {
      participants.add({'role': 'parent'});
    }
    return participants;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadConfirmedReports() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.id;

      if (studentId != null) {
        final reports = await _supabase.getConfirmedReportsForStudent(
          studentId,
        );
        if (mounted) {
          setState(() {
            _confirmedReports = reports;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading reports: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReport == null) {
      ToastUtils.showWarning(context, 'Please select a confirmed report');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.id;

      if (studentId == null) {
        ToastUtils.showError(context, 'User not authenticated');
        setState(() => _isSubmitting = false);
        return;
      }

      await _supabase.createCounselingRequest(
        studentId: studentId,
        reportId: _selectedReport!.id,
        reason:
            _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
        requestDetails:
            _detailsController.text.trim().isEmpty
                ? null
                : _detailsController.text.trim(),
        sessionDate: _selectedDate,
        sessionTime: _selectedTime,
        sessionType: null,
        locationMode: null,
        participants:
            _getSelectedParticipants().isNotEmpty
                ? _getSelectedParticipants()
                : null,
        counselorId: _selectedCounselorId,
      );

      if (mounted) {
        ToastUtils.showSuccess(
          context,
          'Counseling request submitted successfully',
        );
        context.go('/student/counseling-status');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error submitting request: $e');
        setState(() => _isSubmitting = false);
      }
    }
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
                title: 'Request Counseling',
                subtitle: 'Schedule a counseling session',
                icon: Icons.calendar_today_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                MediaQuery.of(context).size.width > 600
                                    ? 24
                                    : 16,
                            vertical: 24,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 800,
                                minHeight:
                                    MediaQuery.of(context).size.height - 200,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Hero Section
                                    Container(
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.warningOrange.withValues(
                                              alpha: 0.1,
                                            ),
                                            AppTheme.skyBlue.withValues(
                                              alpha: 0.05,
                                            ),
                                          ],
                                        ),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(24),
                                            ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: AppTheme.warningOrange
                                                  .withAlpha(20),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.psychology_rounded,
                                              size: 48,
                                              color: AppTheme.warningOrange,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Text(
                                            'Request Counseling',
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.deepBlue,
                                              letterSpacing: -0.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Request counseling support for a report approved by Dean. You can schedule your session and choose who will attend.',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: AppTheme.mediumGray,
                                              height: 1.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ).fadeInSlideUp(),

                                    // Form Card
                                    Card(
                                      elevation: 8,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              bottom: Radius.circular(24),
                                            ),
                                        side: BorderSide(
                                          color: AppTheme.lightBlue.withAlpha(
                                            77,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            // Select Report Section
                                            _buildSectionLabel(
                                              'Select Approved Report',
                                            ),
                                            const SizedBox(height: 16),
                                            if (_confirmedReports.isEmpty)
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  24,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.lightBlue
                                                      .withAlpha(26),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      Icons.info_outline,
                                                      size: 48,
                                                      color:
                                                          AppTheme.mediumGray,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'No Approved Reports',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppTheme.deepBlue,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'You can only request counseling for reports that have been approved by the Dean. Please wait for your report to be approved first.',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color:
                                                            AppTheme.mediumGray,
                                                        height: 1.5,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              ..._confirmedReports.map<Widget>((
                                                report,
                                              ) {
                                                final isSelected =
                                                    _selectedReport?.id ==
                                                    report.id;
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color:
                                                          isSelected
                                                              ? AppTheme
                                                                  .warningOrange
                                                              : AppTheme
                                                                  .lightBlue
                                                                  .withAlpha(
                                                                    77,
                                                                  ),
                                                      width: isSelected ? 2 : 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    color:
                                                        isSelected
                                                            ? AppTheme
                                                                .warningOrange
                                                                .withAlpha(13)
                                                            : Colors.white,
                                                  ),
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _selectedReport =
                                                            report;
                                                      });
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  12,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  isSelected
                                                                      ? AppTheme
                                                                          .warningOrange
                                                                          .withAlpha(
                                                                            20,
                                                                          )
                                                                      : AppTheme
                                                                          .lightBlue
                                                                          .withAlpha(
                                                                            26,
                                                                          ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .report_outlined,
                                                              color:
                                                                  isSelected
                                                                      ? AppTheme
                                                                          .warningOrange
                                                                      : AppTheme
                                                                          .skyBlue,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  report.title,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        AppTheme
                                                                            .deepBlue,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  'Type: ${report.type}',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color:
                                                                        AppTheme
                                                                            .mediumGray,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  'Approved: ${DateFormat('MMM dd, yyyy').format(report.updatedAt)}',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color:
                                                                        AppTheme
                                                                            .mediumGray,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (isSelected)
                                                            Icon(
                                                              Icons
                                                                  .check_circle,
                                                              color:
                                                                  AppTheme
                                                                      .warningOrange,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),

                                            const SizedBox(height: 32),

                                            const SizedBox(height: 32),

                                            // Select Counselor Section
                                            _buildSectionLabel(
                                              'Select Counselor',
                                            ),
                                            const SizedBox(height: 16),
                                            DropdownButtonFormField<String>(
                                              initialValue:
                                                  _selectedCounselorId,
                                              decoration: InputDecoration(
                                                labelText: 'Choose a Counselor',
                                                prefixIcon: Icon(
                                                  Icons.person_search,
                                                  color: AppTheme.skyBlue,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              items:
                                                  _facilitators
                                                      .map(
                                                        (c) => DropdownMenuItem(
                                                          value: c.id,
                                                          child: Text(
                                                            '${c.fullName} (${c.department ?? "Guidance"})',
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                              onChanged:
                                                  (v) => setState(
                                                    () =>
                                                        _selectedCounselorId =
                                                            v,
                                                  ),
                                              validator:
                                                  (v) =>
                                                      v == null
                                                          ? 'Please select a counselor'
                                                          : null,
                                            ),

                                            const SizedBox(height: 32),

                                            // Preferred Schedule Section
                                            _buildSectionLabel(
                                              'Preferred Schedule (Optional)',
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: _selectDate,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade400,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .calendar_today,
                                                            color:
                                                                AppTheme
                                                                    .deepBlue,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Text(
                                                            _selectedDate ==
                                                                    null
                                                                ? 'Select Date'
                                                                : DateFormat(
                                                                  'MMM dd, yyyy',
                                                                ).format(
                                                                  _selectedDate!,
                                                                ),
                                                            style: TextStyle(
                                                              color:
                                                                  _selectedDate ==
                                                                          null
                                                                      ? Colors
                                                                          .grey
                                                                          .shade600
                                                                      : AppTheme
                                                                          .deepBlue,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: _selectTime,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade400,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.access_time,
                                                            color:
                                                                AppTheme
                                                                    .deepBlue,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Text(
                                                            _selectedTime ==
                                                                    null
                                                                ? 'Select Time'
                                                                : _selectedTime!
                                                                    .format(
                                                                      context,
                                                                    ),
                                                            style: TextStyle(
                                                              color:
                                                                  _selectedTime ==
                                                                          null
                                                                      ? Colors
                                                                          .grey
                                                                          .shade600
                                                                      : AppTheme
                                                                          .deepBlue,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_selectedDate != null ||
                                                _selectedTime != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  'Note: This is just a preference. The counselor will confirm or suggest a new time.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.mediumGray,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),

                                            const SizedBox(height: 32),

                                            // Reason Section
                                            _buildSectionLabel(
                                              'Reason for Counseling',
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: _reasonController,
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Why are you requesting counseling?',
                                                prefixIcon: Container(
                                                  margin: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme
                                                        .warningOrange
                                                        .withAlpha(26),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.help_outline,
                                                    color:
                                                        AppTheme.warningOrange,
                                                    size: 20,
                                                  ),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  borderSide: BorderSide(
                                                    color: AppTheme.lightBlue
                                                        .withAlpha(77),
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: AppTheme
                                                            .lightBlue
                                                            .withAlpha(77),
                                                      ),
                                                    ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  borderSide: const BorderSide(
                                                    color:
                                                        AppTheme.warningOrange,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                              maxLines: 3,
                                              textCapitalization:
                                                  TextCapitalization.sentences,
                                            ),

                                            // Note about scheduling
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: AppTheme.skyBlue
                                                    .withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: AppTheme.skyBlue
                                                      .withAlpha(40),
                                                ),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(
                                                    Icons.info_outline,
                                                    color: AppTheme.skyBlue,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'The exact schedule and location of your counseling session will be set by the counselor after reviewing your request.',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            AppTheme.deepBlue,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(height: 32),

                                            // Participant Selection Section
                                            _buildSectionLabel(
                                              'Choose Participants (Optional)',
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Select who you would like to attend the session with you:',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppTheme.mediumGray,
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            // Facilitators
                                            if (_facilitators.isNotEmpty)
                                              _buildParticipantDropdown(
                                                title:
                                                    'Facilitators (Counselors)',
                                                users: _facilitators,
                                                role: 'facilitator',
                                              ),

                                            // Advisers
                                            if (_advisers.isNotEmpty)
                                              _buildParticipantDropdown(
                                                title: 'Advisers (Teachers)',
                                                users: _advisers,
                                                role: 'adviser',
                                              ),

                                            // Parent/Guardian Option
                                            SwitchListTile(
                                              title: const Text(
                                                'Include Parent/Guardian',
                                              ),
                                              subtitle: const Text(
                                                'If enabled, the Guidance Office will invite your parent/guardian to attend.',
                                              ),
                                              value: _includeParent,
                                              onChanged: (value) {
                                                setState(
                                                  () => _includeParent = value,
                                                );
                                              },
                                              thumbColor:
                                                  WidgetStateProperty.all(
                                                    AppTheme.skyBlue,
                                                  ),
                                            ),

                                            const SizedBox(height: 24),

                                            // Additional Details Section
                                            _buildSectionLabel(
                                              'Additional Details (Optional)',
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: _detailsController,
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Any additional information you would like to share...',
                                                prefixIcon: Container(
                                                  margin: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.mediumBlue
                                                        .withAlpha(26),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.note_outlined,
                                                    color: AppTheme.mediumBlue,
                                                    size: 20,
                                                  ),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  borderSide: BorderSide(
                                                    color: AppTheme.lightBlue
                                                        .withAlpha(77),
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: AppTheme
                                                            .lightBlue
                                                            .withAlpha(77),
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color:
                                                                AppTheme
                                                                    .mediumBlue,
                                                            width: 2,
                                                          ),
                                                    ),
                                              ),
                                              maxLines: 4,
                                              textCapitalization:
                                                  TextCapitalization.sentences,
                                            ),

                                            const SizedBox(height: 32),

                                            // Submit Button
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppTheme.warningOrange,
                                                    AppTheme.warningOrange
                                                        .withAlpha(204),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppTheme
                                                        .warningOrange
                                                        .withAlpha(77),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: ElevatedButton(
                                                onPressed:
                                                    _isSubmitting ||
                                                            _confirmedReports
                                                                .isEmpty
                                                        ? null
                                                        : _submitRequest,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  shadowColor:
                                                      Colors.transparent,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 18,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                ),
                                                child:
                                                    _isSubmitting
                                                        ? const SizedBox(
                                                          height: 20,
                                                          width: 20,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        )
                                                        : const Text(
                                                          'Submit Counseling Request',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).fadeInSlideUp(delay: 100.ms),
                                  ],
                                ),
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

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.warningOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantDropdown({
    required String title,
    required List<UserModel> users,
    required String role,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.lightBlue.withAlpha(77)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
          ),
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isSelected = _selectedParticipants[user.id] == true;
                  return CheckboxListTile(
                    title: Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    value: isSelected,
                    activeColor: AppTheme.skyBlue,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) => _toggleParticipant(user.id, role),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
