// No longer using intl in this model

enum SupportSessionStatus {
  aiActive,
  humanActive,
  resolved;

  @override
  String toString() => name;

  static SupportSessionStatus fromString(String value) {
    if (value == 'ai_active') return SupportSessionStatus.aiActive;
    if (value == 'human_active') return SupportSessionStatus.humanActive;

    return SupportSessionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SupportSessionStatus.aiActive,
    );
  }

  String get displayName {
    switch (this) {
      case SupportSessionStatus.aiActive:
        return 'AI Assistant Active';
      case SupportSessionStatus.humanActive:
        return 'Counselor Online';
      case SupportSessionStatus.resolved:
        return 'Resolved';
    }
  }

  String toDbString() {
    switch (this) {
      case SupportSessionStatus.aiActive:
        return 'ai_active';
      case SupportSessionStatus.humanActive:
        return 'human_active';
      case SupportSessionStatus.resolved:
        return 'resolved';
    }
  }
}

class SupportSessionModel {
  final String id;
  final String? studentId;
  final String? studentName;
  final String category;
  final SupportSessionStatus status;
  final bool isUrgent;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportSessionModel({
    required this.id,
    this.studentId,
    this.studentName,
    required this.category,
    required this.status,
    required this.isUrgent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportSessionModel.fromJson(Map<String, dynamic> json) {
    return SupportSessionModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String?,
      studentName: json['student_name'] as String?,
      category: json['category'] as String? ?? 'General Support',
      status: SupportSessionStatus.fromString(
        json['status'] as String? ?? 'ai_active',
      ),
      isUrgent: json['is_urgent'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'category': category,
      'status': status.name,
      'is_urgent': isUrgent,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class SupportMessageModel {
  final String id;
  final String sessionId;
  final String? senderId;
  final String senderRole; // student, teacher, counselor, ai
  final String message;
  final String messageType; // text, ai_assistance
  final bool isRead;
  final DateTime createdAt;

  SupportMessageModel({
    required this.id,
    required this.sessionId,
    this.senderId,
    required this.senderRole,
    required this.message,
    required this.messageType,
    required this.isRead,
    required this.createdAt,
  });

  factory SupportMessageModel.ai({
    required String sessionId,
    required String message,
  }) {
    return SupportMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: sessionId,
      senderId: null,
      senderRole: 'ai',
      message: message,
      messageType: 'ai_assistance',
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      senderId: json['sender_id'] as String?,
      senderRole: json['sender_role'] as String,
      message: json['message'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message': message,
      'message_type': messageType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
