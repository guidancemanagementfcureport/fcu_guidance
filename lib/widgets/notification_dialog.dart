import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';

class NotificationDialog extends StatefulWidget {
  final NotificationProvider provider;
  final String userId;

  const NotificationDialog({
    super.key,
    required this.provider,
    required this.userId,
  });

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  String _sortBy = 'newest'; // 'newest', 'oldest', 'unread'

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 400,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: AppTheme.skyBlue,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.sort_rounded,
                      color: AppTheme.deepBlue,
                    ),
                    tooltip: 'Sort by',
                    onSelected: (value) => setState(() => _sortBy = value),
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'newest',
                            child: Row(
                              children: [
                                Icon(Icons.arrow_downward_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Newest First'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'oldest',
                            child: Row(
                              children: [
                                Icon(Icons.arrow_upward_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Oldest First'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'unread',
                            child: Row(
                              children: [
                                Icon(Icons.mark_email_unread_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Unread First'),
                              ],
                            ),
                          ),
                        ],
                  ),
                  if (widget.provider.unreadCount > 0)
                    TextButton(
                      onPressed:
                          () => widget.provider.markAllAsRead(widget.userId),
                      child: const Text('Mark all read'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child:
                  widget.provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : widget.provider.notifications.isEmpty
                      ? _buildEmptyState()
                      : _buildNotificationList(),
            ),
          ],
        ),
      ),
    ).fadeIn();
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.notifications_none_rounded,
          size: 64,
          color: AppTheme.mediumGray.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 16),
        Text(
          'No notifications yet',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.mediumGray,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationList() {
    // Sort logic
    final sortedList = List<NotificationModel>.from(
      widget.provider.notifications,
    );
    switch (_sortBy) {
      case 'oldest':
        sortedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'unread':
        sortedList.sort((a, b) {
          if (!a.isRead && b.isRead) return -1;
          if (a.isRead && !b.isRead) return 1;
          return b.createdAt.compareTo(a.createdAt); // Secondary sort by date
        });
        break;
      case 'newest':
      default:
        sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sortedList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notification = sortedList[index];
        return _NotificationTile(
          notification: notification,
          onTap: () {
            if (!notification.isRead) {
              widget.provider.markAsRead(notification.id);
            }
            // Navigate if route is present
            if (notification.data.containsKey('route')) {
              Navigator.pop(context); // Close dialog
              context.go(notification.data['route']);
            } else if (notification.type == NotificationType.newReport &&
                notification.data.containsKey('report_id')) {
              // ... (existing logic)
            }
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;

    switch (notification.type) {
      case NotificationType.newReport:
        iconColor = AppTheme.skyBlue;
        iconData = Icons.assignment_late_rounded;
        break;
      case NotificationType.reportUpdate:
        iconColor = Colors.orange;
        iconData = Icons.update_rounded;
        break;
      case NotificationType.success:
        iconColor = Colors.green;
        iconData = Icons.check_circle_rounded;
        break;
      case NotificationType.newMessage:
        iconColor = AppTheme.mediumBlue;
        iconData = Icons.chat_bubble_rounded;
        break;
      default:
        iconColor = AppTheme.skyBlue;
        iconData = Icons.info_rounded;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              notification.isRead
                  ? Colors.transparent
                  : iconColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                notification.isRead
                    ? AppTheme.skyBlue.withValues(alpha: 0.1)
                    : iconColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.skyBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkGray,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat(
                      'MMM dd, hh:mm a',
                    ).format(notification.createdAt),
                    style: TextStyle(fontSize: 11, color: AppTheme.mediumGray),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
