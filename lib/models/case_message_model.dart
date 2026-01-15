class CaseMessageModel {
  final String id;
  final String caseId;
  final String senderId;
  final String senderRole; // teacher or counselor
  final String message;
  final DateTime createdAt;

  CaseMessageModel({
    required this.id,
    required this.caseId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  factory CaseMessageModel.fromJson(Map<String, dynamic> json) {
    return CaseMessageModel(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
