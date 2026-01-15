import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Centralized toast notification utility with flat style
/// Follows MVP design guidelines: clean, professional, non-intrusive
class ToastUtils {
  ToastUtils._();

  // Configuration
  static const _autoClose = Duration(seconds: 4);
  static const _animation = Duration(milliseconds: 300);

  /// Internal method to show toast with flat style
  static void _show(
    BuildContext context, {
    required String message,
    required ToastificationType type,
    String? title,
    IconData? icon,
    Duration? autoClose,
  }) {
    if (!context.mounted) return;

    // Determine colors based on type (flat style - soft backgrounds)
    final Color backgroundColor;
    final Color iconColor;
    final Color textColor = const Color(0xFF111827); // Dark gray for readability

    switch (type) {
      case ToastificationType.success:
        backgroundColor = const Color(0xFFF0FDF4); // Soft green
        iconColor = const Color(0xFF10B981); // Green
        break;
      case ToastificationType.info:
        backgroundColor = const Color(0xFFEFF6FF); // Light blue
        iconColor = const Color(0xFF3B82F6); // Blue
        break;
      case ToastificationType.warning:
        backgroundColor = const Color(0xFFFEF3C7); // Soft amber
        iconColor = const Color(0xFFF59E0B); // Amber
        break;
      case ToastificationType.error:
        backgroundColor = const Color(0xFFFEE2E2); // Soft red
        iconColor = const Color(0xFFEF4444); // Red
        break;
      default:
        backgroundColor = const Color(0xFFEFF6FF); // Default to info blue
        iconColor = const Color(0xFF3B82F6); // Default to info blue
        break;
    }

    toastification.show(
      context: context,
      style: ToastificationStyle.flat,
      type: type,
      title: title != null
          ? Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.2,
              ),
            )
          : null,
      description: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textColor.withValues(alpha: 0.8),
          height: 1.4,
        ),
      ),
      icon: icon != null
          ? Icon(
              icon,
              size: 22,
              color: iconColor,
            )
          : null,
      alignment: Alignment.bottomRight,
      autoCloseDuration: autoClose ?? _autoClose,
      animationDuration: _animation,
      pauseOnHover: true,
      dragToClose: true,
      closeOnClick: true,
      showProgressBar: true,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ],
      margin: const EdgeInsets.all(16),
      // Flat style customization
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
    );
  }

  /// Show success toast notification
  /// Use for: Report submitted, request confirmed, successful actions
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration? autoClose,
  }) {
    _show(
      context,
      message: message,
      type: ToastificationType.success,
      title: title ?? 'Success',
      icon: Icons.check_circle_outline,
      autoClose: autoClose,
    );
  }

  /// Show error toast notification
  /// Use for: Submission failed, permission denied, errors
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration? autoClose,
  }) {
    _show(
      context,
      message: message,
      type: ToastificationType.error,
      title: title ?? 'Error',
      icon: Icons.error_outline,
      autoClose: autoClose,
    );
  }

  /// Show warning toast notification
  /// Use for: Incomplete fields, action required, warnings
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration? autoClose,
  }) {
    _show(
      context,
      message: message,
      type: ToastificationType.warning,
      title: title ?? 'Warning',
      icon: Icons.warning_amber_outlined,
      autoClose: autoClose,
    );
  }

  /// Show info toast notification
  /// Use for: Status updates, system messages, information
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration? autoClose,
  }) {
    _show(
      context,
      message: message,
      type: ToastificationType.info,
      title: title ?? 'Info',
      icon: Icons.info_outline,
      autoClose: autoClose,
    );
  }
}

