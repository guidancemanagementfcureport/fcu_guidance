class ReportAnalyticsModel {
  final int totalReports;
  final int activeReports;
  final int resolvedReports;
  final Map<String, int> reportsByDepartment;
  final Map<String, int> reportsByRole;
  final Map<String, int> reportsByStatus;
  final List<MonthlyTrendData> monthlyTrends;

  ReportAnalyticsModel({
    required this.totalReports,
    required this.activeReports,
    required this.resolvedReports,
    required this.reportsByDepartment,
    required this.reportsByRole,
    required this.reportsByStatus,
    required this.monthlyTrends,
  });

  factory ReportAnalyticsModel.empty() {
    return ReportAnalyticsModel(
      totalReports: 0,
      activeReports: 0,
      resolvedReports: 0,
      reportsByDepartment: {},
      reportsByRole: {},
      reportsByStatus: {},
      monthlyTrends: [],
    );
  }
}

class MonthlyTrendData {
  final String month;
  final int year;
  final int count;

  MonthlyTrendData({
    required this.month,
    required this.year,
    required this.count,
  });

  String get displayLabel => '$month $year';
}
