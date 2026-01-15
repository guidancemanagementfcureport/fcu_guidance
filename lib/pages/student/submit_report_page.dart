import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
// import 'dart:typed_data';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class SubmitReportPage extends StatefulWidget {
  const SubmitReportPage({super.key});

  @override
  State<SubmitReportPage> createState() => _SubmitReportPageState();
}

class _SubmitReportPageState extends State<SubmitReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

  final _supabase = SupabaseService();
  bool _isLoading = false;
  String? _selectedType;
  DateTime? _incidentDate;
  final List<PlatformFile> _selectedFiles = [];
  UserModel? _currentStudent;
  // Teacher selection
  List<UserModel> _teachers = [];
  String? _selectedTeacherId;

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
    _loadStudentInfo();
    _loadTeachers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentInfo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.id;

      if (studentId != null) {
        final student = await _supabase.getUserById(studentId);
        if (mounted) {
          setState(() {
            _currentStudent = student;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading student info: $e');
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final teachers = await _supabase.getActiveTeachers();
      if (mounted) {
        setState(() {
          _teachers = teachers;
        });
      }
    } catch (e) {
      debugPrint('Error loading teachers: $e');
    }
  }

  String _getStudentLevelInfo() {
    if (_currentStudent == null || _currentStudent!.studentLevel == null) {
      return 'Not specified';
    }

    switch (_currentStudent!.studentLevel!) {
      case StudentLevel.juniorHigh:
        final info = <String>[];
        if (_currentStudent!.gradeLevel != null) {
          info.add(_currentStudent!.gradeLevel!);
        }
        if (_currentStudent!.section != null) {
          info.add(_currentStudent!.section!);
        }
        return 'Junior High School${info.isEmpty ? '' : ' - ${info.join(', ')}'}';
      case StudentLevel.seniorHigh:
        final info = <String>[];
        if (_currentStudent!.gradeLevel != null) {
          info.add(_currentStudent!.gradeLevel!);
        }
        if (_currentStudent!.strand != null) {
          info.add(_currentStudent!.strand!);
        }
        return 'Senior High School${info.isEmpty ? '' : ' - ${info.join(', ')}'}';
      case StudentLevel.college:
        final info = <String>[];
        if (_currentStudent!.course != null) {
          info.add(_currentStudent!.course!);
        }
        if (_currentStudent!.yearLevel != null) {
          info.add(_currentStudent!.yearLevel!);
        }
        return 'College${info.isEmpty ? '' : ' - ${info.join(', ')}'}';
    }
  }

  Color _getStudentLevelColor() {
    if (_currentStudent?.studentLevel == null) {
      return AppTheme.mediumGray;
    }
    switch (_currentStudent!.studentLevel!) {
      case StudentLevel.juniorHigh:
        return const Color(0xFF3B82F6); // Blue
      case StudentLevel.seniorHigh:
        return const Color(0xFF10B981); // Green
      case StudentLevel.college:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'doc',
          'docx',
          'mp4',
          'mov',
          'avi',
          'mkv',
        ],
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        if (_selectedFiles.length + result.files.length > 3) {
          if (mounted) {
            ToastUtils.showWarning(
              context,
              'You can only attach up to 3 files.',
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _selectedFiles.addAll(result.files);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error picking file: $e');
      }
    }
  }

  Future<String?> _uploadFiles() async {
    if (_selectedFiles.isEmpty) return null;

    List<String> uploadedUrls = [];

    try {
      for (var file in _selectedFiles) {
        if (file.bytes == null) continue;

        final fileName = file.name;
        final path =
            'reports/${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';

        final url = await _supabase.uploadFile(
          bucket: 'app_assets',
          path: path,
          fileBytes: file.bytes!,
          contentType: _getContentType(fileName),
        );

        if (url != null) uploadedUrls.add(url);
      }

      if (uploadedUrls.isEmpty) return null;
      return uploadedUrls.join(',');
    } catch (e) {
      debugPrint('File upload error: $e');
      return null;
    }
  }

  String _getContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ToastUtils.showWarning(context, 'Please select a report type');
      return;
    }
    if (_selectedTeacherId == null || _selectedTeacherId!.isEmpty) {
      ToastUtils.showWarning(context, 'Please select a teacher');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.id;

      if (studentId == null) {
        ToastUtils.showError(context, 'User not authenticated');
        setState(() => _isLoading = false);
        return;
      }

      // Upload files if selected
      String? attachmentUrl;
      if (_selectedFiles.isNotEmpty) {
        attachmentUrl = await _uploadFiles();
        if (attachmentUrl == null) {
          if (mounted) {
            ToastUtils.showError(context, 'Failed to upload files');
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // Create report
      await _supabase.createReport(
        studentId: studentId,
        title: _titleController.text.trim(),
        type: _selectedType!,
        details: _detailsController.text.trim(),
        attachmentUrl: attachmentUrl,
        incidentDate: _incidentDate,
        teacherId: _selectedTeacherId,
      );

      if (mounted) {
        ToastUtils.showSuccess(context, 'Report submitted successfully');
        context.go('/student/report-status');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error submitting report: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.skyBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.deepBlue,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Bullying':
        return Icons.block_rounded;
      case 'Academic Concern':
        return Icons.school_rounded;
      case 'Personal Issue':
        return Icons.person_outline_rounded;
      case 'Behavioral Issue':
        return Icons.psychology_outlined;
      case 'Safety Concern':
        return Icons.security_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Future<void> _selectIncidentDate() async {
    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null && mounted) {
        setState(() {
          _incidentDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
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
                title: 'Submit Report',
                subtitle: 'Submit an incident report for counselor review',
                icon: Icons.report_problem_rounded,
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
                      constraints: BoxConstraints(
                        maxWidth: 800,
                        minHeight: MediaQuery.of(context).size.height - 200,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Hero Section with Icon
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.skyBlue.withAlpha(26),
                                    AppTheme.mediumBlue.withAlpha(13),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppTheme.skyBlue.withAlpha(38),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.report_problem_rounded,
                                      size: 48,
                                      color: AppTheme.skyBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Submit Incident Report',
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
                                    'Please provide details about the incident you wish to report.',
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
                              shadowColor: AppTheme.skyBlue.withAlpha(26),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(24),
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(24),
                                  ),
                                ),
                                padding: EdgeInsets.all(
                                  MediaQuery.of(context).size.width > 600
                                      ? 32
                                      : 24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),

                                    // Student Information (Read-only)
                                    _buildSectionLabel('Student Information'),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.lightGray.withAlpha(77),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.lightBlue.withAlpha(
                                            77,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.school_rounded,
                                            color: _getStudentLevelColor(),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Student Level',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.mediumGray,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _getStudentLevelInfo(),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: AppTheme.deepBlue,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStudentLevelColor()
                                                  .withAlpha(26),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _currentStudent
                                                      ?.studentLevel
                                                      ?.displayName ??
                                                  'N/A',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _getStudentLevelColor(),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Title
                                    _buildSectionLabel('Report Information'),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _titleController,
                                      decoration: InputDecoration(
                                        labelText: 'Title of Incident',
                                        hintText:
                                            'Brief title describing the incident',
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.skyBlue.withAlpha(
                                              26,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.title_rounded,
                                            color: AppTheme.skyBlue,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppTheme.lightGray.withAlpha(
                                          77,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppTheme.lightBlue.withAlpha(
                                              77,
                                            ),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.skyBlue,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      style: const TextStyle(fontSize: 15),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a title';
                                        }
                                        return null;
                                      },
                                    ).fadeInSlideUp(delay: 100.ms),
                                    const SizedBox(height: 20),

                                    // Report Type
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedType,
                                      decoration: InputDecoration(
                                        labelText: 'Type of Report',
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.skyBlue.withAlpha(
                                              26,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.category_rounded,
                                            color: AppTheme.skyBlue,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppTheme.lightGray.withAlpha(
                                          77,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppTheme.lightBlue.withAlpha(
                                              77,
                                            ),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.skyBlue,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      dropdownColor: Colors.white,
                                      style: const TextStyle(fontSize: 15),
                                      items:
                                          _reportTypes.map((type) {
                                            return DropdownMenuItem(
                                              value: type,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    _getTypeIcon(type),
                                                    size: 20,
                                                    color: AppTheme.mediumGray,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(type),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedType = value);
                                      },
                                      validator: (value) {
                                        if (value == null) {
                                          return 'Please select a report type';
                                        }
                                        return null;
                                      },
                                    ).fadeInSlideUp(delay: 150.ms),
                                    const SizedBox(height: 20),

                                    // Select Teacher
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedTeacherId,
                                      decoration: InputDecoration(
                                        labelText: 'Select Teacher',
                                        helperText:
                                            'Select the teacher you trust or who is most relevant to this concern.',
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.skyBlue.withAlpha(
                                              26,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person_outline,
                                            color: AppTheme.skyBlue,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppTheme.lightGray.withAlpha(
                                          77,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppTheme.lightBlue.withAlpha(
                                              77,
                                            ),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.skyBlue,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                      ),
                                      isExpanded: true,
                                      dropdownColor: Colors.white,
                                      items:
                                          _teachers.map((teacher) {
                                            final subtitleParts = <String>[];
                                            if (teacher.department != null &&
                                                teacher
                                                    .department!
                                                    .isNotEmpty) {
                                              subtitleParts.add(
                                                teacher.department!,
                                              );
                                            }
                                            if (teacher.course != null &&
                                                teacher.course!.isNotEmpty) {
                                              subtitleParts.add(
                                                teacher.course!,
                                              );
                                            }
                                            final subtitle =
                                                subtitleParts.isNotEmpty
                                                    ? ' – ${subtitleParts.join(', ')}'
                                                    : '';
                                            return DropdownMenuItem(
                                              value: teacher.id,
                                              child: Text(
                                                '${teacher.fullName}$subtitle',
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (value) {
                                        setState(
                                          () => _selectedTeacherId = value,
                                        );
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a teacher';
                                        }
                                        return null;
                                      },
                                    ).fadeInSlideUp(delay: 200.ms),
                                    const SizedBox(height: 20),

                                    // Incident Date & Time
                                    InkWell(
                                      onTap: _selectIncidentDate,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.lightGray.withAlpha(
                                            77,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.lightBlue.withAlpha(
                                              77,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppTheme.skyBlue
                                                    .withAlpha(26),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.calendar_today_rounded,
                                                color: AppTheme.skyBlue,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Date & Time of Incident',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme.mediumGray,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _incidentDate != null
                                                        ? '${_incidentDate!.day}/${_incidentDate!.month}/${_incidentDate!.year} ${_incidentDate!.hour}:${_incidentDate!.minute.toString().padLeft(2, '0')}'
                                                        : 'Select date and time',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color:
                                                          _incidentDate != null
                                                              ? AppTheme
                                                                  .darkGray
                                                              : AppTheme
                                                                  .mediumGray,
                                                      fontWeight:
                                                          _incidentDate != null
                                                              ? FontWeight.w500
                                                              : FontWeight
                                                                  .normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 16,
                                              color: AppTheme.mediumGray,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).fadeInSlideUp(delay: 200.ms),
                                    const SizedBox(height: 24),

                                    _buildSectionLabel('Incident Details'),
                                    const SizedBox(height: 16),

                                    // Description
                                    TextFormField(
                                      controller: _detailsController,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Description / Incident Details',
                                        hintText:
                                            'Provide a detailed description of the incident...',
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.only(
                                            top: 8,
                                            bottom: 8,
                                            left: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.skyBlue.withAlpha(
                                              26,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.description_rounded,
                                            color: AppTheme.skyBlue,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppTheme.lightGray.withAlpha(
                                          77,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppTheme.lightBlue.withAlpha(
                                              77,
                                            ),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.skyBlue,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.all(
                                          16,
                                        ),
                                      ),
                                      maxLines: 6,
                                      style: const TextStyle(fontSize: 15),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter incident details';
                                        }
                                        if (value.length < 20) {
                                          return 'Please provide more details (at least 20 characters)';
                                        }
                                        return null;
                                      },
                                    ).fadeInSlideUp(delay: 250.ms),
                                    const SizedBox(height: 24),

                                    _buildSectionLabel('Attachments'),
                                    const SizedBox(height: 16),

                                    // File Attachments List
                                    if (_selectedFiles.isNotEmpty)
                                      Column(
                                        children:
                                            _selectedFiles.asMap().entries.map((
                                              entry,
                                            ) {
                                              final index = entry.key;
                                              final file = entry.value;
                                              return Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      AppTheme.successGreen
                                                          .withAlpha(13),
                                                      AppTheme.successGreen
                                                          .withAlpha(13),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: AppTheme.successGreen
                                                        .withAlpha(77),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme
                                                            .successGreen
                                                            .withAlpha(38),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .attach_file_rounded,
                                                        color:
                                                            AppTheme
                                                                .successGreen,
                                                        size: 24,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            file.name,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  AppTheme
                                                                      .darkGray,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            '${(file.size / 1024).toStringAsFixed(1)} KB',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  AppTheme
                                                                      .mediumGray,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              6,
                                                            ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color: AppTheme
                                                                  .errorRed
                                                                  .withAlpha(
                                                                    26,
                                                                  ),
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                            ),
                                                        child: const Icon(
                                                          Icons.close_rounded,
                                                          size: 18,
                                                          color:
                                                              AppTheme.errorRed,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          _selectedFiles
                                                              .removeAt(index);
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ).fadeInSlideUp(
                                                delay: Duration(
                                                  milliseconds:
                                                      300 + (index * 50),
                                                ),
                                              );
                                            }).toList(),
                                      ),

                                    if (_selectedFiles.length < 3)
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppTheme.mediumBlue
                                                .withAlpha(13),
                                            style: BorderStyle.solid,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _pickFile,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 20,
                                                    horizontal: 16,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .add_circle_outline_rounded,
                                                    color: AppTheme.skyBlue,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    _selectedFiles.isEmpty
                                                        ? 'Attach File (Max 3)'
                                                        : 'Add Another File',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppTheme.skyBlue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ).fadeInSlideUp(delay: 300.ms),
                                    const SizedBox(height: 32),

                                    // Submit Button
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppTheme.skyBlue,
                                            AppTheme.mediumBlue,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.skyBlue.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap:
                                              _isLoading ? null : _submitReport,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 18,
                                            ),
                                            alignment: Alignment.center,
                                            child:
                                                _isLoading
                                                    ? const SizedBox(
                                                      height: 24,
                                                      width: 24,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(Colors.white),
                                                      ),
                                                    )
                                                    : Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        const Icon(
                                                          Icons.send_rounded,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        const Text(
                                                          'Submit Report',
                                                          style: TextStyle(
                                                            fontSize: 17,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ).fadeInSlideUp(delay: 350.ms),
                                  ],
                                ),
                              ),
                            ),
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
}
