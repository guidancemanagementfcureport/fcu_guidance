import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/report_model.dart';
import '../models/report_activity_log_model.dart';
import '../models/counseling_request_model.dart';
import '../models/counseling_activity_log_model.dart';
import '../models/notification_model.dart';
import '../models/resource_model.dart';
import '../models/case_message_model.dart';
import '../models/user_activity_log_model.dart';
import '../models/support_chat_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _client;
  bool _initialized = false;
  bool _isCreatingUser =
      false; // Flag to prevent auth state listener from processing during user creation

  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    if (!_initialized) {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _client = Supabase.instance.client;
      _initialized = true;
    }
  }

  SupabaseClient get client => _client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;

  // ============================================
  // AUTHENTICATION
  // ============================================

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.fcuguidance://login-callback',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      debugPrint(
        'Attempting sign in with email: ${email.toLowerCase().trim()}',
      );
      final response = await _client.auth.signInWithPassword(
        email: email.toLowerCase().trim(),
        password: password,
      );

      if (response.user != null) {
        debugPrint('Sign in successful for user: ${response.user!.id}');
        debugPrint(
          'Email confirmed: ${response.user!.emailConfirmedAt != null}',
        );
      }

      return response.user;
    } catch (e) {
      // Log the error for debugging
      debugPrint('Sign in error: $e');
      debugPrint('Email used: ${email.toLowerCase().trim()}');

      // Check if user exists in auth.users
      // Note: We can't directly query auth.users from client, but we can provide helpful error
      if (e.toString().contains('Invalid login credentials') ||
          e.toString().contains('invalid_credentials')) {
        debugPrint(
          'Possible causes: '
          '1. User does not exist in auth.users '
          '2. Password is incorrect '
          '3. Email confirmation required but not confirmed',
        );
      }

      rethrow;
    }
  }

  /// Send magic link to email
  Future<bool> sendMagicLink(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'io.supabase.fcuguidance://login-callback',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if email exists in users table
  Future<bool> checkEmailExists(String email) async {
    try {
      final response =
          await _client
              .from('users')
              .select('id')
              .eq('gmail', email.toLowerCase())
              .eq('status', 'active')
              .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if email exists in users table
  Future<bool> checkGmailExists(String gmail) async {
    try {
      final response =
          await _client
              .from('users')
              .select('id')
              .eq('gmail', gmail.toLowerCase())
              .eq('status', 'active')
              .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get user by email
  Future<UserModel?> getUserByGmail(String gmail) async {
    try {
      final response =
          await _client
              .from('users')
              .select()
              .eq('gmail', gmail.toLowerCase())
              .eq('status', 'active')
              .maybeSingle();
      if (response != null) {
        return UserModel.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update last login timestamp
  Future<void> updateLastLogin(String userId) async {
    try {
      await _client
          .from('users')
          .update({'last_login': DateTime.now().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ============================================
  // USER MANAGEMENT
  // ============================================

  Future<UserModel?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final response =
          await _client.from('users').select().eq('id', userId).single();

      return UserModel.fromJson(response);
    } catch (e) {
      // If user not found by ID, try to find by email as fallback
      // This handles cases where auth user ID doesn't match public.users ID
      try {
        final authUser = currentUser;
        if (authUser?.email != null) {
          debugPrint(
            'User not found by ID ($userId). Trying to find by email: ${authUser!.email}',
          );
          final emailResponse = await getUserByGmail(authUser.email!);
          if (emailResponse != null) {
            debugPrint(
              'Found user by email. Auth ID: $userId, Public ID: ${emailResponse.id}',
            );
            // If IDs don't match, this indicates an ID mismatch issue
            if (emailResponse.id != userId) {
              debugPrint(
                '⚠️ ID mismatch detected! Auth user ID: $userId, Public user ID: ${emailResponse.id}',
              );
              debugPrint(
                '⚠️ Run this SQL to fix: UPDATE public.users SET id = '
                '$userId'
                ' WHERE gmail = '
                '${authUser.email}'
                ';',
              );
            }
            return emailResponse;
          }
        }
      } catch (fallbackError) {
        debugPrint('Fallback lookup by email also failed: $fallbackError');
      }
      debugPrint('getCurrentUserProfile error: $e');
      return null;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all active teachers (for student report teacher selection)
  Future<List<UserModel>> getActiveTeachers() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('role', 'teacher')
          .eq('status', 'active')
          .order('full_name', ascending: true);

      return (response as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getActiveTeachers error: $e');
      return [];
    }
  }

  /// Get all active counselors
  Future<List<UserModel>> getActiveCounselors() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('role', 'counselor')
          .eq('status', 'active')
          .order('full_name', ascending: true);

      return (response as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getActiveCounselors error: $e');
      return [];
    }
  }

  // Dashboard stats helpers
  Future<int> countUsers({String? status}) async {
    try {
      var query = _client.from('users').select('id');
      if (status != null) {
        query = query.eq('status', status);
      }
      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countUsers error: $e');
      return 0;
    }
  }

  Future<int> countRecentLogins({
    Duration window = const Duration(hours: 24),
  }) async {
    try {
      final since = DateTime.now().subtract(window).toIso8601String();
      final response = await _client
          .from('users')
          .select('id')
          .eq('status', 'active')
          .gte('last_login', since);
      return (response as List).length;
    } catch (e) {
      debugPrint('countRecentLogins error: $e');
      return 0;
    }
  }

  Future<void> logActivity({
    required String userId,
    required String action,
  }) async {
    try {
      await _client.from('activity_logs').insert({
        'user_id': userId,
        'action': action,
      });
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Future<List<UserActivityLog>> getActivityLogs({int limit = 20}) async {
    try {
      final response = await _client
          .from('activity_logs')
          .select('*, users(full_name, role, gmail)')
          .order('timestamp', ascending: false)
          .limit(limit);
      return (response as List)
          .map((e) => UserActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getActivityLogs error: $e');
      return [];
    }
  }

  /// Create new user (Admin only)
  /// Creates auth user with password and user record in database
  Future<UserModel?> createUser({
    required String gmail,
    required String fullName,
    required String password,
    required UserRole role,
    StudentLevel? studentLevel,
    String? course,
    String? gradeLevel,
    String? strand,
    String? section,
    String? yearLevel,
    String? department,
  }) async {
    // Store current admin user ID to preserve it
    final adminUserId = _client.auth.currentUser?.id;

    // Set flag to prevent auth state listener from processing sign-in during user creation
    _isCreatingUser = true;

    try {
      // First, create the auth user with password
      debugPrint(
        'Creating auth user with email: ${gmail.toLowerCase().trim()}',
      );
      final authResponse = await _client.auth.signUp(
        email: gmail.toLowerCase().trim(),
        password: password,
        emailRedirectTo: 'io.supabase.fcuguidance://login-callback',
      );

      if (authResponse.user == null) {
        debugPrint('Error: Auth user creation failed - user is null');
        throw Exception('Failed to create auth user. User may already exist.');
      }

      final authUserId = authResponse.user!.id;
      debugPrint('Auth user created successfully with ID: $authUserId');

      // Check if email is confirmed
      bool emailConfirmed = authResponse.user!.emailConfirmedAt != null;

      if (!emailConfirmed) {
        debugPrint(
          'Email not confirmed immediately. Waiting for auto-confirm trigger...',
        );
        // Wait for the trigger to run (if it exists)
        // Try multiple times with delays to allow trigger to complete
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));

          // Try to refresh the session to get updated user info
          try {
            // Refresh the session to get updated confirmation status
            await _client.auth.refreshSession();
            final refreshedUser = _client.auth.currentUser;
            if (refreshedUser?.id == authUserId) {
              emailConfirmed = refreshedUser!.emailConfirmedAt != null;
              if (emailConfirmed) {
                debugPrint(
                  '✅ Email confirmed by auto-confirm trigger (attempt ${i + 1})',
                );
                break;
              }
            }
          } catch (e) {
            debugPrint('Error checking email confirmation: $e');
          }
        }

        // If still not confirmed, the trigger may not be set up
        if (!emailConfirmed) {
          debugPrint(
            '⚠️ Email still not confirmed after waiting. '
            'Please ensure the auto-confirm trigger is set up: supabase/auto_confirm_users_trigger.sql',
          );
          debugPrint(
            '⚠️ Run this SQL in Supabase SQL Editor to manually confirm: '
            'UPDATE auth.users SET email_confirmed_at = NOW() WHERE id = '
            '$authUserId'
            ';',
          );
          debugPrint(
            '⚠️ Alternatively, disable email confirmation in Supabase Dashboard → Authentication → Settings',
          );
          // Continue anyway - the user can still be created, but login will fail until confirmed
        }
      } else {
        debugPrint('✅ Email already confirmed during signup');
      }

      // IMPORTANT: Prevent auto-login for ALL roles (student, teacher, counselor, admin)
      // Check if signUp created a session and if we're logged in as the new user
      final currentUserAfterSignUp = _client.auth.currentUser;
      final loggedInAsNewUser = currentUserAfterSignUp?.id == authUserId;
      final stillAdmin = currentUserAfterSignUp?.id == adminUserId;

      if (authResponse.session != null || loggedInAsNewUser) {
        debugPrint(
          'Session was created during signup for ${role.toString()} user',
        );

        // If we're logged in as the new user (not admin), the flag will prevent auth provider from processing
        if (loggedInAsNewUser && !stillAdmin && adminUserId != null) {
          debugPrint(
            '⚠️ Logged in as new ${role.toString()} user - flag prevents auth provider from processing',
          );
          // The _isCreatingUser flag prevents the auth provider from processing this sign-in
        } else if (stillAdmin) {
          debugPrint('✅ Still logged in as admin - session preserved');
        }
      } else {
        // No session was created, which is good - admin session should be preserved
        debugPrint(
          'No session created for ${role.toString()} user - admin session preserved',
        );
      }

      // Insert into users table with the auth user ID
      // Build insert map conditionally based on role
      final insertData = <String, dynamic>{
        'id': authUserId, // Use the actual auth user ID
        'gmail': gmail.toLowerCase(),
        'full_name': fullName,
        'role': role.toString(),
        'status': 'active',
      };

      // Only include student-specific fields if role is student
      if (role == UserRole.student) {
        if (studentLevel != null) {
          insertData['student_level'] = studentLevel.toString();
        }
        if (course != null) insertData['course'] = course;
        if (gradeLevel != null) insertData['grade_level'] = gradeLevel;
        if (strand != null) insertData['strand'] = strand;
        if (section != null) insertData['section'] = section;
        if (yearLevel != null) insertData['year_level'] = yearLevel;
      } else {
        // For non-student roles, only include department
        if (department != null) insertData['department'] = department;
      }

      try {
        final response =
            await _client.from('users').insert(insertData).select().single();

        debugPrint('✅ User record created successfully in users table');
        debugPrint(
          '✅ User account created. User can now login with their credentials.',
        );

        // Final check: Ensure we're not logged in as the new user
        // The flag prevents auth provider from processing any sign-in during user creation
        final finalCurrentUser = _client.auth.currentUser;
        final finalLoggedInAsNewUser = finalCurrentUser?.id == authUserId;
        final finalLoggedInAsAdmin = finalCurrentUser?.id == adminUserId;

        if (finalLoggedInAsNewUser &&
            !finalLoggedInAsAdmin &&
            adminUserId != null) {
          debugPrint(
            '⚠️ Logged in as new ${role.toString()} user instead of admin',
          );
          // Sign out the new user session
          // The flag is still true, so auth provider won't process this sign-out
          await _client.auth.signOut();
          await Future.delayed(const Duration(milliseconds: 300));

          // After sign out, check if we need to restore admin
          // Note: Admin session may have been replaced, so we can't easily restore it
          // But at least we're not logged in as the new user
          final afterSignOut = _client.auth.currentUser;
          if (afterSignOut == null) {
            debugPrint(
              'ℹ️ No active session after sign out. Admin may need to login again.',
            );
          } else if (afterSignOut.id == adminUserId) {
            debugPrint('✅ Admin session restored');
          }
        } else if (finalLoggedInAsAdmin) {
          debugPrint('✅ Admin session preserved after user creation');
        } else if (finalCurrentUser == null && adminUserId != null) {
          debugPrint(
            'ℹ️ No active session. Admin was logged out during user creation.',
          );
        }

        // Clear the flag after user creation is complete
        // This allows auth state changes to be processed normally again
        _isCreatingUser = false;

        return UserModel.fromJson(response);
      } catch (insertError) {
        // Check if error is due to missing columns (schema not migrated)
        if (insertError.toString().contains('student_level') ||
            insertError.toString().contains('strand') ||
            insertError.toString().contains('section') ||
            insertError.toString().contains('year_level') ||
            insertError.toString().contains('PGRST204')) {
          debugPrint(
            '⚠️ Database schema error: Missing student level columns. '
            'Please run the migration: supabase/user_management_schema.sql',
          );

          // Try inserting without the new columns as fallback
          final fallbackData = <String, dynamic>{
            'id': authUserId,
            'gmail': gmail.toLowerCase(),
            'full_name': fullName,
            'role': role.toString(),
            'status': 'active',
          };

          // Only include basic fields that should exist
          if (role == UserRole.student) {
            if (course != null) fallbackData['course'] = course;
            if (gradeLevel != null) fallbackData['grade_level'] = gradeLevel;
          } else {
            if (department != null) fallbackData['department'] = department;
          }

          try {
            final fallbackResponse =
                await _client
                    .from('users')
                    .insert(fallbackData)
                    .select()
                    .single();

            debugPrint(
              '⚠️ User created without student level fields. '
              'Please run migration to add student_level, strand, section, year_level columns.',
            );

            _isCreatingUser = false;
            return UserModel.fromJson(fallbackResponse);
          } catch (fallbackError) {
            debugPrint('Fallback insert also failed: $fallbackError');
            throw Exception(
              'Database schema is missing required columns. '
              'Please run the migration script: supabase/user_management_schema.sql '
              'in your Supabase SQL Editor to add the student_level, strand, section, and year_level columns.',
            );
          }
        }
        // Re-throw if it's a different error
        rethrow;
      }
    } catch (e) {
      debugPrint('Error creating user: $e');

      // Check if auth user was created but users table insert failed
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('already exists')) {
        debugPrint('User may already exist. Checking...');

        // Check if user exists in users table
        try {
          final existing =
              await _client
                  .from('users')
                  .select()
                  .eq('gmail', gmail.toLowerCase())
                  .maybeSingle();
          if (existing != null) {
            debugPrint(
              'User exists in users table but auth user may be missing',
            );
            // Check if we can sign in (which would verify auth user exists)
            try {
              await _client.auth.signInWithPassword(
                email: gmail.toLowerCase().trim(),
                password: password,
              );
              debugPrint('Auth user exists and password is correct');
            } catch (signInError) {
              debugPrint('Cannot sign in: $signInError');
              debugPrint('Auth user may not exist or password is wrong');
              throw Exception(
                'User exists in database but cannot login. '
                'The auth user may be missing or password is incorrect. '
                'Please delete and recreate the user, or reset the password in Supabase Dashboard.',
              );
            }
            return UserModel.fromJson(existing);
          }
        } catch (checkError) {
          debugPrint('Error checking existing user: $checkError');
        }
      }

      // Clear the flag even on error
      _isCreatingUser = false;

      // Re-throw the error so it can be handled by the caller
      rethrow;
    }
  }

  /// Check if we're currently creating a user (to prevent auth state listener from processing)
  bool get isCreatingUser => _isCreatingUser;

  /// Link auth user to users table after magic link sign-in
  Future<bool> linkAuthUserToProfile(String authUserId, String gmail) async {
    try {
      // Find user by email
      final user =
          await _client
              .from('users')
              .select()
              .eq('gmail', gmail.toLowerCase())
              .maybeSingle();

      if (user != null) {
        // Update the user's ID to match auth user ID
        await _client
            .from('users')
            .update({'id': authUserId})
            .eq('gmail', gmail.toLowerCase());
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Update user
  Future<UserModel?> updateUser({
    required String userId,
    String? gmail,
    String? fullName,
    StudentLevel? studentLevel,
    String? course,
    String? gradeLevel,
    String? strand,
    String? section,
    String? yearLevel,
    String? department,
    String? avatarUrl,
    UserRole? role,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (gmail != null) {
        updates['gmail'] = gmail.toLowerCase();
      }
      if (fullName != null) {
        updates['full_name'] = fullName;
      }
      if (studentLevel != null) {
        updates['student_level'] = studentLevel.toString();
      }
      if (course != null) {
        updates['course'] = course;
      }
      if (gradeLevel != null) {
        updates['grade_level'] = gradeLevel;
      }
      if (strand != null) {
        updates['strand'] = strand;
      }
      if (section != null) {
        updates['section'] = section;
      }
      if (yearLevel != null) {
        updates['year_level'] = yearLevel;
      }
      if (department != null) {
        updates['department'] = department;
      }
      if (avatarUrl != null) {
        updates['avatar_url'] = avatarUrl;
      }
      if (role != null) {
        updates['role'] = role.toString();
      }
      if (status != null) {
        updates['status'] = status;
      }

      final response =
          await _client
              .from('users')
              .update(updates)
              .eq('id', userId)
              .select()
              .single();

      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Upload user avatar
  Future<String?> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    try {
      final path = 'avatars/$userId.$extension';
      await _client.storage
          .from('app_assets')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final publicUrl = _client.storage.from('app_assets').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  /// Upload a generic file (e.g. report attachment)
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      // Get public URL
      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  /// Update user password (Admin only)
  /// Note: This requires admin privileges via Supabase Edge Function or backend.
  /// For production, create a Supabase Edge Function that uses service role key.
  Future<bool> updateUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      // Validate password length
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      // Call Database Function (RPC) for secure password update
      try {
        await _client.rpc(
          'admin_update_user_password',
          params: {'target_user_id': userId, 'new_password': newPassword},
        );
        debugPrint('✅ Password updated successfully for user: $userId');
        return true;
      } catch (rpcError) {
        debugPrint('RPC error: $rpcError');
        // Provide helpful error message
        throw Exception(
          'Password update requires backend setup. '
          'Please run the SQL script "supabase/admin_password_reset.sql" '
          'in your Supabase SQL Editor to create the required "admin_update_user_password" function.',
        );
      }
    } catch (e) {
      debugPrint('Error updating password: $e');
      rethrow;
    }
  }

  /// Disable user account
  Future<bool> disableUser(String userId) async {
    try {
      await _client
          .from('users')
          .update({'status': 'inactive'})
          .eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Enable user account
  Future<bool> enableUser(String userId) async {
    try {
      await _client.from('users').update({'status': 'active'}).eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete user (hard delete)
  /// Note: Auth user deletion requires backend/Edge Function
  Future<bool> deleteUser(String userId) async {
    try {
      // Delete from users table
      await _client.from('users').delete().eq('id', userId);
      // Note: Auth user deletion should be handled by backend/Edge Function
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response =
          await _client.from('users').select().eq('id', userId).maybeSingle();
      if (response != null) {
        return UserModel.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    try {
      final response = await _client
          .from('users')
          .select()
          .filter('id', 'in', '(${userIds.map((id) => '"$id"').join(',')})');

      return (response as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getUsersByIds error: $e');
      return [];
    }
  }

  // ============================================
  // REPORTS
  // ============================================

  Future<ReportModel> createReport({
    required String studentId,
    required String title,
    required String type,
    required String details,
    String? attachmentUrl,
    DateTime? incidentDate,
    bool isAnonymous = false,
    String? teacherId,
  }) async {
    final reportData = {
      'student_id': studentId,
      'title': title,
      'type': type,
      'details': details,
      'is_anonymous': isAnonymous,
      'status': 'submitted',
    };

    if (teacherId != null && teacherId.isNotEmpty) {
      reportData['teacher_id'] = teacherId;
    }

    if (attachmentUrl != null) {
      reportData['attachment_url'] = attachmentUrl;
    }

    if (incidentDate != null) {
      reportData['incident_date'] = incidentDate.toIso8601String();
    }

    final response =
        await _client.from('reports').insert(reportData).select().single();

    final report = ReportModel.fromJson(response);

    // Create activity log for submission
    await createReportActivityLog(
      reportId: report.id,
      actorId: studentId,
      role: 'student',
      action: 'submitted',
    );

    return report;
  }

  /// Create anonymous report (no authentication required)
  /// Note: This requires RLS policies to allow anonymous inserts
  /// For production, consider using a Supabase Edge Function

  /// Get report by tracking ID (for anonymous report tracking)
  Future<ReportModel?> getReportByTrackingId(String trackingId) async {
    try {
      final response =
          await _client
              .from('reports')
              .select()
              .eq('tracking_id', trackingId)
              .maybeSingle();

      if (response != null) {
        return ReportModel.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting report by tracking ID: $e');
      return null;
    }
  }

  /// Get all anonymous reports (for counselor/admin dashboards)
  Future<List<ReportModel>> getAnonymousReports() async {
    try {
      final response = await _client
          .from('reports')
          .select()
          .eq('is_anonymous', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting anonymous reports: $e');
      return [];
    }
  }

  Future<List<ReportModel>> getStudentReports(String studentId) async {
    try {
      final response = await _client
          .from('reports')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ReportModel>> getTeacherReports(String teacherId) async {
    try {
      final response = await _client
          .from('reports')
          .select()
          .or('teacher_id.eq.$teacherId,teacher_id.is.null')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getTeacherReports error: $e');
      return [];
    }
  }

  Future<List<ReportModel>> getTeacherReportsAndAnonymous(
    String teacherId,
  ) async {
    final regularReports = await getTeacherReports(teacherId);
    final anonymousReportsData = await getTeacherAnonymousReports(teacherId);

    final anonymousReports =
        anonymousReportsData
            .map((reportData) {
              final report = reportData['anonymous_reports'];
              if (report == null) return null;

              final statusString = report['status'] as String? ?? 'pending';
              ReportStatus status;
              switch (statusString) {
                case 'pending':
                  status = ReportStatus.pending;
                  break;
                case 'ongoing':
                  status = ReportStatus.teacherReviewed;
                  break;
                case 'forwarded':
                  status = ReportStatus.forwarded;
                  break;
                case 'resolved':
                  status = ReportStatus.settled;
                  break;
                default:
                  status = ReportStatus.pending;
              }

              return ReportModel(
                id: report['id'] as String,
                title: report['category'] as String? ?? 'Anonymous Report',
                type: report['category'] as String? ?? 'Other',
                details:
                    report['description'] as String? ?? 'No details provided.',
                status: status,
                isAnonymous: true,
                counselorId: report['counselor_id'] as String?,
                teacherNote: report['teacher_note'] as String?,
                trackingId: report['case_code'] as String?,
                createdAt: DateTime.parse(report['created_at'] as String),
                updatedAt: DateTime.parse(report['updated_at'] as String),
              );
            })
            .whereType<ReportModel>()
            .toList();

    final allReports = [...regularReports, ...anonymousReports];
    allReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return allReports;
  }

  Future<List<ReportModel>> getCounselorReports(String counselorId) async {
    try {
      final response = await _client
          .from('reports')
          .select()
          .or('counselor_id.eq.$counselorId,counselor_id.is.null')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<ReportModel> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    String? teacherId,
    String? counselorId,
    String? note,
  }) async {
    final updates = <String, dynamic>{'status': status.toString()};
    if (teacherId != null) updates['teacher_id'] = teacherId;
    if (counselorId != null) updates['counselor_id'] = counselorId;
    if (note != null) updates['teacher_note'] = note;

    try {
      final response =
          await _client
              .from('reports')
              .update(updates)
              .eq('id', reportId)
              .select()
              .single();

      final report = ReportModel.fromJson(response);

      // Create activity log
      await _createLog(
        reportId: reportId,
        status: status,
        teacherId: teacherId,
        counselorId: counselorId,
        note: note,
      );

      return report;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // Report not found in 'reports' table, try 'anonymous_reports'
        String anonStatus = 'pending';
        if (status == ReportStatus.settled ||
            status == ReportStatus.completed ||
            status == ReportStatus.approvedByDean) {
          anonStatus = 'resolved';
        } else if (status == ReportStatus.forwarded) {
          anonStatus = 'forwarded';
        } else if (status != ReportStatus.pending &&
            status != ReportStatus.submitted) {
          anonStatus = 'ongoing';
        }

        final updateData = <String, dynamic>{'status': anonStatus};
        if (counselorId != null) updateData['counselor_id'] = counselorId;
        if (note != null) updateData['teacher_note'] = note;

        final response =
            await _client
                .from('anonymous_reports')
                .update(updateData)
                .eq('id', reportId)
                .select()
                .single();

        // Construct ReportModel from anonymous response
        final report = ReportModel(
          id: response['id'] as String,
          title: response['category'] as String? ?? 'Anonymous Report',
          type: response['category'] as String? ?? 'Other',
          details: response['description'] as String? ?? 'No details provided.',
          status: status, // Return the requested status to keep UI in sync
          isAnonymous: true,
          trackingId: response['case_code'] as String?,
          createdAt: DateTime.parse(response['created_at'] as String),
          updatedAt: DateTime.parse(response['updated_at'] as String),
        );

        return report;
      }
      rethrow;
    }
  }

  Future<void> _createLog({
    required String reportId,
    required ReportStatus status,
    String? teacherId,
    String? counselorId,
    String? note,
  }) async {
    String action = status.toString();
    String role = 'teacher';
    String? actorId = teacherId ?? counselorId;

    if (counselorId != null) {
      role = 'counselor';
      if (status == ReportStatus.counselorConfirmed) {
        action = 'confirmed';
      } else if (status == ReportStatus.counselorReviewed) {
        action = 'reviewed_and_forwarded_to_dean';
      } else if (status == ReportStatus.forwarded) {
        action = 'forwarded';
      }
    } else if (teacherId != null) {
      if (status == ReportStatus.teacherReviewed) {
        action = 'reviewed';
      } else if (status == ReportStatus.forwarded) {
        action = 'forwarded';
      }
    }

    if (actorId != null) {
      await createReportActivityLog(
        reportId: reportId,
        actorId: actorId,
        role: role,
        action: action,
        note: note,
      );
    }
  }

  // Get reports with filters
  Future<List<ReportModel>> getReportsWithFilters({
    String? studentId,
    String? teacherId,
    String? counselorId,
    String? deanId,
    ReportStatus? status,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client.from('reports').select();

      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }
      // For teachers: show assigned reports OR anonymous reports (for communication)
      if (teacherId != null) {
        // Show: assigned to teacher OR anonymous reports
        query = query.or('teacher_id.eq.$teacherId,is_anonymous.eq.true');
      }
      // For counselors: show assigned reports OR reviewed/approved reports OR anonymous reports
      if (counselorId != null) {
        // Show: assigned to counselor OR oversight statuses OR anonymous reports
        // Fetch all cases where counselor can communicate
        query = query.or(
          'counselor_id.eq.$counselorId,status.in.("forwarded","counselor_reviewed","approved_by_dean","counseling_scheduled"),is_anonymous.eq.true',
        );
      }
      // For Deans/Admins: show reports requiring oversight or direct assignment
      if (deanId != null) {
        // Deans see reports when they are the direct dean_id
        // OR when a counselor has reviewed/escalated (typically for college students)
        query = query.or(
          'dean_id.eq.$deanId,status.in.("counselor_reviewed","approved_by_dean","counseling_scheduled")',
        );
      }
      if (status != null) {
        query = query.eq('status', status.toString());
      }
      if (type != null) {
        query = query.eq('type', type);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getReportsWithFilters error: $e');
      return [];
    }
  }

  // Get reports forwarded to counselor (for case records)
  Future<List<ReportModel>> getForwardedReports(String counselorId) async {
    try {
      // 1. Get regular forwarded reports
      final response = await _client
          .from('reports')
          .select()
          .eq('status', 'forwarded')
          // include unassigned or null counselor_id without empty-string uuid errors
          .or('counselor_id.eq.$counselorId,counselor_id.is.null')
          .order('created_at', ascending: false);

      final regularReports =
          (response as List)
              .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
              .toList();

      // 2. Get forwarded or pending anonymous reports
      // 2. Get relevant anonymous reports
      // a. Get reports explicitly assigned to this counselor (for submitted status)
      final myAssignments = await _client
          .from('anonymous_report_counselors')
          .select('report_id')
          .eq('counselor_id', counselorId);

      final myReportIds =
          (myAssignments as List).map((a) => a['report_id'] as String).toList();

      // b. Fetch reports: Either Forwarded (public to guidance) OR (Pending AND Assigned to Me)
      // Note: We fetch both independently or use a filter
      final forwardedResponse = await _client
          .from('anonymous_reports')
          .select()
          .eq('status', 'forwarded');

      final myDirectResponse =
          myReportIds.isNotEmpty
              ? await _client
                  .from('anonymous_reports')
                  .select()
                  .eq('status', 'pending')
                  .inFilter('id', myReportIds)
              : [];

      final combinedRaw = [...forwardedResponse as List, ...myDirectResponse];

      // Deduplicate in case of overlaps (unlikely with distinct statuses but good practice)
      final uniqueReports = <String, Map<String, dynamic>>{};
      for (final r in combinedRaw) {
        uniqueReports[r['id']] = r;
      }

      final anonymousReports =
          uniqueReports.values.map((json) {
            return ReportModel(
              id: json['id'] as String,
              title: json['category'] as String? ?? 'Anonymous Report',
              type: json['category'] as String? ?? 'Other',
              details: json['description'] as String? ?? 'No details provided.',
              status:
                  json['status'] == 'pending'
                      ? ReportStatus.submitted
                      : ReportStatus.fromString(json['status'] as String),
              isAnonymous: true,
              trackingId: json['case_code'] as String?,
              createdAt: DateTime.parse(json['created_at'] as String),
              updatedAt: DateTime.parse(
                json['updated_at'] as String? ?? json['created_at'] as String,
              ),
            );
          }).toList();

      // 3. Combine and sort
      final allReports = [...regularReports, ...anonymousReports];
      allReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allReports;
    } catch (e) {
      debugPrint('getForwardedReports error: $e');
      return [];
    }
  }

  // Get all reports relevant to counselor (including forwarded to Dean and resolved)
  Future<List<ReportModel>> getCounselorAllReports(String counselorId) async {
    try {
      // 1. Get reports with various statuses
      final response = await _client
          .from('reports')
          .select()
          .inFilter('status', [
            'forwarded',
            'counselor_confirmed',
            'counselor_reviewed',
            'approved_by_dean',
            'counseling_scheduled',
            'settled',
            'completed',
          ])
          .or('counselor_id.eq.$counselorId,counselor_id.is.null')
          .order('created_at', ascending: false);

      final regularReports =
          (response as List)
              .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
              .toList();

      // 2. Get anonymous reports
      // a. Get IDs assigned to this counselor
      final myAssignments = await _client
          .from('anonymous_report_counselors')
          .select('report_id')
          .eq('counselor_id', counselorId);

      final myReportIds =
          (myAssignments as List).map((a) => a['report_id'] as String).toList();

      // b. Fetch standard visible reports (forwarded/ongoing/resolved)
      // AND my specific pending reports
      // We'll fetch all forwarded/ongoing/resolved as before, plus my pending ones.

      // Fetch 1: Publicly visible statuses
      final visibleResponse = await _client
          .from('anonymous_reports')
          .select()
          .inFilter('status', ['forwarded', 'ongoing', 'resolved'])
          .order('created_at', ascending: false);

      // Fetch 2: My Pending Direct Submissions
      final myPendingResponse =
          myReportIds.isNotEmpty
              ? await _client
                  .from('anonymous_reports')
                  .select()
                  .eq('status', 'pending')
                  .inFilter('id', myReportIds)
              : [];

      final combinedAnonRaw = [
        ...visibleResponse as List,
        ...myPendingResponse,
      ];

      // Deduplicate
      final uniqueAnon = <String, Map<String, dynamic>>{};
      for (final r in combinedAnonRaw) {
        uniqueAnon[r['id']] = r;
      }

      final anonymousReports =
          uniqueAnon.values.map((json) {
            String s = json['status'] as String? ?? 'forwarded';
            ReportStatus status = ReportStatus.forwarded;

            if (s == 'pending') {
              status = ReportStatus.submitted; // Map pending to submitted
            } else if (s == 'resolved') {
              status = ReportStatus.settled;
            } else if (s == 'ongoing') {
              status = ReportStatus.counselorReviewed;
            } else if (s == 'forwarded') {
              status = ReportStatus.forwarded;
            }

            return ReportModel(
              id: json['id'] as String,
              title: json['category'] as String? ?? 'Anonymous Report',
              type: json['category'] as String? ?? 'Other',
              details: json['description'] as String? ?? 'No details provided.',
              status: status,
              isAnonymous: true,
              trackingId: json['case_code'] as String?,
              createdAt: DateTime.parse(json['created_at'] as String),
              updatedAt: DateTime.parse(
                json['updated_at'] as String? ?? json['created_at'] as String,
              ),
            );
          }).toList();

      // 3. Combine and sort
      final allReports = [...regularReports, ...anonymousReports];
      allReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allReports;
    } catch (e) {
      debugPrint('getCounselorAllReports error: $e');
      return [];
    }
  }

  Future<ReportModel?> getReportById(String reportId) async {
    try {
      final response =
          await _client.from('reports').select().eq('id', reportId).single();

      return ReportModel.fromJson(response);
    } catch (e) {
      debugPrint('getReportById error: $e');
      return null;
    }
  }

  // ============================================
  // DEAN ACTIONS
  // ============================================

  /// Get reports reviewed by counselor (ready for Dean approval)
  Future<List<ReportModel>> getCounselorReviewedReports() async {
    try {
      final response = await _client
          .from('reports')
          .select()
          .eq('status', 'counselor_reviewed')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getCounselorReviewedReports error: $e');
      return [];
    }
  }

  /// Get reports for Dean (only College students with relevant statuses)
  Future<List<ReportModel>> getDeanReports() async {
    try {
      // 1. Fetch reports with statuses relevant to Dean
      final response = await _client
          .from('reports')
          .select()
          .inFilter('status', [
            'counselor_reviewed',
            'approved_by_dean',
            'counseling_scheduled',
          ])
          .order('created_at', ascending: false);

      final reports =
          (response as List)
              .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
              .toList();

      if (reports.isEmpty) return [];

      // 2. Fetch student details to filter for College level
      final studentIds =
          reports
              .map((r) => r.studentId)
              .where((id) => id != null)
              .toSet()
              .toList();

      if (studentIds.isEmpty) return [];

      // Batch fetch users
      final studentsResponse = await _client
          .from('users')
          .select('id, student_level')
          .inFilter('id', studentIds);

      final collegeStudentIds =
          (studentsResponse as List)
              .where((json) {
                final level = json['student_level'] as String?;
                return level != null && level.toLowerCase() == 'college';
              })
              .map((json) => json['id'] as String)
              .toSet();

      // 3. Filter reports: Include only if student is College
      return reports
          .where(
            (r) =>
                r.studentId != null && collegeStudentIds.contains(r.studentId),
          )
          .toList();
    } catch (e) {
      debugPrint('getDeanReports error: $e');
      return [];
    }
  }

  /// Approve report by Dean (changes status to approved_by_dean)
  Future<ReportModel> approveReportByDean({
    required String reportId,
    required String deanId,
    String? deanNote,
  }) async {
    final updates = <String, dynamic>{
      'status': ReportStatus.approvedByDean.toString(),
      'dean_id': deanId,
    };
    if (deanNote != null && deanNote.isNotEmpty) {
      updates['dean_note'] = deanNote;
    }

    final response =
        await _client
            .from('reports')
            .update(updates)
            .eq('id', reportId)
            .select()
            .single();

    final report = ReportModel.fromJson(response);

    // Create activity log
    await createReportActivityLog(
      reportId: reportId,
      actorId: deanId,
      role: 'dean',
      action: 'approved_by_dean',
      note: deanNote ?? 'Report approved for counseling eligibility',
    );

    return report;
  }

  /// Decline report by Dean
  Future<ReportModel> declineReportByDean({
    required String reportId,
    required String deanId,
    String? deanNote,
  }) async {
    final updates = <String, dynamic>{
      'status': ReportStatus.settled.toString(), // Mark as settled/declined
      'dean_id': deanId,
    };
    if (deanNote != null && deanNote.isNotEmpty) {
      updates['dean_note'] = deanNote;
    }

    final response =
        await _client
            .from('reports')
            .update(updates)
            .eq('id', reportId)
            .select()
            .single();

    final report = ReportModel.fromJson(response);

    // Create activity log
    await createReportActivityLog(
      reportId: reportId,
      actorId: deanId,
      role: 'dean',
      action: 'declined_by_dean',
      note: deanNote ?? 'Report declined by Dean',
    );

    return report;
  }

  /// Schedule counseling session by Dean
  Future<void> scheduleCounselingByDean({
    required String reportId,
    required String deanId,
    required String counselorId,
    required DateTime sessionDate,
    required int sessionHour,
    required int sessionMinute,
    required String sessionType,
    required String locationMode,
    required List<Map<String, dynamic>> participants,
  }) async {
    // Update report status to counseling_scheduled
    await _client
        .from('reports')
        .update({
          'status': ReportStatus.counselingScheduled.toString(),
          'dean_id': deanId,
        })
        .eq('id', reportId);

    // Create or update counseling request
    // Check if counseling request already exists
    final existingRequest =
        await _client
            .from('counseling_requests')
            .select()
            .eq('report_id', reportId)
            .maybeSingle();

    final sessionDateStr = DateFormat('yyyy-MM-dd').format(sessionDate);
    final sessionTimeStr =
        '${sessionHour.toString().padLeft(2, '0')}:${sessionMinute.toString().padLeft(2, '0')}:00';

    if (existingRequest != null) {
      // Update existing request
      await _client
          .from('counseling_requests')
          .update({
            'counselor_id': counselorId,
            'dean_id': deanId,
            'session_date': sessionDateStr,
            'session_time': sessionTimeStr,
            'session_type': sessionType,
            'location_mode': locationMode,
            'participants': participants,
            'status': 'Counseling Confirmed',
          })
          .eq('id', existingRequest['id']);
    } else {
      // Create new request
      final report = await getReportById(reportId);
      if (report == null || report.studentId == null) {
        throw Exception('Report not found or student ID missing');
      }

      await _client.from('counseling_requests').insert({
        'report_id': reportId,
        'student_id': report.studentId,
        'counselor_id': counselorId,
        'dean_id': deanId,
        'session_date': sessionDateStr,
        'session_time': sessionTimeStr,
        'session_type': sessionType,
        'location_mode': locationMode,
        'participants': participants,
        'status': 'Counseling Confirmed',
      });
    }

    // Create activity log
    final timeStr =
        '${sessionHour.toString().padLeft(2, '0')}:${sessionMinute.toString().padLeft(2, '0')}';
    await createReportActivityLog(
      reportId: reportId,
      actorId: deanId,
      role: 'dean',
      action: 'counseling_scheduled',
      note:
          'Counseling session scheduled: $sessionType, $locationMode on ${DateFormat('MMM dd, yyyy').format(sessionDate)} at $timeStr',
    );
  }

  // ============================================
  // REPORT ACTIVITY LOGS
  // ============================================

  Future<ReportActivityLog> createReportActivityLog({
    required String reportId,
    String? actorId, // Nullable for anonymous reports
    required String role,
    required String action,
    String? note,
  }) async {
    final response =
        await _client
            .from('report_activity_logs')
            .insert({
              'report_id': reportId,
              'actor_id': actorId, // Can be null for anonymous reports
              'role': role,
              'action': action,
              'note': note,
              'timestamp': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

    return ReportActivityLog.fromJson(response);
  }

  Future<List<ReportActivityLog>> getReportActivityLogs(String reportId) async {
    try {
      final response = await _client
          .from('report_activity_logs')
          .select()
          .eq('report_id', reportId)
          .order('timestamp', ascending: true);

      return (response as List)
          .map(
            (json) => ReportActivityLog.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('getReportActivityLogs error: $e');
      return [];
    }
  }

  // ============================================
  // DASHBOARD STATS - REPORTS
  // ============================================

  /// Count student reports by status
  Future<int> countStudentReports({
    required String studentId,
    ReportStatus? status,
    bool openOnly = false,
  }) async {
    try {
      var query = _client
          .from('reports')
          .select('id')
          .eq('student_id', studentId);

      if (status != null) {
        query = query.eq('status', status.toString());
      } else if (openOnly) {
        query = query.neq('status', 'settled');
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countStudentReports error: $e');
      // If it's a network error, log it but don't crash
      if (e.toString().contains('Failed to fetch') ||
          e.toString().contains('ClientException')) {
        debugPrint(
          'Network error fetching reports. This may be a temporary connection issue.',
        );
      }
      return 0;
    }
  }

  /// Count teacher reports by status
  Future<int> countTeacherReports({
    required String teacherId,
    ReportStatus? status,
    bool openOnly = false,
  }) async {
    try {
      var query = _client
          .from('reports')
          .select('id')
          .or('teacher_id.eq.$teacherId,teacher_id.is.null');

      if (status != null) {
        query = query.eq('status', status.toString());
      } else if (openOnly) {
        query = query.neq('status', 'settled');
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countTeacherReports error: $e');
      return 0;
    }
  }

  /// Count counselor cases by status
  Future<int> countCounselorCases({
    required String counselorId,
    ReportStatus? status,
    bool activeOnly = false,
  }) async {
    try {
      var query = _client
          .from('reports')
          .select('id')
          .or('counselor_id.eq.$counselorId,counselor_id.is.null');

      if (status != null) {
        query = query.eq('status', status.toString());
      } else if (activeOnly) {
        query = query.neq('status', 'settled');
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countCounselorCases error: $e');
      return 0;
    }
  }

  /// Count reports created today
  Future<int> countReportsToday({String? studentId, String? teacherId}) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      var query = _client
          .from('reports')
          .select('id')
          .gte('created_at', startOfDay.toIso8601String());

      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }
      if (teacherId != null) {
        query = query.eq('teacher_id', teacherId);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countReportsToday error: $e');
      return 0;
    }
  }

  /// Count all reports (admin)
  Future<int> countAllReports() async {
    try {
      final response = await _client.from('reports').select('id');
      return (response as List).length;
    } catch (e) {
      debugPrint('countAllReports error: $e');
      return 0;
    }
  }

  // ============================================
  // DASHBOARD STATS - COUNSELING REQUESTS
  // ============================================

  /// Count student counseling requests by status
  Future<int> countStudentCounselingRequests({
    required String studentId,
    String? status,
    bool activeOnly = false,
  }) async {
    try {
      var query = _client
          .from('counseling_requests')
          .select('id')
          .eq('student_id', studentId);

      if (status != null) {
        query = query.eq('status', status);
      } else if (activeOnly) {
        query = query.neq('status', 'completed').neq('status', 'cancelled');
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countStudentCounselingRequests error: $e');
      return 0;
    }
  }

  /// Count counselor counseling requests
  Future<int> countCounselorCounselingRequests({
    required String counselorId,
    String? status,
    bool activeOnly = false,
  }) async {
    try {
      var query = _client
          .from('counseling_requests')
          .select('id')
          .eq('counselor_id', counselorId);

      if (status != null) {
        query = query.eq('status', status);
      } else if (activeOnly) {
        query = query.neq('status', 'completed').neq('status', 'cancelled');
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countCounselorCounselingRequests error: $e');
      return 0;
    }
  }

  /// Count counseling requests today
  Future<int> countCounselingRequestsToday({
    String? studentId,
    String? counselorId,
  }) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      var query = _client
          .from('counseling_requests')
          .select('id')
          .gte('created_at', startOfDay.toIso8601String());

      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }
      if (counselorId != null) {
        query = query.eq('counselor_id', counselorId);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countCounselingRequestsToday error: $e');
      return 0;
    }
  }

  /// Count all counseling requests (admin)
  Future<int> countAllCounselingRequests() async {
    try {
      final response = await _client.from('counseling_requests').select('id');
      return (response as List).length;
    } catch (e) {
      debugPrint('countAllCounselingRequests error: $e');
      return 0;
    }
  }

  // ============================================
  // DASHBOARD STATS - NOTIFICATIONS
  // ============================================

  /// Count user notifications
  Future<int> countUserNotifications({
    required String userId,
    bool unreadOnly = false,
  }) async {
    try {
      var query = _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query;
      return (response as List).length;
    } catch (e) {
      debugPrint('countUserNotifications error: $e');
      return 0;
    }
  }

  // ============================================
  // COUNSELING REQUESTS
  // ============================================

  Future<CounselingRequestModel> createCounselingRequest({
    required String studentId,
    required String reportId,
    String? reason,
    String? preferredTime,
    String? requestDetails,
    DateTime? sessionDate,
    TimeOfDay? sessionTime,
    String? sessionType,
    String? locationMode,
    String? counselorId,
    List<Map<String, dynamic>>? participants,
  }) async {
    // Verify that the report is approved
    final report = await getReportById(reportId);
    if (report == null) {
      throw Exception('Report not found');
    }

    // Check student level for approval requirements
    final user = await getUserById(studentId);
    final isHighSchool =
        user?.studentLevel == StudentLevel.juniorHigh ||
        user?.studentLevel == StudentLevel.seniorHigh;

    bool isApproved = false;
    if (report.status == ReportStatus.approvedByDean) {
      isApproved = true;
    } else if (isHighSchool &&
        report.status == ReportStatus.counselorConfirmed) {
      isApproved = true;
    }

    if (!isApproved) {
      throw Exception(
        isHighSchool
            ? 'Counseling can only be requested for reports approved by Dean or confirmed by Counselor'
            : 'Counseling can only be requested for reports approved by Dean',
      );
    }

    final insertData = <String, dynamic>{
      'student_id': studentId,
      'report_id': reportId,
      'reason': reason,
      'preferred_time': preferredTime,
      'request_details': requestDetails,
      'status': 'Pending Counseling Review',
    };

    // Add scheduling information if provided
    if (sessionDate != null) {
      insertData['session_date'] = sessionDate.toIso8601String().split('T')[0];
    }
    if (sessionTime != null) {
      insertData['session_time'] =
          '${sessionTime.hour.toString().padLeft(2, '0')}:${sessionTime.minute.toString().padLeft(2, '0')}:00';
    }
    if (sessionType != null) {
      insertData['session_type'] = sessionType;
    }
    if (locationMode != null) {
      insertData['location_mode'] = locationMode;
    }
    if (counselorId != null) {
      insertData['counselor_id'] = counselorId;
    }
    if (participants != null && participants.isNotEmpty) {
      insertData['participants'] = participants;
    }

    final response =
        await _client
            .from('counseling_requests')
            .insert(insertData)
            .select()
            .single();

    final counselingRequest = CounselingRequestModel.fromJson(response);

    // Update report status to counseling_scheduled
    await _client
        .from('reports')
        .update({'status': 'counseling_scheduled'})
        .eq('id', reportId);

    // Log the request activity
    await createCounselingActivityLog(
      counselingId: counselingRequest.id,
      actorId: studentId,
      action: 'requested',
      note: reason ?? 'Counseling session requested and scheduled by student.',
    );

    // Also create a report-level activity log
    await createReportActivityLog(
      reportId: reportId,
      actorId: studentId,
      role: 'student',
      action: 'counseling_requested',
      note: 'Student has requested and scheduled a counseling session.',
    );

    return counselingRequest;
  }

  Future<List<CounselingRequestModel>> getStudentCounselingRequests(
    String studentId,
  ) async {
    try {
      final response = await _client
          .from('counseling_requests')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) =>
                CounselingRequestModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<CounselingRequestModel>> getCounselorRequests(
    String counselorId,
  ) async {
    try {
      final response = await _client
          .from('counseling_requests')
          .select()
          .eq('counselor_id', counselorId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) =>
                CounselingRequestModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<CounselingRequestModel> updateCounselingRequest({
    required String requestId,
    required CounselingStatus status,
    String? counselorId,
    String? counselorNote,
    DateTime? sessionDate,
    TimeOfDay? sessionTime,
    String? sessionType,
    String? locationMode,
  }) async {
    final updates = <String, dynamic>{'status': status.toString()};
    if (counselorId != null) updates['counselor_id'] = counselorId;
    if (counselorNote != null) updates['counselor_note'] = counselorNote;
    if (sessionDate != null) {
      updates['session_date'] = sessionDate.toIso8601String().split('T')[0];
    }
    if (sessionTime != null) {
      updates['session_time'] =
          '${sessionTime.hour.toString().padLeft(2, '0')}:${sessionTime.minute.toString().padLeft(2, '0')}:00';
    }
    if (sessionType != null) updates['session_type'] = sessionType;
    if (locationMode != null) updates['location_mode'] = locationMode;

    final response =
        await _client
            .from('counseling_requests')
            .update(updates)
            .eq('id', requestId)
            .select()
            .single();

    final updatedRequest = CounselingRequestModel.fromJson(response);

    // Log the status update activity
    String action = status.toString().toLowerCase().replaceAll(' ', '_');
    if (action == 'pending_counseling_review') {
      action = 'requested';
    } else if (action == 'counseling_confirmed') {
      action = 'confirmed';
    } else if (action == 'settled') {
      action = 'settled';
    }

    final actorId = counselorId ?? currentUser?.id;
    if (actorId != null) {
      String logNote = counselorNote ?? '';
      if (status == CounselingStatus.confirmed && sessionDate != null) {
        final dateStr = DateFormat('MMMM dd, yyyy').format(sessionDate);
        String timeStr = '';
        if (sessionTime != null) {
          final hour = sessionTime.hour % 12 == 0 ? 12 : sessionTime.hour % 12;
          final period = sessionTime.hour >= 12 ? 'PM' : 'AM';
          timeStr =
              '$hour:${sessionTime.minute.toString().padLeft(2, '0')} $period';
        }
        logNote +=
            '\nScheduled for: $dateStr ${timeStr.isNotEmpty ? "at $timeStr" : ""}';
      }

      await createCounselingActivityLog(
        counselingId: requestId,
        actorId: actorId,
        action: action,
        note: logNote.isNotEmpty ? logNote : null,
      );
    }

    return updatedRequest;
  }

  // Get confirmed reports for a student (eligible for counseling request)
  Future<List<ReportModel>> getConfirmedReportsForStudent(
    String studentId,
  ) async {
    try {
      final user = await getUserById(studentId);
      final isHighSchool =
          user?.studentLevel == StudentLevel.juniorHigh ||
          user?.studentLevel == StudentLevel.seniorHigh;

      // Build status filter
      // College: Approved by Dean only
      // High School: Approved by Dean OR Counselor Confirmed
      final statuses = <String>['approved_by_dean'];
      if (isHighSchool) {
        statuses.add('counselor_confirmed');
      }

      final response = await _client
          .from('reports')
          .select()
          .eq('student_id', studentId)
          .inFilter('status', statuses)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReportModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getConfirmedReportsForStudent error: $e');
      return [];
    }
  }

  // Get counseling request by ID with report details
  Future<CounselingRequestModel?> getCounselingRequestById(
    String requestId,
  ) async {
    try {
      final response =
          await _client
              .from('counseling_requests')
              .select()
              .eq('id', requestId)
              .single();

      return CounselingRequestModel.fromJson(response);
    } catch (e) {
      debugPrint('getCounselingRequestById error: $e');
      return null;
    }
  }

  // Get counseling request by Report ID
  Future<CounselingRequestModel?> getCounselingRequestByReportId(
    String reportId,
  ) async {
    try {
      final response =
          await _client
              .from('counseling_requests')
              .select()
              .eq('report_id', reportId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      if (response == null) return null;
      return CounselingRequestModel.fromJson(response);
    } catch (e) {
      debugPrint('getCounselingRequestByReportId error: $e');
      return null;
    }
  }

  // Get counseling requests for counselor (Student History)
  Future<List<CounselingRequestModel>> getCounselorCounselingRequests({
    required String counselorId,
    CounselingStatus? status,
  }) async {
    try {
      var query = _client
          .from('counseling_requests')
          .select()
          .eq('counselor_id', counselorId);

      if (status != null) {
        query = query.eq('status', status.toString());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) =>
                CounselingRequestModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('getCounselorCounselingRequests error: $e');
      return [];
    }
  }

  // Get all counseling requests for counselor (including unassigned)
  Future<List<CounselingRequestModel>> getAllCounselingRequestsForCounselor({
    required String counselorId,
    CounselingStatus? status,
  }) async {
    try {
      var query = _client
          .from('counseling_requests')
          .select()
          .or('counselor_id.eq.$counselorId,counselor_id.is.null');

      if (status != null) {
        query = query.eq('status', status.toString());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) =>
                CounselingRequestModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('getAllCounselingRequestsForCounselor error: $e');
      return [];
    }
  }

  // ============================================
  // COUNSELING ACTIVITY LOGS
  // ============================================

  Future<void> createCounselingActivityLog({
    required String counselingId,
    required String actorId,
    required String action,
    String? note,
  }) async {
    await _client.from('counseling_activity_logs').insert({
      'counseling_id': counselingId,
      'actor_id': actorId,
      'action': action,
      'note': note,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<CounselingActivityLog>> getCounselingActivityLogs(
    String counselingId,
  ) async {
    try {
      final response = await _client
          .from('counseling_activity_logs')
          .select()
          .eq('counseling_id', counselingId)
          .order('timestamp', ascending: true);

      return (response as List)
          .map(
            (json) =>
                CounselingActivityLog.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('getCounselingActivityLogs error: $e');
      return [];
    }
  }

  // Get recent activities for counselor dashboard
  Future<List<Map<String, dynamic>>> getCounselorRecentActivities({
    required String counselorId,
    int limit = 5,
  }) async {
    try {
      final allActivities = <Map<String, dynamic>>[];

      // 1. Get activities where the counselor is the actor
      final actorActivities = await _client
          .from('report_activity_logs')
          .select()
          .eq('actor_id', counselorId)
          .order('timestamp', ascending: false)
          .limit(limit);

      for (final activity in actorActivities as List) {
        allActivities.add({
          'type': 'report',
          'id': activity['id'],
          'action': activity['action'],
          'role': activity['role'],
          'timestamp': activity['timestamp'],
          'note': activity['note'],
          'report_id': activity['report_id'],
        });
      }

      // 2. Get activities for reports assigned to this counselor
      // Using a more efficient approach: first get some recent reports,
      // then their logs. Or better, just get logs where the actor is the counselor
      // or the report is one of theirs.

      // Since we want to fix the "Failed to fetch" which happened during ID fetching,
      // let's fetch the recent logs directly if we can, or just simplify the ID fetch.

      // Fetch latest reports assigned to counselor
      final recentReports = await _client
          .from('reports')
          .select('id')
          .or('counselor_id.eq.$counselorId,counselor_id.is.null')
          .order('updated_at', ascending: false)
          .limit(20);

      final reportIds =
          (recentReports as List).map((r) => r['id'] as String).toList();

      if (reportIds.isNotEmpty) {
        final logs = await _client
            .from('report_activity_logs')
            .select()
            .filter(
              'report_id',
              'in',
              '(${reportIds.map((id) => '"$id"').join(',')})',
            )
            .neq('actor_id', counselorId) // Avoid duplicates from step 1
            .order('timestamp', ascending: false)
            .limit(limit);

        for (final activity in logs as List) {
          allActivities.add({
            'type': 'report',
            'id': activity['id'],
            'action': activity['action'],
            'role': activity['role'],
            'timestamp': activity['timestamp'],
            'note': activity['note'],
            'report_id': activity['report_id'],
          });
        }
      }

      // 3. Counseling activities
      final counselingLogs = await _client
          .from('counseling_activity_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);

      // Filtering counseling logs manually or via join would be better,
      // but for now let's just take the most recent ones if they belong to the counselor
      for (final activity in counselingLogs as List) {
        // Simple check for now to avoid ID fetching overhead
        allActivities.add({
          'type': 'counseling',
          'id': activity['id'],
          'action': activity['action'],
          'timestamp': activity['timestamp'],
          'note': activity['note'],
          'counseling_id': activity['counseling_id'],
        });
      }

      // Sort by timestamp descending and limit
      allActivities.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp'] as String);
        final bTime = DateTime.parse(b['timestamp'] as String);
        return bTime.compareTo(aTime);
      });

      // Remove duplicates by ID and type
      final seen = <String>{};
      final uniqueActivities = <Map<String, dynamic>>[];
      for (final activity in allActivities) {
        final key = '${activity['type']}_${activity['id']}';
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueActivities.add(activity);
        }
      }

      return uniqueActivities.take(limit).toList();
    } catch (e) {
      debugPrint('getCounselorRecentActivities error: $e');
      return [];
    }
  }

  // Get recent activities for teacher dashboard
  Future<List<Map<String, dynamic>>> getTeacherRecentActivities({
    required String teacherId,
    int limit = 5,
  }) async {
    try {
      // Get reports assigned to this teacher
      List<String> reportIds = [];
      try {
        final reports = await _client
            .from('reports')
            .select('id')
            .eq('teacher_id', teacherId);

        final anonReports = await _client
            .from('anonymous_report_teachers')
            .select('report_id')
            .eq('teacher_id', teacherId);

        final regularIds = (reports as List)
            .where((r) => r['id'] != null)
            .map((r) => r['id'] as String);

        final anonIds = (anonReports as List)
            .where((r) => r['report_id'] != null)
            .map((r) => r['report_id'] as String);

        reportIds = [...regularIds, ...anonIds];
      } catch (e) {
        debugPrint('Error fetching teacher report IDs: $e');
      }

      // Get report activity logs
      final allActivities = <Map<String, dynamic>>[];

      if (reportIds.isNotEmpty) {
        var query = _client.from('report_activity_logs').select();

        // Build OR query for multiple report IDs
        if (reportIds.length == 1) {
          query = query.eq('report_id', reportIds[0]);
        } else {
          query = query.or(reportIds.map((id) => 'report_id.eq.$id').join(','));
        }

        final reportActivities = await query
            .order('timestamp', ascending: false)
            .limit(limit * 2); // Get more to account for filtering

        for (final activity in reportActivities) {
          allActivities.add({
            'type': 'report',
            'id': activity['id'],
            'action': activity['action'],
            'role': activity['role'],
            'timestamp': activity['timestamp'],
            'note': activity['note'],
            'report_id': activity['report_id'],
          });
        }
      }

      // Sort by timestamp descending and limit
      allActivities.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp'] as String);
        final bTime = DateTime.parse(b['timestamp'] as String);
        return bTime.compareTo(aTime);
      });

      return allActivities.take(limit).toList();
    } catch (e) {
      debugPrint('getTeacherRecentActivities error: $e');
      return [];
    }
  }

  // ============================================
  // RESOURCE LIBRARY
  // ============================================

  Future<List<ResourceModel>> getResources({bool publicOnly = true}) async {
    try {
      var query = _client.from('resource_library').select();
      if (publicOnly) {
        query = query.eq('is_public', true);
      }
      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => ResourceModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<ResourceModel> createResource({
    required String counselorId,
    required String title,
    required String fileUrl,
    required ResourceFileType fileType,
    String? description,
    String? category,
    bool isPublic = true,
  }) async {
    final response =
        await _client
            .from('resource_library')
            .insert({
              'counselor_id': counselorId,
              'title': title,
              'file_url': fileUrl,
              'file_type': fileType.toString(),
              'description': description,
              'category': category,
              'is_public': isPublic,
            })
            .select()
            .single();

    return ResourceModel.fromJson(response);
  }

  // ============================================
  // ANALYTICS
  // ============================================

  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final reports = await _client.from('reports').select('status');
      final counseling = await _client
          .from('counseling_requests')
          .select('status');

      final reportsList = reports as List? ?? [];
      final counselingList = counseling as List? ?? [];

      int totalReports = reportsList.length;
      int openCases =
          reportsList.where((r) => (r as Map)['status'] != 'settled').length;
      int resolvedCases =
          reportsList.where((r) => (r as Map)['status'] == 'settled').length;
      int activeCounseling =
          counselingList
              .where(
                (c) => c['status'] != 'completed' && c['status'] != 'cancelled',
              )
              .length;

      return {
        'total_reports': totalReports,
        'open_cases': openCases,
        'resolved_cases': resolvedCases,
        'active_counseling_requests': activeCounseling,
      };
    } catch (e) {
      return {
        'total_reports': 0,
        'open_cases': 0,
        'resolved_cases': 0,
        'active_counseling_requests': 0,
      };
    }
  }

  // ============================================
  // CASE MESSAGES (Communication Tools)
  // ============================================

  /// Create a case-based message.
  /// Application-level checks enforce role and case assignment (no RLS).
  Future<CaseMessageModel> createCaseMessage({
    required String caseId,
    required UserModel sender,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message cannot be empty');
    }
    if (trimmed.length > 4000) {
      throw Exception('Message exceeds 4000 characters limit');
    }

    // Only teachers, counselors, deans or admins may post
    if (sender.role != UserRole.teacher &&
        sender.role != UserRole.counselor &&
        sender.role != UserRole.dean &&
        sender.role != UserRole.admin) {
      throw Exception('Role not authorized to send messages');
    }

    // Verify case exists and requester is assigned
    final report = await getReportById(caseId);
    if (report == null) {
      throw Exception('Case not found');
    }
    // Allow posting if assigned OR if assignment is null (case is visible to them)
    // For teachers: must be assigned or teacher_id is null
    if (sender.role == UserRole.teacher &&
        report.teacherId != null &&
        report.teacherId != sender.id) {
      throw Exception('Teacher is not assigned to this case');
    }
    // For counselors: can post if assigned, or if forwarded/anonymous (counselor_id is null)
    if (sender.role == UserRole.counselor &&
        report.counselorId != null &&
        report.counselorId != sender.id) {
      // Allow if status is forwarded or if it's an anonymous report
      if (report.status != ReportStatus.forwarded && !report.isAnonymous) {
        throw Exception('Counselor is not assigned to this case');
      }
    }

    final response =
        await _client
            .from('case_messages')
            .insert({
              'case_id': caseId,
              'sender_id': sender.id,
              'sender_role': sender.role.toString(),
              'message': trimmed,
            })
            .select()
            .single();

    return CaseMessageModel.fromJson(response);
  }

  /// Fetch messages for a case in chronological order.
  /// Application-level checks enforce role and case assignment (no RLS).
  Future<List<CaseMessageModel>> getCaseMessages({
    required String caseId,
    required UserModel requester,
    int limit = 100,
    int offset = 0,
  }) async {
    if (requester.role != UserRole.teacher &&
        requester.role != UserRole.counselor &&
        requester.role != UserRole.dean &&
        requester.role != UserRole.admin) {
      throw Exception('Role not authorized to view messages');
    }

    // Verify case exists and requester is assigned
    final report = await getReportById(caseId);
    if (report == null) {
      throw Exception('Case not found');
    }
    // Allow viewing if assigned OR if assignment is null (case is visible to them)
    // For teachers: must be assigned or teacher_id is null
    if (requester.role == UserRole.teacher &&
        report.teacherId != null &&
        report.teacherId != requester.id) {
      throw Exception('Teacher is not assigned to this case');
    }
    // For counselors: can view if assigned, or if forwarded/anonymous (counselor_id is null)
    if (requester.role == UserRole.counselor &&
        report.counselorId != null &&
        report.counselorId != requester.id) {
      // Allow if status is forwarded or if it's an anonymous report
      if (report.status != ReportStatus.forwarded && !report.isAnonymous) {
        throw Exception('Counselor is not assigned to this case');
      }
    }

    // For deans: can view if assigned or overseeing
    if (requester.role == UserRole.dean &&
        report.deanId != null &&
        report.deanId != requester.id) {
      if (report.status != ReportStatus.counselorReviewed &&
          report.status != ReportStatus.forwarded) {
        throw Exception('Dean is not authorized for this case');
      }
    }

    final response = await _client
        .from('case_messages')
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: true)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => CaseMessageModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ============================================
  // ANONYMOUS CHAT SYSTEM
  // ============================================

  /// Create an anonymous report with case code for chat system
  Future<Map<String, dynamic>?> createAnonymousReport({
    required String category,
    required String description,
    required List<String> teacherIds,
    String? status,
  }) async {
    try {
      // Generate case code using the database function
      final caseCodeResponse = await _client.rpc('generate_case_code');
      final caseCode = caseCodeResponse as String? ?? _generateCaseCode();

      // Create the anonymous report
      final reportData = {
        'case_code': caseCode,
        'category': category,
        'description': description,
        'status': status ?? (teacherIds.isNotEmpty ? 'pending' : 'forwarded'),
      };

      final reportResponse =
          await _client
              .from('anonymous_reports')
              .insert(reportData)
              .select()
              .single();

      final reportId = reportResponse['id'] as String;

      // Assign recipients (teachers or counselors) to the report
      if (teacherIds.isNotEmpty) {
        // Fetch roles to split teachers and counselors
        final usersResponse = await _client
            .from('users')
            .select('id, role')
            .inFilter('id', teacherIds);

        final teachers = <String>[];
        final counselors = <String>[];

        for (final user in usersResponse as List) {
          final id = user['id'] as String;
          final role = user['role'] as String;
          if (role == 'counselor') {
            counselors.add(id);
          } else {
            teachers.add(id);
          }
        }

        if (teachers.isNotEmpty) {
          final assignments =
              teachers
                  .map((id) => {'report_id': reportId, 'teacher_id': id})
                  .toList();
          await _client.from('anonymous_report_teachers').insert(assignments);
        }

        if (counselors.isNotEmpty) {
          final assignments =
              counselors
                  .map((id) => {'report_id': reportId, 'counselor_id': id})
                  .toList();
          await _client.from('anonymous_report_counselors').insert(assignments);
        }
      }

      return {'id': reportId, 'case_code': caseCode};
    } catch (e) {
      debugPrint('Error creating anonymous chat report: $e');
      rethrow;
    }
  }

  /// Fallback case code generator (if RPC fails)
  String _generateCaseCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = StringBuffer('AR-');
    for (int i = 0; i < 6; i++) {
      code.write(chars[(random + i) % chars.length]);
    }
    return code.toString();
  }

  /// Get anonymous report by case code
  Future<Map<String, dynamic>?> getAnonymousReportByCaseCode(
    String caseCode,
  ) async {
    try {
      final response = await _client.rpc(
        'get_anonymous_report_by_case_code_public',
        params: {'p_case_code': caseCode},
      );

      if (response == null) return null;

      // The RPC function returns a JSON object, which needs to be cast to a Map.
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Error getting anonymous report by case code: $e');
      return null;
    }
  }

  /// Get the roles of users assigned to an anonymous report
  Future<List<String>> getAnonymousReportRecipientRoles(String reportId) async {
    try {
      final roles = <String>[];

      // 1. Check teacher assignments
      final teacherAssignments = await _client
          .from('anonymous_report_teachers')
          .select('teacher_id')
          .eq('report_id', reportId);

      if ((teacherAssignments as List).isNotEmpty) {
        // We know these are teachers (or users acting as teachers)
        // Ideally fetch roles, but for now we assume 'teacher' or fetch if needed.
        // The previous implementation fetched roles. Let's do that to be safe.
        final teacherIds =
            teacherAssignments.map((t) => t['teacher_id'] as String).toList();
        final teacherRoles = await _client
            .from('users')
            .select('role')
            .inFilter('id', teacherIds);
        roles.addAll(
          (teacherRoles as List).map((r) => r['role'] as String).toList(),
        );
      }

      // 2. Check counselor assignments
      final counselorAssignments = await _client
          .from('anonymous_report_counselors')
          .select('counselor_id')
          .eq('report_id', reportId);

      if ((counselorAssignments as List).isNotEmpty) {
        // These are definitely counselors
        roles.add('counselor');
      }

      return roles.toSet().toList(); // Deduplicate
    } catch (e) {
      debugPrint('Error getting recipient roles: $e');
      return [];
    }
  }

  /// Send a message in anonymous chat
  Future<void> sendAnonymousMessage({
    required String reportId,
    required String senderType, // 'anonymous' or 'teacher'
    String? senderId, // Only for teachers
    required String message,
  }) async {
    try {
      await _client.from('anonymous_messages').insert({
        'report_id': reportId,
        'sender_type': senderType,
        'sender_id': senderId,
        'message': message,
        'is_read': false,
      });

      // Update report status to 'ongoing' if it's pending/forwarded (only if teacher/counselor picks up)
      if (senderType == 'teacher' || senderType == 'counselor') {
        await _client
            .from('anonymous_reports')
            .update({'status': 'ongoing'})
            .eq('id', reportId)
            .inFilter('status', ['pending', 'forwarded']);
      }
    } catch (e) {
      debugPrint('Error sending anonymous message: $e');
      rethrow;
    }
  }

  /// Get messages for an anonymous report
  Future<List<Map<String, dynamic>>> getAnonymousMessages(
    String reportId,
  ) async {
    try {
      final response = await _client
          .from('anonymous_messages')
          .select()
          .eq('report_id', reportId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting anonymous messages: $e');
      return [];
    }
  }

  /// Mark messages as read for a teacher
  Future<void> markAnonymousMessagesAsRead({
    required String reportId,
    required String teacherId,
  }) async {
    try {
      await _client
          .from('anonymous_messages')
          .update({'is_read': true})
          .eq('report_id', reportId)
          .eq('sender_type', 'anonymous')
          .isFilter('sender_id', null);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Get all anonymous reports for a teacher
  Future<List<Map<String, dynamic>>> getTeacherAnonymousReports(
    String teacherId,
  ) async {
    try {
      final response = await _client
          .from('anonymous_report_teachers')
          .select('''
            id,
            report_id,
            assigned_at,
            anonymous_reports (
              id,
              case_code,
              category,
              description,
              status,
              created_at,
              updated_at
            )
          ''')
          .eq('teacher_id', teacherId)
          .order('assigned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting teacher anonymous reports: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCounselorAnonymousReports(
    String counselorId,
  ) async {
    try {
      // 1. Get reports where specifically assigned as counselor_id
      final directResponse = await _client
          .from('anonymous_reports')
          .select()
          .eq('counselor_id', counselorId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> directReports =
          (directResponse as List).map((report) {
            return {
              'id': report['id'],
              'report_id': report['id'],
              'assigned_at': report['created_at'],
              'anonymous_reports': report,
            };
          }).toList();

      // 2. Get reports where notified via anonymous_report_counselors
      final notifiedResponse = await _client
          .from('anonymous_report_counselors')
          .select('''
            id,
            report_id,
            assigned_at,
            anonymous_reports (
              id,
              case_code,
              category,
              description,
              status,
              created_at,
              updated_at,
              teacher_note,
              counselor_id
            )
          ''')
          .eq('counselor_id', counselorId)
          .order('assigned_at', ascending: false);

      final List<Map<String, dynamic>> notifiedReports =
          List<Map<String, dynamic>>.from(notifiedResponse);

      // 3. Combine and deduplicate by report_id
      final Map<String, Map<String, dynamic>> combined = {};

      for (var r in directReports) {
        combined[r['report_id']] = r;
      }

      for (var r in notifiedReports) {
        if (!combined.containsKey(r['report_id'])) {
          combined[r['report_id']] = r;
        }
      }

      final result = combined.values.toList();
      result.sort(
        (a, b) =>
            (b['assigned_at'] as String).compareTo(a['assigned_at'] as String),
      );

      return result;
    } catch (e) {
      debugPrint('Error getting counselor anonymous reports: $e');
      return [];
    }
  }

  /// Get unread message count for a teacher
  Future<int> getTeacherUnreadCount(String teacherId) async {
    try {
      final response = await _client.rpc(
        'get_teacher_unread_count',
        params: {'p_teacher_id': teacherId},
      );
      return response as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting teacher unread count: $e');
      return 0;
    }
  }

  /// Get teachers assigned to an anonymous report
  Future<List<Map<String, dynamic>>> getReportTeachers(String reportId) async {
    try {
      final response = await _client
          .from('anonymous_report_teachers')
          .select('''
            id,
            teacher_id,
            assigned_at,
            users:teacher_id (
              id,
              full_name,
              gmail
            )
          ''')
          .eq('report_id', reportId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting report teachers: $e');
      return [];
    }
  }

  // ============================================
  // ADMIN REPORT ANALYTICS
  // ============================================

  /// Get comprehensive analytics for admin dashboard
  Future<Map<String, dynamic>> getReportAnalytics() async {
    try {
      // Get total reports count
      final totalCount = await _client.from('reports').count();
      final totalReports = totalCount;

      // Get active reports count (not settled or completed)
      final activeCount = await _client
          .from('reports')
          .count()
          .not('status', 'in', '(settled,completed)');
      final activeReports = activeCount;

      // Get resolved reports
      final resolvedReports = totalReports - activeReports;

      // Get reports by status
      final statusResponse = await _client.from('reports').select('status');

      final reportsByStatus = <String, int>{};
      for (final row in statusResponse as List) {
        final status = row['status'] as String;
        reportsByStatus[status] = (reportsByStatus[status] ?? 0) + 1;
      }

      // Get reports by department (from teacher/counselor)
      final reportsByDepartment = <String, int>{};

      // Get monthly trends (last 6 months)
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final trendsResponse = await _client
          .from('reports')
          .select('created_at')
          .gte('created_at', sixMonthsAgo.toIso8601String())
          .order('created_at', ascending: true);

      final monthlyTrends = <String, int>{};
      for (final row in trendsResponse as List) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        final monthKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        monthlyTrends[monthKey] = (monthlyTrends[monthKey] ?? 0) + 1;
      }

      return {
        'totalReports': totalReports,
        'activeReports': activeReports,
        'resolvedReports': resolvedReports,
        'reportsByStatus': reportsByStatus,
        'reportsByDepartment': reportsByDepartment,
        'monthlyTrends': monthlyTrends,
      };
    } catch (e) {
      debugPrint('Error getting report analytics: $e');
      return {
        'totalReports': 0,
        'activeReports': 0,
        'resolvedReports': 0,
        'reportsByStatus': <String, int>{},
        'reportsByDepartment': <String, int>{},
        'monthlyTrends': <String, int>{},
      };
    }
  }

  /// Get all reports for admin with participant details
  Future<List<Map<String, dynamic>>> getAllReportsForAdmin() async {
    try {
      // 1. Fetch Standard Reports (raw)
      final reportsResponse = await _client
          .from('reports')
          .select('*')
          .order('created_at', ascending: false);

      final reports = List<Map<String, dynamic>>.from(reportsResponse);

      // 2. Fetch Anonymous Reports
      final anonymousResponse = await _client
          .from('anonymous_reports')
          .select('*')
          .order('created_at', ascending: false);

      // Collect all User IDs to fetch details in one go
      final userIds = <String>{};
      for (var r in reports) {
        if (r['student_id'] != null) userIds.add(r['student_id']);
        if (r['teacher_id'] != null) userIds.add(r['teacher_id']);
        if (r['counselor_id'] != null) userIds.add(r['counselor_id']);
        if (r['dean_id'] != null) userIds.add(r['dean_id']);
      }

      // Fetch Users
      final Map<String, Map<String, dynamic>> userMap = {};
      if (userIds.isNotEmpty) {
        final usersResponse = await _client
            .from('users')
            .select('id, full_name, role, department, student_level')
            .filter('id', 'in', '(${userIds.map((id) => '"$id"').join(',')})');

        for (var u in usersResponse) {
          userMap[u['id'] as String] = u;
        }
      }

      // 3. Process Standard Reports with joined data
      final processedReports =
          reports.map((r) {
            return {
              ...r,
              'student':
                  userMap[r['student_id']] ?? {'full_name': 'Unknown Student'},
              'teacher':
                  userMap[r['teacher_id']] ?? {'full_name': 'Not Assigned'},
              'counselor':
                  userMap[r['counselor_id']] ?? {'full_name': 'Not Assigned'},
              'dean': userMap[r['dean_id']] ?? {'full_name': 'Not Assigned'},
              'is_anonymous': false,
            };
          }).toList();

      // 4. Process Anonymous Reports
      final processedAnonymous =
          (anonymousResponse as List).map((e) {
            return {
              'id': e['id'],
              'title': e['category'] ?? 'Anonymous Report',
              'description': e['description'],
              'status': e['status'] ?? 'pending',
              'created_at': e['created_at'],
              'is_anonymous': true,
              'student_id': null,
              'student': {'full_name': 'Anonymous User'},
              'teacher_id': null,
              'teacher': {'full_name': 'Not Assigned'},
              'counselor_id': e['counselor_id'],
              'counselor':
                  userMap[e['counselor_id']] ?? {'full_name': 'Not Assigned'},
              'dean_id': null,
              'dean': {'full_name': 'Not Assigned'},
              'tracking_id': e['case_code'],
              'type': e['category'] ?? 'General',
            };
          }).toList();

      // 5. Combine and Sort
      final allReports = [...processedReports, ...processedAnonymous];
      allReports.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      return allReports;
    } catch (e) {
      debugPrint('Error getting all reports for admin: $e');
      return [];
    }
  }

  /// Get recent reports for admin dashboard
  Future<List<Map<String, dynamic>>> getRecentReports({int limit = 5}) async {
    try {
      // 1. Fetch Standard Reports (raw)
      final reportsResponse = await _client
          .from('reports')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      final reports = List<Map<String, dynamic>>.from(reportsResponse);

      // 2. Fetch Anonymous Reports
      final anonymousResponse = await _client
          .from('anonymous_reports')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      // Collect all User IDs to fetch details in one go
      final userIds = <String>{};
      for (var r in reports) {
        if (r['student_id'] != null) userIds.add(r['student_id']);
        if (r['teacher_id'] != null) userIds.add(r['teacher_id']);
        if (r['counselor_id'] != null) userIds.add(r['counselor_id']);
        if (r['dean_id'] != null) userIds.add(r['dean_id']);
      }

      // Fetch Users
      final Map<String, Map<String, dynamic>> userMap = {};
      if (userIds.isNotEmpty) {
        final usersResponse = await _client
            .from('users')
            .select('id, full_name, role, department')
            .filter('id', 'in', '(${userIds.join(',')})');

        for (var u in usersResponse) {
          userMap[u['id'] as String] = u;
        }
      }

      // 3. Process Standard Reports with joined data
      final processedReports =
          reports.map((r) {
            return {
              ...r,
              'student':
                  userMap[r['student_id']] ?? {'full_name': 'Unknown Student'},
              'teacher':
                  userMap[r['teacher_id']] ?? {'full_name': 'Not Assigned'},
              'counselor':
                  userMap[r['counselor_id']] ?? {'full_name': 'Not Assigned'},
              'dean': userMap[r['dean_id']] ?? {'full_name': 'Not Assigned'},
              'is_anonymous': false,
            };
          }).toList();

      // 4. Process Anonymous Reports
      final processedAnonymous =
          (anonymousResponse as List).map((e) {
            return {
              'id': e['id'],
              'title': e['category'] ?? 'Anonymous Report',
              'description': e['description'],
              'status': e['status'] ?? 'pending',
              'created_at': e['created_at'],
              'is_anonymous': true,
              'student_id': null,
              'student': {'full_name': 'Anonymous User'},
              'teacher_id': null,
              'teacher': {'full_name': 'Not Assigned'},
              'counselor_id': e['counselor_id'],
              'counselor':
                  userMap[e['counselor_id']] ?? {'full_name': 'Not Assigned'},
              'dean_id': null,
              'dean': {'full_name': 'Not Assigned'},
              'tracking_id': e['case_code'],
              'type': e['category'] ?? 'General',
            };
          }).toList();

      // 5. Combine and Sort and Limit
      final allReports = [...processedReports, ...processedAnonymous];
      allReports.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      return allReports.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting recent reports: $e');
      return [];
    }
  }

  /// Get reports with advanced filters for admin
  /// Get reports with advanced filters for admin
  Future<List<Map<String, dynamic>>> getReportsWithAdvancedFilters({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? roleFilter, // 'teacher', 'counselor', 'dean'
    bool? isAnonymous,
    String? department,
  }) async {
    try {
      final allReports = await getAllReportsForAdmin();

      final filtered =
          allReports.where((report) {
            // 1. Date filter
            if (startDate != null || endDate != null) {
              final createdAt = DateTime.parse(report['created_at'] as String);
              if (startDate != null && createdAt.isBefore(startDate)) {
                return false;
              }
              // Add 23:59:59 to endDate to include the whole day
              if (endDate != null) {
                final endLimit = DateTime(
                  endDate.year,
                  endDate.month,
                  endDate.day,
                  23,
                  59,
                  59,
                );
                if (createdAt.isAfter(endLimit)) return false;
              }
            }

            // 2. Status filter
            if (status != null && status.isNotEmpty) {
              final reportStatus = report['status']?.toString().toLowerCase();
              if (reportStatus != status.toLowerCase()) return false;
            }

            // 3. Anonymous filter
            if (isAnonymous != null) {
              if (report['is_anonymous'] != isAnonymous) return false;
            }

            // 4. Role Assignment filter
            if (roleFilter != null && roleFilter.isNotEmpty) {
              switch (roleFilter.toLowerCase()) {
                case 'teacher':
                  if (report['teacher_id'] == null) return false;
                  break;
                case 'counselor':
                  if (report['counselor_id'] == null) return false;
                  break;
                case 'dean':
                  if (report['dean_id'] == null) return false;
                  break;
              }
            }

            // 5. Department filter
            if (department != null && department.isNotEmpty) {
              final student = report['student'] as Map<String, dynamic>?;
              final teacher = report['teacher'] as Map<String, dynamic>?;
              final counselor = report['counselor'] as Map<String, dynamic>?;

              bool match =
                  (student?['department'] == department) ||
                  (teacher?['department'] == department) ||
                  (counselor?['department'] == department);
              if (!match) return false;
            }

            return true;
          }).toList();

      return filtered;
    } catch (e) {
      debugPrint('Error getting reports with filters: $e');
      return [];
    }
  }

  /// Search reports by case code, participant names, or category
  /// Search reports by case code, participant names, category, or title
  Future<List<Map<String, dynamic>>> searchReports(String searchQuery) async {
    try {
      final allReports = await getAllReportsForAdmin();

      if (searchQuery.isEmpty) {
        return allReports;
      }

      final searchLower = searchQuery.toLowerCase();
      final filtered =
          allReports.where((report) {
            // 1. Search in tracking_id / case code
            final trackingId = report['tracking_id'] as String?;
            if (trackingId != null &&
                trackingId.toLowerCase().contains(searchLower)) {
              return true;
            }

            // 2. Search in title and category / type
            final title = report['title'] as String?;
            final type = report['type'] as String?;
            if ((title != null && title.toLowerCase().contains(searchLower)) ||
                (type != null && type.toLowerCase().contains(searchLower))) {
              return true;
            }

            // 3. Search in description
            final description = report['description'] as String?;
            if (description != null &&
                description.toLowerCase().contains(searchLower)) {
              return true;
            }

            // 4. Search in participant names (student, teacher, counselor)
            final student = report['student'] as Map<String, dynamic>?;
            final studentName = student?['full_name'] as String?;
            if (studentName != null &&
                studentName.toLowerCase().contains(searchLower)) {
              return true;
            }

            final teacher = report['teacher'] as Map<String, dynamic>?;
            final teacherName = teacher?['full_name'] as String?;
            if (teacherName != null &&
                teacherName.toLowerCase().contains(searchLower)) {
              return true;
            }

            final counselor = report['counselor'] as Map<String, dynamic>?;
            final counselorName = counselor?['full_name'] as String?;
            if (counselorName != null &&
                counselorName.toLowerCase().contains(searchLower)) {
              return true;
            }

            return false;
          }).toList();

      return filtered;
    } catch (e) {
      debugPrint('Error searching reports: $e');
      return [];
    }
  }

  /// Get complete case record details for admin
  Future<Map<String, dynamic>?> getCaseRecordDetail(String reportId) async {
    try {
      // Get report with all participant details
      final reportResponse =
          await _client
              .from('reports')
              .select('*')
              .eq('id', reportId)
              .maybeSingle();

      if (reportResponse == null) {
        return null;
      }

      // Get case messages
      final messagesResponse = await _client
          .from('case_messages')
          .select('''
            *,
            sender:sender_id(id, full_name, role)
          ''')
          .eq('case_id', reportId)
          .order('created_at', ascending: true);

      // Get activity logs
      final logsResponse = await _client
          .from('report_activity_logs')
          .select('''
            *,
            actor:actor_id(id, full_name, role)
          ''')
          .eq('report_id', reportId)
          .order('created_at', ascending: true);

      return {
        'report': reportResponse,
        'messages': List<Map<String, dynamic>>.from(messagesResponse),
        'activityLogs': List<Map<String, dynamic>>.from(logsResponse),
      };
    } catch (e) {
      debugPrint('Error getting case record detail: $e');
      return null;
    }
  }

  // ============================================
  // NOTIFICATIONS
  // ============================================

  /// Get notifications for a user
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map(
            (json) => NotificationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsAsRead(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Stream notifications for real-time updates
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (data) =>
              data.map((json) => NotificationModel.fromJson(json)).toList(),
        );
  }
  // ============================================
  // BACKUP & RESTORE (ADMIN)
  // ============================================

  Future<String> createBackupJob({
    required String backupType,
    String? description,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final response =
        await _client
            .from('backup_jobs')
            .insert({
              'created_by': user.id,
              'backup_type': backupType,
              'description': description,
            })
            .select()
            .single();

    return response['id'] as String;
  }

  Future<void> saveBackupRecords({
    required String jobId,
    required String tableName,
    required List<Map<String, dynamic>> records,
  }) async {
    if (records.isEmpty) return;

    // Map records to backup_records format
    final backupEntries =
        records
            .map(
              (r) => {
                'backup_job_id': jobId,
                'table_name': tableName,
                'record_data': r,
              },
            )
            .toList();

    await _client.from('backup_records').insert(backupEntries);
  }

  Future<List<Map<String, dynamic>>> getTableData(String tableName) async {
    final response = await _client.from(tableName).select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBackupJobs() async {
    final response = await _client
        .from('backup_jobs')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBackupRecords(String jobId) async {
    final response = await _client
        .from('backup_records')
        .select()
        .eq('backup_job_id', jobId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> restoreRecord({
    required String tableName,
    required Map<String, dynamic> recordData,
  }) async {
    // Upsert to overwrite existing, checking for conflict if possible?
    // Supabase .upsert handles it if PK is present.
    await _client.from(tableName).upsert(recordData);
  }

  // ============================================
  // AI-ASSISTED SUPPORT CHAT
  // ============================================

  /// Create or get a support session for a student
  Future<SupportSessionModel> createSupportSession({
    String? studentId,
    String? studentName,
    String? category,
  }) async {
    try {
      // Check for active session if studentId is provided
      if (studentId != null) {
        final existing =
            await _client
                .from('support_sessions')
                .select()
                .eq('student_id', studentId)
                .neq('status', 'resolved')
                .maybeSingle();

        if (existing != null) {
          return SupportSessionModel.fromJson(existing);
        }
      }

      final data = {
        'student_id': studentId,
        'student_name': studentName ?? 'Guest Student',
        'category': category ?? 'General Support',
        'status': 'ai_active',
      };

      final response =
          await _client.from('support_sessions').insert(data).select().single();

      return SupportSessionModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating support session: $e');
      rethrow;
    }
  }

  /// Get messages for a support session
  Future<List<SupportMessageModel>> getSupportMessages(String sessionId) async {
    try {
      final response = await _client
          .from('support_messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => SupportMessageModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting support messages: $e');
      return [];
    }
  }

  /// Send a message in a support session
  Future<void> sendSupportMessage({
    required String sessionId,
    String? senderId,
    required String senderRole,
    required String message,
    String messageType = 'text',
  }) async {
    try {
      await _client.from('support_messages').insert({
        'session_id': sessionId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'message': message,
        'message_type': messageType,
      });

      // AI response is now handled by SupportChatProvider using OpenAI service
      /* 
      if (senderRole == 'student') {
        final session =
            await _client
                .from('support_sessions')
                .select('status')
                .eq('id', sessionId)
                .single();

        if (session['status'] == 'ai_active') {
          // Delayed AI response simulation
          _triggerAiResponse(sessionId, message);
        }
      }
      */

      // Update session timestamp
      await _client
          .from('support_sessions')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', sessionId);
    } catch (e) {
      debugPrint('Error sending support message: $e');
      rethrow;
    }
  }

  /* 
  /// AI Logic (MVP) - Deprecated in favor of OpenAI in SupportChatProvider
  Future<void> _triggerAiResponse(
    String sessionId,
    String studentMessage,
  ) async {
    ...
  }

  bool _isMessageUrgent(String message) {
    ...
  }
  */

  Future<void> updateSupportSessionStatus(
    String sessionId,
    SupportSessionStatus status,
  ) async {
    try {
      await _client
          .from('support_sessions')
          .update({
            'status': status.toDbString(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (e) {
      debugPrint('Error updating support session status: $e');
    }
  }

  /// Mark a session as urgent (for AI escalation)
  Future<void> markSessionUrgent(String sessionId) async {
    try {
      await _client
          .from('support_sessions')
          .update({
            'is_urgent': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (e) {
      debugPrint('Error marking session as urgent: $e');
    }
  }

  /// Stream support messages for real-time chat
  Stream<List<SupportMessageModel>> streamSupportMessages(String sessionId) {
    return _client
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at', ascending: true)
        .map(
          (data) =>
              data.map((json) => SupportMessageModel.fromJson(json)).toList(),
        );
  }

  /// Get all support sessions for communication tools
  Future<List<SupportSessionModel>> getSupportSessions() async {
    try {
      final response = await _client
          .from('support_sessions')
          .select()
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => SupportSessionModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching support sessions: $e');
      return [];
    }
  }
}
