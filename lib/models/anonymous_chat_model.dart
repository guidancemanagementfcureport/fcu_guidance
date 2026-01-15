class AnonymousReport {
  final String id;
  final String caseCode;
  final String category;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnonymousReport({
    required this.id,
    required this.caseCode,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnonymousReport.fromJson(Map<String, dynamic> json) {
    return AnonymousReport(
      id: json['id'] as String,
      caseCode: json['case_code'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_code': caseCode,
      'category': category,
      'description': description,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class AnonymousMessage {
  final String id;
  final String reportId;
  final String senderType; // 'anonymous' or 'teacher'
  final String? senderId; // Only for teachers
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AnonymousMessage({
    required this.id,
    required this.reportId,
    required this.senderType,
    this.senderId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AnonymousMessage.fromJson(Map<String, dynamic> json) {
    return AnonymousMessage(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      senderType: json['sender_type'] as String,
      senderId: json['sender_id'] as String?,
      message: json['message'] as String,
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'sender_type': senderType,
      'sender_id': senderId,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isFromAnonymous => senderType == 'anonymous';
  bool get isFromTeacher => senderType == 'teacher';
}

class AnonymousReportTeacher {
  final String id;
  final String reportId;
  final String teacherId;
  final DateTime assignedAt;

  AnonymousReportTeacher({
    required this.id,
    required this.reportId,
    required this.teacherId,
    required this.assignedAt,
  });

  factory AnonymousReportTeacher.fromJson(Map<String, dynamic> json) {
    return AnonymousReportTeacher(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      teacherId: json['teacher_id'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'teacher_id': teacherId,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }
}

