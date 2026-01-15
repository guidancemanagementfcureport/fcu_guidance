class ReportModel {
  final String id;
  final String? studentId; // Nullable for anonymous reports
  final String? teacherId;
  final String? counselorId;
  final String? deanId; // Dean who approved the report
  final String title;
  final String type; // Type of report (bullying, academic concern, etc.)
  final String details;
  final String? attachmentUrl; // Optional file attachment
  final DateTime? incidentDate; // Date & time of incident
  final ReportStatus status;
  final bool isAnonymous;
  final String? trackingId; // Tracking ID for anonymous reports
  // Internal notes (not visible to students)
  final String? teacherNote;
  final String? counselorNote;
  final String? deanNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    this.studentId, // Nullable for anonymous reports
    this.teacherId,
    this.counselorId,
    this.deanId,
    required this.title,
    required this.type,
    required this.details,
    this.attachmentUrl,
    this.incidentDate,
    this.status = ReportStatus.submitted,
    this.isAnonymous = false,
    this.trackingId,
    this.teacherNote,
    this.counselorNote,
    this.deanNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      counselorId: json['counselor_id'] as String?,
      deanId: json['dean_id'] as String?,
      title: json['title'] as String,
      type: json['type'] as String? ?? 'other',
      details: json['details'] as String,
      attachmentUrl: json['attachment_url'] as String?,
      incidentDate:
          json['incident_date'] != null
              ? DateTime.parse(json['incident_date'] as String)
              : null,
      status: ReportStatus.fromString(json['status'] as String),
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      trackingId: json['tracking_id'] as String?,
      teacherNote: json['teacher_note'] as String?,
      counselorNote: json['counselor_note'] as String?,
      deanNote: json['dean_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'teacher_id': teacherId,
      'counselor_id': counselorId,
      'dean_id': deanId,
      'title': title,
      'type': type,
      'details': details,
      'attachment_url': attachmentUrl,
      'incident_date': incidentDate?.toIso8601String(),
      'status': status.toString(),
      'is_anonymous': isAnonymous,
      'tracking_id': trackingId,
      'teacher_note': teacherNote,
      'counselor_note': counselorNote,
      'dean_note': deanNote,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReportModel copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? counselorId,
    String? deanId,
    String? title,
    String? type,
    String? details,
    String? attachmentUrl,
    DateTime? incidentDate,
    ReportStatus? status,
    bool? isAnonymous,
    String? trackingId,
    String? teacherNote,
    String? counselorNote,
    String? deanNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      counselorId: counselorId ?? this.counselorId,
      deanId: deanId ?? this.deanId,
      title: title ?? this.title,
      type: type ?? this.type,
      details: details ?? this.details,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      incidentDate: incidentDate ?? this.incidentDate,
      status: status ?? this.status,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      trackingId: trackingId ?? this.trackingId,
      teacherNote: teacherNote ?? this.teacherNote,
      counselorNote: counselorNote ?? this.counselorNote,
      deanNote: deanNote ?? this.deanNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum ReportStatus {
  submitted,
  pending,
  teacherReviewed,
  forwarded,
  counselorReviewed,
  counselorConfirmed,
  approvedByDean,
  counselingScheduled,
  settled,
  completed;

  static ReportStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return ReportStatus.submitted;
      case 'pending':
        return ReportStatus.pending;
      case 'teacher_reviewed':
        return ReportStatus.teacherReviewed;
      case 'forwarded':
        return ReportStatus.forwarded;
      case 'counselor_reviewed':
        return ReportStatus.counselorReviewed;
      case 'counselor_confirmed':
        return ReportStatus.counselorConfirmed;
      case 'approved_by_dean':
        return ReportStatus.approvedByDean;
      case 'counseling_scheduled':
        return ReportStatus.counselingScheduled;
      case 'settled':
        return ReportStatus.settled;
      case 'completed':
        return ReportStatus.completed;
      case 'ongoing':
        return ReportStatus.pending;
      default:
        return ReportStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ReportStatus.submitted:
        return 'submitted';
      case ReportStatus.pending:
        return 'pending';
      case ReportStatus.teacherReviewed:
        return 'teacher_reviewed';
      case ReportStatus.forwarded:
        return 'forwarded';
      case ReportStatus.counselorReviewed:
        return 'counselor_reviewed';
      case ReportStatus.counselorConfirmed:
        return 'counselor_confirmed';
      case ReportStatus.approvedByDean:
        return 'approved_by_dean';
      case ReportStatus.counselingScheduled:
        return 'counseling_scheduled';
      case ReportStatus.settled:
        return 'settled';
      case ReportStatus.completed:
        return 'completed';
    }
  }

  String get displayName {
    switch (this) {
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.pending:
        return 'Pending Review';
      case ReportStatus.teacherReviewed:
        return 'Teacher Reviewed';
      case ReportStatus.forwarded:
        return 'Forwarded';
      case ReportStatus.counselorReviewed:
        return 'Counselor Reviewed';
      case ReportStatus.counselorConfirmed:
        return 'Counselor Confirmed';
      case ReportStatus.approvedByDean:
        return 'Approved by Dean';
      case ReportStatus.counselingScheduled:
        return 'Confirmed by Counselor';
      case ReportStatus.settled:
        return 'Settled';
      case ReportStatus.completed:
        return 'Completed';
    }
  }
}
