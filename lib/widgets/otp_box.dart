import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';

/// A single digit input box for the 4-digit OTP entry UI.
/// Handles styling, focus state, and error highlighting independently.
class OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  /// When true, the box border turns red to signal a validation error.
  final bool hasError;

  final ValueChanged<String> onChanged;

  /// Callback used to move focus backward when backspace is pressed on an empty box.
  final ValueChanged<KeyEvent> onKeyEvent;

  const OtpBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    // KeyboardListener captures backspace even on empty fields so focus can
    // move to the previous box without eating the event.
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: onKeyEvent,
      child: SizedBox(
        width: 52,
        height: 58,
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          // Accept digits only — no letters or special characters.
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.darkNavy,
          ),
          decoration: InputDecoration(
            counterText: '', // Hide the default maxLength counter label.
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
