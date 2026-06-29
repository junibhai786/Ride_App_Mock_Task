import 'package:flutter/material.dart';
import 'package:ride_app_mock/core/errors/app_exception.dart';

/// Converts [AppException] subtypes into user-facing messages and SnackBars.
class ErrorHandler {
  const ErrorHandler._();

  static String message(AppException e) => e.message;

  static void showSnackBar(
    BuildContext context,
    AppException e, {
    bool isError = true,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message(e))),
            ],
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: _duration(e),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
  }

  static Duration _duration(AppException e) => switch (e) {
        NetworkException() || TimeoutException() => const Duration(seconds: 5),
        ServerException(statusCode: >= 500) => const Duration(seconds: 4),
        _ => const Duration(seconds: 3),
      };
}
