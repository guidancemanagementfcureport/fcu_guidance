class ReportActivityLog {
  final String id;
  final String reportId;
  final String actorId; // Teacher or counselor who performed the action
  final String role; // "student", "teacher", "counselor"
  final String action; // "submitted", "reviewed", "forwarded", "accepted", "confirmed"
  final String? note; // Optional comment/note
  final DateTime timestamp;

  ReportActivityLog({
    required this.id,
    required this.reportId,
    required this.actorId,
    required this.role,
    required this.action,
    this.note,
    required this.timestamp,
  });

  factory ReportActivityLog.fromJson(Map<String, dynamic> json) {
    return ReportActivityLog(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      actorId: json['actor_id'] as String,
      role: json['role'] as String,
      action: json['action'] as String,
      note: json['note'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'actor_id': actorId,
      'role': role,
      'action': action,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

