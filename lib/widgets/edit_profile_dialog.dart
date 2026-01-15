import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';

class EditProfileDialog extends StatefulWidget {
  final UserModel user;

  const EditProfileDialog({super.key, required this.user});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _departmentController;
  late TextEditingController _courseController;
  late TextEditingController _gradeLevelController;
  late TextEditingController _strandController;
  late TextEditingController _sectionController;
  late TextEditingController _yearLevelController;
  StudentLevel? _selectedStudentLevel;
  bool _isLoading = false;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _departmentController = TextEditingController(
      text: widget.user.department ?? '',
    );
    _courseController = TextEditingController(text: widget.user.course ?? '');
    _gradeLevelController = TextEditingController(
      text: widget.user.gradeLevel ?? '',
    );
    _strandController = TextEditingController(text: widget.user.strand ?? '');
    _sectionController = TextEditingController(text: widget.user.section ?? '');
    _yearLevelController = TextEditingController(
      text: widget.user.yearLevel ?? '',
    );
    _selectedStudentLevel = widget.user.studentLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _courseController.dispose();
    _gradeLevelController.dispose();
    _strandController.dispose();
    _sectionController.dispose();
    _yearLevelController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _pickedImageBytes = result.files.first.bytes;
        _pickedImageExtension = result.files.first.extension;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      String? avatarUrl;
      if (_pickedImageBytes != null && _pickedImageExtension != null) {
        avatarUrl = await authProvider.uploadAvatar(
          _pickedImageBytes!,
          _pickedImageExtension!,
        );
      }

      final error = await authProvider.updateProfile(
        fullName: _nameController.text.trim(),
        department:
            widget.user.role != UserRole.student
                ? _departmentController.text.trim()
                : null,
        studentLevel:
            widget.user.role == UserRole.student ? _selectedStudentLevel : null,
        course:
            widget.user.role == UserRole.student
                ? _courseController.text.trim()
                : null,
        gradeLevel:
            widget.user.role == UserRole.student
                ? _gradeLevelController.text.trim()
                : null,
        strand:
            widget.user.role == UserRole.student
                ? _strandController.text.trim()
                : null,
        section:
            widget.user.role == UserRole.student
                ? _selectedStudentLevel == StudentLevel.juniorHigh
                    ? _sectionController.text.trim()
                    : null
                : null,
        yearLevel:
            widget.user.role == UserRole.student &&
                    _selectedStudentLevel == StudentLevel.college
                ? _yearLevelController.text.trim()
                : null,
        avatarUrl: avatarUrl,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (error == null) {
          ToastUtils.showSuccess(context, 'Profile updated successfully');
          Navigator.of(context).pop();
        } else {
          ToastUtils.showError(context, error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError(context, 'An unexpected error occurred: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.user.role == UserRole.student;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.deepBlue, AppTheme.infoBlue],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Update Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildAvatarPicker(),
                      const SizedBox(height: 32),
                      _buildModernField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_rounded,
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Name is required'
                                    : null,
                      ),
                      if (!isStudent)
                        _buildModernField(
                          controller: _departmentController,
                          label: 'Office / Department',
                          icon: Icons.business_center_rounded,
                        ),
                      if (isStudent) ...[
                        _buildDropdownField(),
                        _buildModernField(
                          controller: _courseController,
                          label: 'Course / Track',
                          icon: Icons.school_rounded,
                        ),
                        _buildModernField(
                          controller: _gradeLevelController,
                          label: 'Grade Level',
                          icon: Icons.grade_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Discard'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.deepBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Save Profile'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.skyBlue.withValues(alpha: 0.3),
                width: 3,
              ),
              image:
                  _pickedImageBytes != null
                      ? DecorationImage(
                        image: MemoryImage(_pickedImageBytes!),
                        fit: BoxFit.cover,
                      )
                      : widget.user.avatarUrl != null
                      ? DecorationImage(
                        image: NetworkImage(widget.user.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                _pickedImageBytes == null && widget.user.avatarUrl == null
                    ? Container(
                      decoration: BoxDecoration(
                        color: AppTheme.skyBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: AppTheme.skyBlue,
                      ),
                    )
                    : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.deepBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.mediumGray, fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: AppTheme.skyBlue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.lightGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.skyBlue, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<StudentLevel>(
        initialValue: _selectedStudentLevel,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.deepBlue,
        ),
        decoration: InputDecoration(
          labelText: 'Education Level',
          labelStyle: const TextStyle(color: AppTheme.mediumGray, fontSize: 13),
          prefixIcon: const Icon(
            Icons.school_rounded,
            size: 20,
            color: AppTheme.skyBlue,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.lightGray),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        items:
            StudentLevel.values.map((level) {
              return DropdownMenuItem(
                value: level,
                child: Text(level.displayName),
              );
            }).toList(),
        onChanged: (value) => setState(() => _selectedStudentLevel = value),
      ),
    );
  }
}
