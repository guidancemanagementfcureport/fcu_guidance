import 'package:flutter/material.dart';

class CounselingRequestModel {
  final String id;
  final String studentId;
  final String? counselorId;
  final String? deanId;
  final String? reportId;
  final CounselingStatus status;
  final String? requestDetails;
  final String? reason;
  final String? preferredTime;
  final String? counselorNote;
  // Counseling Session Scheduling (set by Dean)
  final DateTime? sessionDate;
  final TimeOfDay? sessionTime;
  final String? sessionType; // 'Individual' or 'Group'
  final String? locationMode; // 'In-person' or 'Online'
  final List<Map<String, dynamic>>? participants; // Array of {userId, role}
  final DateTime createdAt;
  final DateTime updatedAt;

  CounselingRequestModel({
    required this.id,
    required this.studentId,
    this.counselorId,
    this.deanId,
    this.reportId,
    this.status = CounselingStatus.pendingReview,
    this.requestDetails,
    this.reason,
    this.preferredTime,
    this.counselorNote,
    this.sessionDate,
    this.sessionTime,
    this.sessionType,
    this.locationMode,
    this.participants,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CounselingRequestModel.fromJson(Map<String, dynamic> json) {
    // Parse session_time from TIME format (HH:MM:SS) or string
    TimeOfDay? sessionTime;
    if (json['session_time'] != null) {
      final timeStr = json['session_time'] as String;
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        sessionTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    // Parse participants from JSONB
    List<Map<String, dynamic>>? participants;
    if (json['participants'] != null) {
      if (json['participants'] is List) {
        participants =
            (json['participants'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
      } else if (json['participants'] is Map) {
        // Handle if stored as object instead of array
        participants = [json['participants'] as Map<String, dynamic>];
      }
    }

    return CounselingRequestModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      counselorId: json['counselor_id'] as String?,
      deanId: json['dean_id'] as String?,
      reportId: json['report_id'] as String?,
      status: CounselingStatus.fromString(json['status'] as String),
      requestDetails: json['request_details'] as String?,
      reason: json['reason'] as String?,
      preferredTime: json['preferred_time'] as String?,
      counselorNote: json['counselor_note'] as String?,
      sessionDate:
          json['session_date'] != null
              ? DateTime.parse(json['session_date'] as String)
              : null,
      sessionTime: sessionTime,
      sessionType: json['session_type'] as String?,
      locationMode: json['location_mode'] as String?,
      participants: participants,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'counselor_id': counselorId,
      'dean_id': deanId,
      'report_id': reportId,
      'status': status.toString(),
      'request_details': requestDetails,
      'reason': reason,
      'preferred_time': preferredTime,
      'counselor_note': counselorNote,
      'session_date':
          sessionDate?.toIso8601String().split('T')[0], // DATE format
      'session_time':
          sessionTime != null
              ? '${sessionTime!.hour.toString().padLeft(2, '0')}:${sessionTime!.minute.toString().padLeft(2, '0')}:00'
              : null, // TIME format (HH:MM:SS)
      'session_type': sessionType,
      'location_mode': locationMode,
      'participants': participants,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CounselingRequestModel copyWith({
    String? id,
    String? studentId,
    String? counselorId,
    String? deanId,
    String? reportId,
    CounselingStatus? status,
    String? requestDetails,
    String? reason,
    String? preferredTime,
    String? counselorNote,
    DateTime? sessionDate,
    TimeOfDay? sessionTime,
    String? sessionType,
    String? locationMode,
    List<Map<String, dynamic>>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CounselingRequestModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      counselorId: counselorId ?? this.counselorId,
      deanId: deanId ?? this.deanId,
      reportId: reportId ?? this.reportId,
      status: status ?? this.status,
      requestDetails: requestDetails ?? this.requestDetails,
      reason: reason ?? this.reason,
      preferredTime: preferredTime ?? this.preferredTime,
      counselorNote: counselorNote ?? this.counselorNote,
      sessionDate: sessionDate ?? this.sessionDate,
      sessionTime: sessionTime ?? this.sessionTime,
      sessionType: sessionType ?? this.sessionType,
      locationMode: locationMode ?? this.locationMode,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum CounselingStatus {
  pendingReview,
  confirmed,
  settled;

  static CounselingStatus fromString(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'pending_counseling_review':
      case 'pendingreview':
      case 'pending':
        return CounselingStatus.pendingReview;
      case 'counseling_confirmed':
      case 'confirmed':
        return CounselingStatus.confirmed;
      case 'settled':
      case 'completed':
        return CounselingStatus.settled;
      // Legacy support
      case 'requested':
        return CounselingStatus.pendingReview;
      case 'approved':
        return CounselingStatus.confirmed;
      case 'cancelled':
        return CounselingStatus.settled;
      default:
        throw ArgumentError('Invalid status: $status');
    }
  }

  @override
  String toString() {
    switch (this) {
      case CounselingStatus.pendingReview:
        return 'Pending Counseling Review';
      case CounselingStatus.confirmed:
        return 'Counseling Confirmed';
      case CounselingStatus.settled:
        return 'Settled';
    }
  }

  String get displayName {
    switch (this) {
      case CounselingStatus.pendingReview:
        return 'Pending Counseling Review';
      case CounselingStatus.confirmed:
        return 'Counseling Confirmed';
      case CounselingStatus.settled:
        return 'Settled';
    }
  }
}
