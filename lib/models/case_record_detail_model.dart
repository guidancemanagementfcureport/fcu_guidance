import 'report_model.dart';
import 'user_model.dart';
import 'case_message_model.dart';
import 'report_activity_log_model.dart';

class CaseRecordDetailModel {
  final ReportModel report;
  final UserModel? student; // Null for anonymous reports
  final UserModel? teacher;
  final UserModel? counselor;
  final UserModel? dean;
  final List<CaseMessageModel> messages;
  final List<ReportActivityLog> activityLogs;

  CaseRecordDetailModel({
    required this.report,
    this.student,
    this.teacher,
    this.counselor,
    this.dean,
    required this.messages,
    required this.activityLogs,
  });

  String get studentDisplayName {
    if (report.isAnonymous) {
      return 'Anonymous Student';
    }
    return student?.fullName ?? 'Unknown Student';
  }

  String get teacherDisplayName => teacher?.fullName ?? 'Not Assigned';
  String get counselorDisplayName => counselor?.fullName ?? 'Not Assigned';
  String get deanDisplayName => dean?.fullName ?? 'Not Assigned';

  int get totalMessages => messages.length;

  DateTime? get lastMessageTime {
    if (messages.isEmpty) return null;
    return messages.last.createdAt;
  }

  List<String> get rolesInvolved {
    final roles = <String>[];
    if (teacher != null) roles.add('Teacher');
    if (counselor != null) roles.add('Counselor');
    if (dean != null) roles.add('Dean');
    return roles;
  }
}
