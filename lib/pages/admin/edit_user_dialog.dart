import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../../utils/toast_utils.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class EditUserDialog extends StatefulWidget {
  final UserModel user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _gmailController;
  late TextEditingController _fullNameController;
  late TextEditingController _courseController;
  late TextEditingController _gradeLevelController;
  late TextEditingController _strandController;
  late TextEditingController _sectionController;
  late TextEditingController _yearLevelController;
  late TextEditingController _departmentController;

  final SupabaseService _supabase = SupabaseService();
  late UserRole _selectedRole;
  late StudentLevel? _selectedStudentLevel;
  late String _selectedStatus;
  bool _isLoading = false;

  // Password fields (Admin only)
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _gmailController = TextEditingController(text: widget.user.gmail);
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _courseController = TextEditingController(text: widget.user.course ?? '');
    _gradeLevelController = TextEditingController(
      text: widget.user.gradeLevel ?? '',
    );
    _strandController = TextEditingController(text: widget.user.strand ?? '');
    _sectionController = TextEditingController(text: widget.user.section ?? '');
    _yearLevelController = TextEditingController(
      text: widget.user.yearLevel ?? '',
    );
    _departmentController = TextEditingController(
      text: widget.user.department ?? '',
    );
    _selectedRole = widget.user.role;
    _selectedStudentLevel = widget.user.studentLevel;
    _selectedStatus = widget.user.status;
  }

  @override
  void dispose() {
    _gmailController.dispose();
    _fullNameController.dispose();
    _courseController.dispose();
    _gradeLevelController.dispose();
    _strandController.dispose();
    _sectionController.dispose();
    _yearLevelController.dispose();
    _departmentController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Check if password is being changed
      final newPassword = _newPasswordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();
      final isChangingPassword =
          newPassword.isNotEmpty || confirmPassword.isNotEmpty;

      // If password fields are filled, validate and update password
      if (isChangingPassword) {
        if (newPassword.isEmpty) {
          setState(() => _isLoading = false);
          ToastUtils.showError(context, 'Please enter a new password');
          return;
        }
        if (newPassword != confirmPassword) {
          setState(() => _isLoading = false);
          ToastUtils.showError(context, 'Passwords do not match');
          return;
        }
        if (newPassword.length < 6) {
          setState(() => _isLoading = false);
          ToastUtils.showError(
            context,
            'Password must be at least 6 characters',
          );
          return;
        }

        // Update password
        try {
          final passwordUpdated = await _supabase.updateUserPassword(
            userId: widget.user.id,
            newPassword: newPassword,
          );
          if (!passwordUpdated) {
            setState(() => _isLoading = false);
            if (mounted) {
              ToastUtils.showError(context, 'Failed to update password');
            }
            return;
          }
        } catch (e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ToastUtils.showError(context, 'Error updating password: $e');
          }
          return;
        }
      }

      // Update user information
      final user = await _supabase.updateUser(
        userId: widget.user.id,
        gmail: _gmailController.text.trim(),
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        studentLevel: _selectedStudentLevel,
        course:
            _courseController.text.trim().isEmpty
                ? null
                : _courseController.text.trim(),
        gradeLevel:
            _gradeLevelController.text.trim().isEmpty
                ? null
                : _gradeLevelController.text.trim(),
        strand:
            _strandController.text.trim().isEmpty
                ? null
                : _strandController.text.trim(),
        section:
            _sectionController.text.trim().isEmpty
                ? null
                : _sectionController.text.trim(),
        yearLevel:
            _yearLevelController.text.trim().isEmpty
                ? null
                : _yearLevelController.text.trim(),
        department:
            _departmentController.text.trim().isEmpty
                ? null
                : _departmentController.text.trim(),
        status: _selectedStatus,
      );

      if (user != null && mounted) {
        if (isChangingPassword) {
          // Show password success dialog
          await _showPasswordSuccessDialog(
            context,
            _newPasswordController.text.trim(),
          );
          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          ToastUtils.showSuccess(context, 'User updated successfully');
          Navigator.pop(context, true);
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastUtils.showError(context, 'Failed to update user');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastUtils.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _showPasswordSuccessDialog(
    BuildContext context,
    String password,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: AppTheme.successGreen),
                SizedBox(width: 8),
                Text('Password Changed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The password has been updated successfully.',
                  style: TextStyle(color: AppTheme.darkGray),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please copy or take a photo of the new password for the user:',
                  style: TextStyle(color: AppTheme.mediumGray, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: SelectableText(
                    password,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: password));
                  ToastUtils.showSuccess(
                    context,
                    'Password copied to clipboard',
                  );
                },
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit User',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                // Email
                TextFormField(
                  controller: _gmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'student001@gmail.com',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    // Validate email format (any email provider)
                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Role
                DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role *',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items:
                      UserRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role.displayName),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedRole = value!);
                  },
                ),
                const SizedBox(height: 16),
                // Status
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status *',
                    prefixIcon: Icon(Icons.toggle_on),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedStatus = value!);
                  },
                ),
                const SizedBox(height: 16),
                // Student Level (for students)
                if (_selectedRole == UserRole.student) ...[
                  DropdownButtonFormField<StudentLevel>(
                    initialValue: _selectedStudentLevel,
                    decoration: const InputDecoration(
                      labelText: 'Student Level *',
                      prefixIcon: Icon(Icons.school),
                    ),
                    items:
                        StudentLevel.values.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(level.displayName),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStudentLevel = value;
                        // Clear fields when level changes
                        if (value != StudentLevel.juniorHigh) {
                          _sectionController.clear();
                        }
                        if (value != StudentLevel.seniorHigh) {
                          _strandController.clear();
                        }
                        if (value != StudentLevel.college) {
                          _courseController.clear();
                          _yearLevelController.clear();
                        }
                      });
                    },
                    validator: (value) {
                      if (_selectedRole == UserRole.student && value == null) {
                        return 'Student level is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Junior High School Fields
                  if (_selectedStudentLevel == StudentLevel.juniorHigh) ...[
                    DropdownButtonFormField<String>(
                      initialValue:
                          _gradeLevelController.text.isEmpty
                              ? null
                              : _gradeLevelController.text,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level *',
                        prefixIcon: Icon(Icons.grade),
                      ),
                      items:
                          ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'].map((
                            grade,
                          ) {
                            return DropdownMenuItem(
                              value: grade,
                              child: Text(grade),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _gradeLevelController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (_selectedStudentLevel == StudentLevel.juniorHigh &&
                            (value == null || value.isEmpty)) {
                          return 'Grade level is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sectionController,
                      decoration: const InputDecoration(
                        labelText: 'Section (Optional)',
                        prefixIcon: Icon(Icons.group),
                        hintText: 'e.g., Section A',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Senior High School Fields
                  if (_selectedStudentLevel == StudentLevel.seniorHigh) ...[
                    DropdownButtonFormField<String>(
                      initialValue:
                          _gradeLevelController.text.isEmpty
                              ? null
                              : _gradeLevelController.text,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level *',
                        prefixIcon: Icon(Icons.grade),
                      ),
                      items:
                          ['Grade 11', 'Grade 12'].map((grade) {
                            return DropdownMenuItem(
                              value: grade,
                              child: Text(grade),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _gradeLevelController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (_selectedStudentLevel == StudentLevel.seniorHigh &&
                            (value == null || value.isEmpty)) {
                          return 'Grade level is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _strandController.text.isEmpty
                              ? null
                              : _strandController.text,
                      decoration: const InputDecoration(
                        labelText: 'Strand *',
                        prefixIcon: Icon(Icons.book),
                      ),
                      items:
                          ['STEM', 'HUMSS', 'ABM', 'GAS', 'TVL'].map((strand) {
                            return DropdownMenuItem(
                              value: strand,
                              child: Text(strand),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _strandController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (_selectedStudentLevel == StudentLevel.seniorHigh &&
                            (value == null || value.isEmpty)) {
                          return 'Strand is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  // College Fields
                  if (_selectedStudentLevel == StudentLevel.college) ...[
                    TextFormField(
                      controller: _courseController,
                      decoration: const InputDecoration(
                        labelText: 'Course / Program *',
                        prefixIcon: Icon(Icons.school),
                        hintText: 'e.g., Computer Science',
                      ),
                      validator: (value) {
                        if (_selectedStudentLevel == StudentLevel.college &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Course/Program is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _yearLevelController.text.isEmpty
                              ? null
                              : _yearLevelController.text,
                      decoration: const InputDecoration(
                        labelText: 'Year Level *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      items:
                          ['1st Year', '2nd Year', '3rd Year', '4th Year'].map((
                            year,
                          ) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _yearLevelController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (_selectedStudentLevel == StudentLevel.college &&
                            (value == null || value.isEmpty)) {
                          return 'Year level is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                // Department (for non-students: teacher, counselor, dean, admin)
                if (_selectedRole != UserRole.student) ...[
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department *',
                      hintText: 'Academic/Administrative unit',
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) {
                      if (_selectedRole == UserRole.dean &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Department is required for Dean role';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Security Section - Change Password (Admin Only)
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final currentUser = authProvider.currentUser;
                    final isAdmin = currentUser?.role == UserRole.admin;

                    if (!isAdmin) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        // Section Divider
                        Divider(thickness: 1, color: AppTheme.lightGray),
                        const SizedBox(height: 16),
                        // Section Header
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: AppTheme.skyBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Security - Change Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGray,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Admin can reset user password. Leave blank to keep current password.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumGray,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // New Password
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            hintText: 'Enter new password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            // Only validate if password is being changed
                            final confirmPassword =
                                _confirmPasswordController.text.trim();
                            if (confirmPassword.isNotEmpty &&
                                (value == null || value.isEmpty)) {
                              return 'Please enter a new password';
                            }
                            if (value != null &&
                                value.isNotEmpty &&
                                value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            hintText: 'Re-enter new password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            // Only validate if password is being changed
                            final newPassword =
                                _newPasswordController.text.trim();
                            if (newPassword.isNotEmpty) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm the new password';
                              }
                              if (value != newPassword) {
                                return 'Passwords do not match';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateUser,
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text('Update User'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
