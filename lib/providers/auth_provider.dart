import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseService _supabase = SupabaseService();

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _supabase.authStateChanges.listen((authState) async {
      // IMPORTANT: Ignore auth state changes during user creation to prevent auto-login
      if (_supabase.isCreatingUser) {
        debugPrint('Ignoring auth state change - user creation in progress');
        return;
      }

      final event = authState.event;
      if (event.toString().contains('signedIn') ||
          event.toString().contains('userUpdated')) {
        // Check if email is registered
        final currentAuthUser = _supabase.currentUser;
        if (currentAuthUser?.email != null) {
          try {
            // Link auth user to users table if needed
            await _supabase.linkAuthUserToProfile(
              currentAuthUser!.id,
              currentAuthUser.email!,
            );

            final user = await _authService.signInWithGmail(
              currentAuthUser.email!,
            );
            if (user != null) {
              _currentUser = user;
              notifyListeners();
            } else {
              // Email not registered, sign out
              await signOut();
            }
          } catch (e) {
            debugPrint('Email check error: $e');
            await signOut();
          }
        }
      } else if (event.toString().contains('signedOut') ||
          event.toString().contains('userDeleted')) {
        // Only clear current user if we're not creating a user
        if (!_supabase.isCreatingUser) {
          _currentUser = null;
          notifyListeners();
        }
      }
    });

    // Load current user if already signed in
    if (_supabase.currentUser != null) {
      await loadCurrentUser();
    }
  }

  /// Sign in with Google OAuth
  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
      // OAuth will trigger auth state change, which will check Gmail
      _isLoading = false;
      notifyListeners();
      return null; // Success, handled by auth state listener
    } catch (e) {
      debugPrint('Google sign in error: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  /// Sign in with email and password
  Future<String?> signInWithEmailPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithEmailPassword(email, password);
      _isLoading = false;
      notifyListeners();

      if (user != null) {
        _currentUser = user;
        // Log activity
        _supabase.logActivity(userId: user.id, action: 'User Logged In');
        // Delay notification to allow toast to show on login page first
        // The login page will handle navigation after showing the toast
        Future.delayed(const Duration(milliseconds: 2000), () {
          notifyListeners();
        });
        return null; // Success
      } else {
        return 'Invalid email or password.';
      }
    } catch (e) {
      debugPrint('Sign in error: $e');
      _isLoading = false;
      notifyListeners();

      // Provide user-friendly error messages
      String errorMessage = e.toString().replaceAll('Exception: ', '');

      if (e.toString().contains('email_not_confirmed') ||
          e.toString().contains('Email not confirmed')) {
        errorMessage =
            'Email not confirmed. Please contact your administrator to confirm your account.';
      } else if (e.toString().contains('Invalid login credentials') ||
          e.toString().contains('invalid_credentials') ||
          e.toString().contains('Invalid email or password')) {
        errorMessage =
            'Invalid email or password. Please check your credentials and try again.';
      } else if (e.toString().contains('User profile not found')) {
        errorMessage =
            'User profile not found. Please contact your administrator.';
      }

      return errorMessage;
    }
  }

  /// Sign in with Magic Link
  Future<String?> signInWithMagicLink(String gmail) async {
    _isLoading = true;
    notifyListeners();

    try {
      // First check if email is registered
      final exists = await _supabase.checkGmailExists(gmail);
      if (!exists) {
        _isLoading = false;
        notifyListeners();
        return 'Email not found. Please contact your administrator.';
      }

      // Send magic link
      final success = await _supabase.sendMagicLink(gmail);
      _isLoading = false;
      notifyListeners();

      if (success) {
        return null; // Success, user will receive email
      } else {
        return 'Failed to send magic link. Please try again.';
      }
    } catch (e) {
      debugPrint('Magic link error: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();
    _currentUser = null;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCurrentUser() async {
    try {
      final currentAuthUser = _supabase.currentUser;
      if (currentAuthUser?.email != null) {
        // Link auth user to users table if needed
        await _supabase.linkAuthUserToProfile(
          currentAuthUser!.id,
          currentAuthUser.email!,
        );

        // Verify email is registered
        final user = await _authService.signInWithGmail(currentAuthUser.email!);
        _currentUser = user;
      } else {
        _currentUser = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Load current user error: $e');
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    await loadCurrentUser();
  }

  /// Update current user profile
  Future<String?> updateProfile({
    String? fullName,
    StudentLevel? studentLevel,
    String? course,
    String? gradeLevel,
    String? strand,
    String? section,
    String? yearLevel,
    String? department,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return 'Not authenticated';

    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = await _supabase.updateUser(
        userId: _currentUser!.id,
        fullName: fullName,
        studentLevel: studentLevel,
        course: course,
        gradeLevel: gradeLevel,
        strand: strand,
        section: section,
        yearLevel: yearLevel,
        department: department,
        avatarUrl: avatarUrl,
      );

      if (updatedUser != null) {
        _currentUser = updatedUser;
        _isLoading = false;
        notifyListeners();
        return null; // Success
      } else {
        _isLoading = false;
        notifyListeners();
        return 'Failed to update profile.';
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  /// Upload avatar image
  Future<String?> uploadAvatar(Uint8List bytes, String extension) async {
    if (_currentUser == null) return null;
    return await _supabase.uploadAvatar(
      userId: _currentUser!.id,
      bytes: bytes,
      extension: extension,
    );
  }
}
