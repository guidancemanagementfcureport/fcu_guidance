enum StudentLevel {
  juniorHigh,
  seniorHigh,
  college;

  static StudentLevel? fromString(String? level) {
    if (level == null) return null;
    switch (level.toLowerCase()) {
      case 'junior_high':
        return StudentLevel.juniorHigh;
      case 'senior_high':
        return StudentLevel.seniorHigh;
      case 'college':
        return StudentLevel.college;
      default:
        return null;
    }
  }

  @override
  String toString() {
    switch (this) {
      case StudentLevel.juniorHigh:
        return 'junior_high';
      case StudentLevel.seniorHigh:
        return 'senior_high';
      case StudentLevel.college:
        return 'college';
    }
  }

  String get displayName {
    switch (this) {
      case StudentLevel.juniorHigh:
        return 'Junior High School';
      case StudentLevel.seniorHigh:
        return 'Senior High School';
      case StudentLevel.college:
        return 'College';
    }
  }
}

class UserModel {
  final String id;
  final String gmail; // Gmail for login
  final UserRole role;
  final String fullName;
  final StudentLevel? studentLevel; // For students: junior_high, senior_high, college
  final String? course; // For college students
  final String? gradeLevel; // For junior high (7-10) or senior high (11-12)
  final String? strand; // For senior high students (STEM, HUMSS, ABM, GAS)
  final String? section; // For junior high students (optional)
  final String? yearLevel; // For college students (1st-4th Year)
  final String? department; // For teachers/counselors/admins
  final String? avatarUrl; // Profile picture URL
  final String status; // 'active' or 'inactive'
  final DateTime createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.id,
    required this.gmail,
    required this.role,
    required this.fullName,
    this.studentLevel,
    this.course,
    this.gradeLevel,
    this.strand,
    this.section,
    this.yearLevel,
    this.department,
    this.avatarUrl,
    this.status = 'active',
    required this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      gmail: json['gmail'] as String,
      role: UserRole.fromString(json['role'] as String),
      fullName: json['full_name'] as String,
      studentLevel: StudentLevel.fromString(json['student_level'] as String?),
      course: json['course'] as String?,
      gradeLevel: json['grade_level'] as String?,
      strand: json['strand'] as String?,
      section: json['section'] as String?,
      yearLevel: json['year_level'] as String?,
      department: json['department'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin:
          json['last_login'] != null
              ? DateTime.parse(json['last_login'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gmail': gmail,
      'role': role.toString(),
      'full_name': fullName,
      'student_level': studentLevel?.toString(),
      'course': course,
      'grade_level': gradeLevel,
      'strand': strand,
      'section': section,
      'year_level': yearLevel,
      'department': department,
      'avatar_url': avatarUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? gmail,
    UserRole? role,
    String? fullName,
    StudentLevel? studentLevel,
    String? course,
    String? gradeLevel,
    String? strand,
    String? section,
    String? yearLevel,
    String? department,
    String? avatarUrl,
    String? status,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      gmail: gmail ?? this.gmail,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      studentLevel: studentLevel ?? this.studentLevel,
      course: course ?? this.course,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      strand: strand ?? this.strand,
      section: section ?? this.section,
      yearLevel: yearLevel ?? this.yearLevel,
      department: department ?? this.department,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  bool get isActive => status == 'active';
}

enum UserRole {
  student,
  teacher,
  counselor,
  dean,
  admin;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'teacher':
        return UserRole.teacher;
      case 'counselor':
        return UserRole.counselor;
      case 'dean':
        return UserRole.dean;
      case 'admin':
        return UserRole.admin;
      default:
        throw ArgumentError('Invalid role: $role');
    }
  }

  @override
  String toString() {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.counselor:
        return 'counselor';
      case UserRole.dean:
        return 'dean';
      case UserRole.admin:
        return 'admin';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.counselor:
        return 'Counselor';
      case UserRole.dean:
        return 'Dean';
      case UserRole.admin:
        return 'System Admin';
    }
  }
}
