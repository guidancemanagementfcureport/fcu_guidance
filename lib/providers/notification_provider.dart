import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/supabase_service.dart';

class NotificationProvider with ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  StreamSubscription<List<NotificationModel>>? _subscription;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void init(String userId) {
    _subscription?.cancel();
    _fetchInitial(userId);
    _subscription = _supabase.streamNotifications(userId).listen((
      newNotifications,
    ) {
      _notifications = newNotifications;
      _unreadCount = newNotifications.where((n) => !n.isRead).length;
      notifyListeners();
    });
  }

  Future<void> _fetchInitial(String userId) async {
    _isLoading = true;
    notifyListeners();

    _notifications = await _supabase.getNotifications(userId);
    _unreadCount = await _supabase.getUnreadNotificationsCount(userId);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final success = await _supabase.markNotificationAsRead(notificationId);
    if (success) {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead(String userId) async {
    final success = await _supabase.markAllNotificationsAsRead(userId);
    if (success) {
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    }
  }

  Future<void> markNotificationsAsSeenForRoute(
    String userId,
    String route,
  ) async {
    List<NotificationModel> toMark = [];

    if (route == '/teacher/communication') {
      toMark =
          _notifications
              .where((n) => !n.isRead && n.type == NotificationType.newMessage)
              .toList();
    } else if (route == '/counselor/communication') {
      toMark =
          _notifications
              .where((n) => !n.isRead && n.type == NotificationType.newMessage)
              .toList();
    } else if (route == '/counselor/cases') {
      toMark =
          _notifications
              .where((n) => !n.isRead && n.type == NotificationType.newReport)
              .toList();
    } else if (route == '/dean/reports') {
      toMark =
          _notifications
              .where((n) => !n.isRead && n.type == NotificationType.newReport)
              .toList();
    } else if (route == '/teacher/reports') {
      toMark =
          _notifications
              .where((n) => !n.isRead && n.type == NotificationType.newReport)
              .toList();
    }

    if (toMark.isNotEmpty) {
      for (var n in toMark) {
        await markAsRead(n.id);
      }
    }
  }

  Future<void> markReportAsSeen(String reportId) async {
    final toMark =
        _notifications
            .where(
              (n) =>
                  !n.isRead &&
                  (n.type == NotificationType.newReport ||
                      n.type == NotificationType.reportUpdate) &&
                  n.data['report_id'] == reportId,
            )
            .toList();

    for (var n in toMark) {
      await markAsRead(n.id);
    }
  }

  Future<void> markMessageAsSeen(String reportId) async {
    final toMark =
        _notifications
            .where(
              (n) =>
                  !n.isRead &&
                  n.type == NotificationType.newMessage &&
                  (n.data['report_id'] == reportId ||
                      n.data['session_id'] == reportId),
            )
            .toList();

    for (var n in toMark) {
      await markAsRead(n.id);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
