import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/anonymous_chat_provider.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/sticky_navigation_bar.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';

class AnonymousReportFormPage extends StatefulWidget {
  const AnonymousReportFormPage({super.key});

  @override
  State<AnonymousReportFormPage> createState() =>
      _AnonymousReportFormPageState();
}

class _AnonymousReportFormPageState extends State<AnonymousReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _supabase = SupabaseService();

  String? _selectedType;
  bool _isLoading = false;
  List<UserModel> _teachers = [];
  final List<String> _selectedTeacherIds = [];
  String _searchQuery = '';
  bool _isTeacherListExpanded = false;

  final List<String> _reportTypes = [
    'Bullying',
    'Academic Concern',
    'Personal Issue',
    'Behavioral Issue',
    'Safety Concern',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipients() async {
    try {
      final teachers = await _supabase.getActiveTeachers();
      final counselors = await _supabase.getActiveCounselors();
      if (mounted) {
        setState(() {
          _teachers = [...teachers, ...counselors];
        });
      }
    } catch (e) {
      debugPrint('Error loading recipients: $e');
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ToastUtils.showWarning(context, 'Please select a report type');
      return;
    }
    if (_selectedTeacherIds.isEmpty) {
      ToastUtils.showWarning(context, 'Please select at least one teacher');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _supabase.createAnonymousReport(
        category: _selectedType!,
        description: _detailsController.text.trim(),
        teacherIds: _selectedTeacherIds,
        status: 'pending',
      );

      if (result != null &&
          result['case_code'] != null &&
          result['id'] != null &&
          mounted) {
        final caseCode = result['case_code'] as String;
        final reportId = result['id'].toString();

        // Set the chat details in the provider
        Provider.of<AnonymousChatProvider>(
          context,
          listen: false,
        ).setChat(caseCode, reportId);

        // Navigate back to home page, where the chatbox will open
        Navigator.of(context).pop();

        if (mounted) {
          _showSuccessDialog(caseCode);
        }
      } else {
        throw Exception('Failed to get case code from response.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastUtils.showError(
          context,
          'Error submitting report: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  void _showSuccessDialog(String caseCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Report Submitted Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please save your case code to continue the conversation later:',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray.withAlpha(77),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        caseCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: caseCode));
                          ToastUtils.showSuccess(
                            context,
                            'Case code copied to clipboard!',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: StickyNavigationBar(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 32,
              vertical: 32,
            ),
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Section with Gradient Background
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.skyBlue.withAlpha(26),
                          AppTheme.paleBlue.withAlpha(13),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.skyBlue.withAlpha(51),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        const Text(
                          'Submit an Anonymous Report',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Subtitle
                        const Text(
                          'Your identity will remain confidential. No login required.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.darkGray,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Reassurance Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.successGreen.withAlpha(77),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                color: AppTheme.successGreen,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '100% Anonymous & Secure',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Form Container Card
                  Container(
                    padding: EdgeInsets.all(isMobile ? 24 : 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.deepBlue.withAlpha(20),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Report Type
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'Report Type *',
                            hintText: null, // Remove string hint
                            prefixIcon: const Icon(
                              Icons.category_outlined,
                              color: AppTheme.mediumGray,
                            ),
                            filled: true,
                            fillColor: AppTheme.lightGray.withAlpha(77),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          hint: const Text(
                            'Select the category that best describes your concern',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14),
                          ),
                          items:
                              _reportTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedType = value);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a report type';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Teacher Selection - Expandable Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Teacher(s) *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGray,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isTeacherListExpanded =
                                      !_isTeacherListExpanded;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        _isTeacherListExpanded
                                            ? AppTheme.skyBlue
                                            : AppTheme.mediumGray.withAlpha(51),
                                    width: _isTeacherListExpanded ? 2 : 1,
                                  ),
                                  boxShadow:
                                      _isTeacherListExpanded
                                          ? [
                                            BoxShadow(
                                              color: AppTheme.skyBlue.withAlpha(
                                                30,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                          : [],
                                ),
                                child: Column(
                                  children: [
                                    // Dropdown Header
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person_search_rounded,
                                            size: 20,
                                            color:
                                                _isTeacherListExpanded
                                                    ? AppTheme.skyBlue
                                                    : AppTheme.mediumGray,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _selectedTeacherIds.isEmpty
                                                  ? 'Choose recipients to notify...'
                                                  : '${_selectedTeacherIds.length} Selected',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color:
                                                    _selectedTeacherIds.isEmpty
                                                        ? AppTheme.mediumGray
                                                        : AppTheme.deepBlue,
                                                fontWeight:
                                                    _selectedTeacherIds.isEmpty
                                                        ? FontWeight.normal
                                                        : FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          AnimatedRotation(
                                            turns:
                                                _isTeacherListExpanded
                                                    ? 0.5
                                                    : 0,
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            child: const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: AppTheme.mediumGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Expandable Content
                                    if (_isTeacherListExpanded) ...[
                                      const Divider(height: 1),
                                      // Search Bar
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          12,
                                          12,
                                          8,
                                        ),
                                        child: TextField(
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search by faculty name...',
                                            hintStyle: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              size: 18,
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: AppTheme.lightGray
                                                .withAlpha(100),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          onChanged: (query) {
                                            setState(() {
                                              _searchQuery =
                                                  query.toLowerCase();
                                            });
                                          },
                                        ),
                                      ),
                                      // Scrollable List
                                      SizedBox(
                                        height: 200,
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          itemCount:
                                              _teachers
                                                  .where(
                                                    (t) => t.fullName
                                                        .toLowerCase()
                                                        .contains(_searchQuery),
                                                  )
                                                  .length,
                                          itemBuilder: (context, index) {
                                            final filtered =
                                                _teachers
                                                    .where(
                                                      (t) => t.fullName
                                                          .toLowerCase()
                                                          .contains(
                                                            _searchQuery,
                                                          ),
                                                    )
                                                    .toList();
                                            final teacher = filtered[index];
                                            final isSelected =
                                                _selectedTeacherIds.contains(
                                                  teacher.id,
                                                );

                                            return InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (isSelected) {
                                                    _selectedTeacherIds.remove(
                                                      teacher.id,
                                                    );
                                                  } else {
                                                    _selectedTeacherIds.add(
                                                      teacher.id,
                                                    );
                                                  }
                                                });
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 200,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            isSelected
                                                                ? AppTheme
                                                                    .skyBlue
                                                                : Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              isSelected
                                                                  ? AppTheme
                                                                      .skyBlue
                                                                  : AppTheme
                                                                      .mediumGray
                                                                      .withAlpha(
                                                                        100,
                                                                      ),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons.check,
                                                        size: 14,
                                                        color:
                                                            isSelected
                                                                ? Colors.white
                                                                : Colors
                                                                    .transparent,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            teacher.fullName,
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              color:
                                                                  isSelected
                                                                      ? AppTheme
                                                                          .deepBlue
                                                                      : AppTheme
                                                                          .darkGray,
                                                              fontWeight:
                                                                  isSelected
                                                                      ? FontWeight
                                                                          .bold
                                                                      : FontWeight
                                                                          .normal,
                                                            ),
                                                          ),
                                                          Text(
                                                            teacher.role ==
                                                                    UserRole
                                                                        .teacher
                                                                ? 'Faculty Member'
                                                                : 'Guidance Counselor',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  teacher.role ==
                                                                          UserRole
                                                                              .teacher
                                                                      ? AppTheme
                                                                          .mediumGray
                                                                      : AppTheme
                                                                          .skyBlue,
                                                              fontWeight:
                                                                  teacher.role ==
                                                                          UserRole
                                                                              .teacher
                                                                      ? FontWeight
                                                                          .normal
                                                                      : FontWeight
                                                                          .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      const Icon(
                                                        Icons.check_circle,
                                                        color: AppTheme.skyBlue,
                                                        size: 18,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Report Details
                        TextFormField(
                          controller: _detailsController,
                          decoration: InputDecoration(
                            labelText: 'Report Details *',
                            hintText:
                                'Describe what happened, when it occurred, and who was involved (if known)',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 120),
                              child: Icon(
                                Icons.description_outlined,
                                color: AppTheme.mediumGray,
                              ),
                            ),
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: AppTheme.lightGray.withAlpha(77),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                          maxLines: 8,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter details';
                            }
                            if (value.length < 20) {
                              return 'Please provide more details (at least 20 characters)';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Privacy Reminder
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.paleBlue.withAlpha(128),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.skyBlue.withAlpha(51),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.skyBlue,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Do not include your name or personal details if you wish to stay anonymous.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.darkGray,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Submit Button with Gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.skyBlue, AppTheme.mediumBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.skyBlue.withAlpha(102),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child:
                                _isLoading
                                    ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Submitting…',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                    : const Text(
                                      'Submit Report',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
