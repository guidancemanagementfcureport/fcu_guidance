import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/modern_dashboard_header.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../../utils/animations.dart';
import 'create_user_dialog.dart';
import 'edit_user_dialog.dart';
import 'user_profile_dialog.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final SupabaseService _supabase = SupabaseService();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  UserRole? _selectedRole;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _supabase.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastUtils.showError(context, 'Error loading users: $e');
      }
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers =
          _users.where((user) {
            final matchesSearch =
                _searchQuery.isEmpty ||
                user.fullName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                user.gmail.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesRole =
                _selectedRole == null || user.role == _selectedRole;
            final matchesStatus =
                _selectedStatus == null || user.status == _selectedStatus;
            return matchesSearch && matchesRole && matchesStatus;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isWeb = MediaQuery.of(context).size.width >= 768;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              ModernDashboardHeader(
                title: 'User Management',
                subtitle: 'Manage all accounts, roles, and access credentials',
                icon: Icons.people_rounded,
                actions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.white.withValues(alpha: 0.2),
                      foregroundColor: AppTheme.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.white.withValues(alpha: 0.3)),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Create User',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _showCreateUserDialog,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Refresh',
                      onPressed: _loadUsers,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          // Search and Filters
                          _buildSearchAndFilters(),
                          // User List
                          Expanded(
                            child: isWeb ? _buildWebUserTable() : _buildMobileUserList(),
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

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.white,
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filterUsers();
                          });
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filterUsers();
              });
            },
          ),
          const SizedBox(height: 12),
          // Filter Chips
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    // Role Filter
                    FilterChip(
                      label: const Text('All Roles'),
                      selected: _selectedRole == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedRole = null;
                          _filterUsers();
                        });
                      },
                    ),
                    ...UserRole.values.map(
                      (role) => FilterChip(
                        label: Text(role.displayName),
                        selected: _selectedRole == role,
                        onSelected: (selected) {
                          setState(() {
                            _selectedRole = selected ? role : null;
                            _filterUsers();
                          });
                        },
                      ),
                    ),
                    // Status Filter
                    FilterChip(
                      label: const Text('All Status'),
                      selected: _selectedStatus == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = null;
                          _filterUsers();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Active'),
                      selected: _selectedStatus == 'active',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = selected ? 'active' : null;
                          _filterUsers();
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('Inactive'),
                      selected: _selectedStatus == 'inactive',
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = selected ? 'inactive' : null;
                          _filterUsers();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebUserTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGray.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Full Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Course/Dept')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('Last Login')),
            DataColumn(label: Text('Actions')),
          ],
          rows:
              _filteredUsers.map((user) {
                return DataRow(
                  cells: [
                    DataCell(Text(user.fullName)),
                    DataCell(Text(user.gmail)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(
                            user.role,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.role.displayName,
                          style: TextStyle(
                            color: _getRoleColor(user.role),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        user.role == UserRole.student
                            ? _getStudentInfo(user)
                            : (user.department ?? '-'),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              user.isActive
                                  ? AppTheme.successGreen.withValues(alpha: 0.1)
                                  : AppTheme.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.status,
                          style: TextStyle(
                            color:
                                user.isActive
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(_formatDate(user.createdAt))),
                    DataCell(
                      Text(
                        user.lastLogin != null
                            ? _formatDate(user.lastLogin!)
                            : 'Never',
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 20),
                            color: AppTheme.skyBlue,
                            onPressed: () => _showUserProfile(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: AppTheme.warningOrange,
                            onPressed: () => _showEditUserDialog(user),
                          ),
                          IconButton(
                            icon: Icon(
                              user.isActive ? Icons.block : Icons.check_circle,
                              size: 20,
                            ),
                            color:
                                user.isActive
                                    ? AppTheme.errorRed
                                    : AppTheme.successGreen,
                            onPressed: () => _toggleUserStatus(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            color: AppTheme.errorRed,
                            onPressed: () => _showDeleteDialog(user),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileUserList() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppTheme.mediumGray),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(color: AppTheme.mediumGray, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user).fadeInSlideUp(delay: (index * 50).ms);
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.fullName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.gmail, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.role.displayName,
                    style: TextStyle(
                      color: _getRoleColor(user.role),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        user.isActive
                            ? AppTheme.successGreen.withValues(alpha: 0.1)
                            : AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.status,
                    style: TextStyle(
                      color:
                          user.isActive
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 20),
                      SizedBox(width: 8),
                      Text('View Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        user.isActive ? Icons.block : Icons.check_circle,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(user.isActive ? 'Disable' : 'Enable'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: AppTheme.errorRed),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(color: AppTheme.errorRed),
                      ),
                    ],
                  ),
                ),
              ],
          onSelected: (value) {
            switch (value) {
              case 'view':
                _showUserProfile(user);
                break;
              case 'edit':
                _showEditUserDialog(user);
                break;
              case 'toggle':
                _toggleUserStatus(user);
                break;
              case 'delete':
                _showDeleteDialog(user);
                break;
            }
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Course/Department',
                  user.role == UserRole.student
                      ? _getStudentInfo(user)
                      : (user.department ?? '-'),
                ),
                _buildDetailRow('Created', _formatDate(user.createdAt)),
                _buildDetailRow(
                  'Last Login',
                  user.lastLogin != null
                      ? _formatDate(user.lastLogin!)
                      : 'Never',
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showUserProfile(user),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.skyBlue,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showEditUserDialog(user),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warningOrange,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _toggleUserStatus(user),
                      icon: Icon(
                        user.isActive ? Icons.block : Icons.check_circle,
                        size: 16,
                      ),
                      label: Text(user.isActive ? 'Disable' : 'Enable'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            user.isActive
                                ? AppTheme.errorRed
                                : AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.mediumGray,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return AppTheme.skyBlue;
      case UserRole.teacher:
        return AppTheme.successGreen;
      case UserRole.counselor:
        return AppTheme.warningOrange;
      case UserRole.dean:
        return const Color(0xFF4C1D95); // Deep indigo
      case UserRole.admin:
        return AppTheme.errorRed;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getStudentInfo(UserModel user) {
    if (user.studentLevel == null) {
      // Legacy data - show course or grade level if available
      return user.course ?? user.gradeLevel ?? '-';
    }

    switch (user.studentLevel!) {
      case StudentLevel.juniorHigh:
        final info = <String>[];
        if (user.gradeLevel != null) info.add(user.gradeLevel!);
        if (user.section != null) info.add(user.section!);
        return info.isEmpty ? 'JHS' : info.join(' - ');
      case StudentLevel.seniorHigh:
        final info = <String>[];
        if (user.gradeLevel != null) info.add(user.gradeLevel!);
        if (user.strand != null) info.add(user.strand!);
        return info.isEmpty ? 'SHS' : info.join(' - ');
      case StudentLevel.college:
        final info = <String>[];
        if (user.course != null) info.add(user.course!);
        if (user.yearLevel != null) info.add(user.yearLevel!);
        return info.isEmpty ? 'College' : info.join(' - ');
    }
  }

  Future<void> _showCreateUserDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateUserDialog(),
    );
    if (result == true) {
      await _loadUsers();
      if (mounted) {
        ToastUtils.showSuccess(context, 'User created successfully');
      }
    }
  }

  Future<void> _showEditUserDialog(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    );
    if (result == true) {
      await _loadUsers();
      if (mounted) {
        ToastUtils.showSuccess(context, 'User updated successfully');
      }
    }
  }

  Future<void> _showUserProfile(UserModel user) async {
    await showDialog(
      context: context,
      builder: (context) => UserProfileDialog(user: user),
    );
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    final action = user.isActive ? 'disable' : 'enable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text('$action User Account'),
            content: Text('Are you sure you want to $action ${user.fullName}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                ),
                child: Text(action.toUpperCase()),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final success =
            user.isActive
                ? await _supabase.disableUser(user.id)
                : await _supabase.enableUser(user.id);
        if (success) {
          await _loadUsers();
          if (mounted) {
            ToastUtils.showSuccess(context, 'User ${action}d successfully');
          }
        } else {
          if (mounted) {
            ToastUtils.showError(context, 'Failed to $action user');
          }
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showError(context, 'Error: $e');
        }
      }
    }
  }

  Future<void> _showDeleteDialog(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('Delete User Account'),
            content: Text(
              'Are you sure you want to permanently delete ${user.fullName}? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                ),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final success = await _supabase.deleteUser(user.id);
        if (success) {
          await _loadUsers();
          if (mounted) {
            ToastUtils.showSuccess(context, 'User deleted successfully');
          }
        } else {
          if (mounted) {
            ToastUtils.showError(context, 'Failed to delete user');
          }
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showError(context, 'Error: $e');
        }
      }
    }
  }
}
