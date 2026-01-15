import '../models/user_model.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseService _supabase = SupabaseService();

  /// Sign in with Google OAuth
  /// Returns user if email is registered, null otherwise
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Initiate Google OAuth
      final success = await _supabase.signInWithGoogle();
      if (!success) return null;

      // Wait for auth state change to get the email
      // Note: In production, handle OAuth callback properly
      return null; // Will be handled by auth state listener
    } catch (e) {
      return null;
    }
  }

  /// Sign in with email and password
  Future<UserModel?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      // Sign in with Supabase auth
      final authUser = await _supabase.signInWithEmailPassword(
        email.toLowerCase().trim(),
        password,
      );

      if (authUser == null) {
        throw Exception('Invalid email or password.');
      }

      // Check if email is confirmed
      if (authUser.emailConfirmedAt == null) {
        throw Exception(
          'Email not confirmed. Please contact your administrator to confirm your account.',
        );
      }

      // Get user profile from users table
      final user = await _supabase.getCurrentUserProfile();
      if (user == null) {
        throw Exception(
          'User profile not found. Please contact your administrator.',
        );
      }

      // Update last login
      await _supabase.updateLastLogin(user.id);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if email is registered and sign in
  Future<UserModel?> signInWithGmail(String gmail) async {
    try {
      // Check if email exists in users table
      final exists = await _supabase.checkGmailExists(gmail);
      if (!exists) {
        throw Exception('Email not found. Please contact your administrator.');
      }

      // Get user by email
      final user = await _supabase.getUserByGmail(gmail);
      if (user != null) {
        // Update last login
        await _supabase.updateLastLogin(user.id);
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  /// Handle OAuth callback - check email and return user
  Future<UserModel?> handleAuthCallback() async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser?.email == null) return null;

      final gmail = currentUser!.email!;

      // Link auth user to users table if needed
      await _supabase.linkAuthUserToProfile(currentUser.id, gmail);

      return await signInWithGmail(gmail);
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _supabase.signOut();
  }

  Future<UserModel?> getCurrentUser() async {
    return await _supabase.getCurrentUserProfile();
  }
}
