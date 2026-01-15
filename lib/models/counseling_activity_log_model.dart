class CounselingActivityLog {
  final String id;
  final String counselingId;
  final String actorId;
  final String action; // 'requested', 'confirmed', 'settled'
  final String? note;
  final DateTime timestamp;
  final String? actorName; // Joined from users table

  CounselingActivityLog({
    required this.id,
    required this.counselingId,
    required this.actorId,
    required this.action,
    this.note,
    required this.timestamp,
    this.actorName,
  });

  factory CounselingActivityLog.fromJson(Map<String, dynamic> json) {
    return CounselingActivityLog(
      id: json['id'] as String,
      counselingId: json['counseling_id'] as String,
      actorId: json['actor_id'] as String,
      action: json['action'] as String,
      note: json['note'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      actorName: json['users'] != null && json['users']['full_name'] != null
          ? json['users']['full_name'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'counseling_id': counselingId,
      'actor_id': actorId,
      'action': action,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

