import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../../utils/toast_utils.dart';

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _gmailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _courseController = TextEditingController();
  final _gradeLevelController = TextEditingController();
  final _strandController = TextEditingController();
  final _sectionController = TextEditingController();
  final _yearLevelController = TextEditingController();
  final _departmentController = TextEditingController();

  final SupabaseService _supabase = SupabaseService();
  UserRole _selectedRole = UserRole.student;
  StudentLevel? _selectedStudentLevel;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _gmailController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _courseController.dispose();
    _gradeLevelController.dispose();
    _strandController.dispose();
    _sectionController.dispose();
    _yearLevelController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Ensure password is trimmed and has no whitespace
      final password = _passwordController.text.trim();

      // Validate password is not empty
      if (password.isEmpty) {
        ToastUtils.showWarning(context, 'Password cannot be empty');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('Creating user with email: ${_gmailController.text.trim()}');
      debugPrint('Password length: ${password.length}');

      final user = await _supabase.createUser(
        gmail: _gmailController.text.trim(),
        fullName: _fullNameController.text.trim(),
        password: password,
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
      );

      if (user != null && mounted) {
        setState(() => _isLoading = false);
        // Show password in a dialog with verification status
        _showPasswordDialog(password, user.gmail);
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ToastUtils.showError(context, 'Failed to create user');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = 'Error: $e';

        // Provide helpful error messages
        if (e.toString().contains('already registered') ||
            e.toString().contains('already exists')) {
          errorMessage = 'This email address is already registered.';
        } else if (e.toString().contains('email')) {
          errorMessage =
              'Email error: $e\n\nNote: If email confirmation is enabled in Supabase, users must confirm their email before logging in.';
        }

        ToastUtils.showError(context, errorMessage);
      }
    }
  }

  void _showPasswordDialog(String password, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successGreen),
                SizedBox(width: 8),
                Text('User Created Successfully'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User account has been created. Please save this password:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Email: $email',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.skyBlue),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          password,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: password),
                          );
                          if (context.mounted) {
                            ToastUtils.showSuccess(
                              context,
                              'Password copied to clipboard',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '⚠️ This password will not be shown again. Please save it securely.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.warningOrange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.skyBlue,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'If login fails, check Supabase Dashboard → Authentication → Users to verify the user exists and email is confirmed.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.mediumGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close password dialog
                  Navigator.of(context).pop(true); // Close create user dialog
                },
                child: const Text('OK'),
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
                  'Create New User',
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
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    hintText: 'Enter password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
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
                        _courseController.clear();
                        _gradeLevelController.clear();
                        _strandController.clear();
                        _sectionController.clear();
                        _yearLevelController.clear();
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
                      onPressed: _isLoading ? null : _createUser,
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
                              : const Text('Create User'),
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
