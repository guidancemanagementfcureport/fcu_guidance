import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';

class DeanScheduleCounselingPage extends StatefulWidget {
  final ReportModel report;

  const DeanScheduleCounselingPage({super.key, required this.report});

  @override
  State<DeanScheduleCounselingPage> createState() =>
      _DeanScheduleCounselingPageState();
}

class _DeanScheduleCounselingPageState
    extends State<DeanScheduleCounselingPage> {
  final _supabase = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _sessionType; // 'Individual' or 'Group'
  String? _locationMode; // 'In-person' or 'Online'
  String? _selectedCounselorId;
  final Map<String, bool> _selectedParticipants = {}; // userId -> isSelected
  final Map<String, String> _participantRoles = {}; // userId -> role

  List<UserModel> _counselors = [];
  List<UserModel> _teachers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      final allUsers = await _supabase.getAllUsers();
      final counselors =
          allUsers
              .where(
                (u) => u.role == UserRole.counselor && u.status == 'active',
              )
              .toList();
      final teachers =
          allUsers
              .where((u) => u.role == UserRole.teacher && u.status == 'active')
              .toList();

      setState(() {
        _counselors = counselors;
        _teachers = teachers;
      });
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading participants: $e');
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
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

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ToastUtils.showWarning(context, 'Please select a date');
      return;
    }

    if (_selectedTime == null) {
      ToastUtils.showWarning(context, 'Please select a time');
      return;
    }

    if (_sessionType == null) {
      ToastUtils.showWarning(context, 'Please select session type');
      return;
    }

    if (_locationMode == null) {
      ToastUtils.showWarning(context, 'Please select location mode');
      return;
    }

    if (_selectedCounselorId == null) {
      ToastUtils.showWarning(context, 'Please select a counselor');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final deanId = authProvider.currentUser?.id;

      if (deanId == null) {
        throw Exception('Dean not authenticated');
      }

      // Build participants list
      final participants = <Map<String, dynamic>>[];

      // Add counselor (required)
      participants.add({'userId': _selectedCounselorId, 'role': 'counselor'});

      // Add other selected participants
      _selectedParticipants.forEach((userId, isSelected) {
        if (isSelected && userId != _selectedCounselorId) {
          participants.add({
            'userId': userId,
            'role': _participantRoles[userId] ?? 'other',
          });
        }
      });

      await _supabase.scheduleCounselingByDean(
        reportId: widget.report.id,
        deanId: deanId,
        counselorId: _selectedCounselorId!,
        sessionDate: _selectedDate!,
        sessionHour: _selectedTime!.hour,
        sessionMinute: _selectedTime!.minute,
        sessionType: _sessionType!,
        locationMode: _locationMode!,
        participants: participants,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ToastUtils.showError(context, 'Error scheduling counseling: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: Container(decoration: AppTheme.appBarGradientDecoration),
        ),
        shape: AppTheme.appBarShape,
        title: const Text('Schedule Counseling Session'),
      ),
      body: Container(
        decoration: AppTheme.softBlueGradientDecoration,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report Summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Report Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.deepBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.report.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Type: ${widget.report.type}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Session Date
                        const Text(
                          'Session Date *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _selectDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedDate != null
                                ? DateFormat(
                                  'MMMM dd, yyyy',
                                ).format(_selectedDate!)
                                : 'Select Date',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Session Time
                        const Text(
                          'Session Time *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _selectTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            _selectedTime != null
                                ? _selectedTime!.format(context)
                                : 'Select Time',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Session Type
                        const Text(
                          'Session Type *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _sessionType,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Select session type',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Individual',
                              child: Text('Individual'),
                            ),
                            DropdownMenuItem(
                              value: 'Group',
                              child: Text('Group'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _sessionType = value);
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select session type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Location Mode
                        const Text(
                          'Location / Mode *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _locationMode,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Select location mode',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'In-person',
                              child: Text('In-person'),
                            ),
                            DropdownMenuItem(
                              value: 'Online',
                              child: Text('Online'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _locationMode = value);
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select location mode';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Counselor Selection (Required)
                        const Text(
                          'Counselor *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCounselorId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Select counselor',
                          ),
                          items:
                              _counselors.map((counselor) {
                                return DropdownMenuItem(
                                  value: counselor.id,
                                  child: Text(counselor.fullName),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCounselorId = value);
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a counselor';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Additional Participants
                        const Text(
                          'Additional Participants (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select additional participants who will attend the session',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.mediumBlue,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Facilitators (Teachers)
                        if (_teachers.isNotEmpty) ...[
                          const Text(
                            'Facilitators',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mediumBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._teachers.map((teacher) {
                            return CheckboxListTile(
                              title: Text(teacher.fullName),
                              subtitle: Text(teacher.department ?? ''),
                              value: _selectedParticipants[teacher.id] ?? false,
                              onChanged: (value) {
                                _toggleParticipant(teacher.id, 'facilitator');
                              },
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Advisers (can be teachers or counselors)
                        if (_counselors.isNotEmpty) ...[
                          const Text(
                            'Advisers',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mediumBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._counselors
                              .where((c) => c.id != _selectedCounselorId)
                              .map((counselor) {
                                return CheckboxListTile(
                                  title: Text(counselor.fullName),
                                  subtitle: Text(counselor.department ?? ''),
                                  value:
                                      _selectedParticipants[counselor.id] ??
                                      false,
                                  onChanged: (value) {
                                    _toggleParticipant(counselor.id, 'adviser');
                                  },
                                );
                              }),
                        ],

                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed:
                                  _isSaving
                                      ? null
                                      : () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _isSaving ? null : _saveSchedule,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.successGreen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child:
                                  _isSaving
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : const Text('Schedule Session'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
