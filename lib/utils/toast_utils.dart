import 'package:flutter/material.dart';

class ToastUtils {
  static void show(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) =>
      show(context, message, duration: const Duration(seconds: 3));

  static void showError(BuildContext context, String message) =>
      show(context, message, duration: const Duration(seconds: 3));

  static void showInfo(BuildContext context, String message) =>
      show(context, message, duration: const Duration(seconds: 3));
}
