// No longer using foundation in this model

class UserActivityLog {
  final String id;
  final String userId;
  final String action;
  final DateTime timestamp;
  final String? userName;
  final String? userRole;
  final String? userEmail;

  UserActivityLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.timestamp,
    this.userName,
    this.userRole,
    this.userEmail,
  });

  factory UserActivityLog.fromJson(Map<String, dynamic> json) {
    String? name;
    String? role;
    String? email;

    // Handle joined user data
    if (json['users'] != null) {
      final userData = json['users'];
      if (userData is Map<String, dynamic>) {
        name = userData['full_name'] as String?;
        role = userData['role'] as String?;
        email = userData['gmail'] as String?;
      }
    }

    return UserActivityLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      action: json['action'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      userName: name,
      userRole: role,
      userEmail: email,
    );
  }
}
